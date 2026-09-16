const Tokenizer = @This();

const std = @import("std");
const log = std.log.scoped(.tokenizer);
const testing = std.testing;

buffer: []const u8,
index: usize = 0,
in_flow: usize = 0,

pub const Token = struct {
    id: Id,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Id = enum {
        // zig fmt: off
        eof,

        new_line,
        doc_start,      // ---
        doc_end,        // ...
        seq_item_ind,   // -
        map_value_ind,  // :
        flow_map_start, // {
        flow_map_end,   // }
        flow_seq_start, // [
        flow_seq_end,   // ]

        comma,
        space,
        tab,
        comment,        // #
        alias,          // *
        anchor,         // &
        tag,            // !

        single_quoted,   // '...'
        double_quoted,   // "..."
        literal,
        // zig fmt: on
    };

    pub const Index = enum(u32) {
        _,
    };
};

pub const TokenIterator = struct {
    buffer: []const Token,
    pos: Token.Index = @enumFromInt(0),

    pub fn next(self: *TokenIterator) ?Token {
        const token = self.peek() orelse return null;
        self.pos = @enumFromInt(@intFromEnum(self.pos) + 1);
        return token;
    }

    pub fn peek(self: TokenIterator) ?Token {
        const pos = @intFromEnum(self.pos);
        if (pos >= self.buffer.len) return null;
        return self.buffer[pos];
    }

    pub fn reset(self: *TokenIterator) void {
        self.pos = @enumFromInt(0);
    }

    pub fn seekTo(self: *TokenIterator, pos: Token.Index) void {
        self.pos = pos;
    }

    pub fn seekBy(self: *TokenIterator, offset: isize) void {
        var pos = @intFromEnum(self.pos);
        if (offset < 0) {
            pos -|= @intCast(@abs(offset));
        } else {
            pos +|= @intCast(@as(usize, @bitCast(offset)));
        }
        self.pos = @enumFromInt(pos);
    }
};

fn stringMatchesPattern(comptime pattern: []const u8, slice: []const u8) bool {
    comptime var count: usize = 0;
    inline while (count < pattern.len) : (count += 1) {
        if (count >= slice.len) return false;
        const c = slice[count];
        if (pattern[count] != c) return false;
    }
    return true;
}

fn matchesPattern(self: Tokenizer, comptime pattern: []const u8) bool {
    return stringMatchesPattern(pattern, self.buffer[self.index..]);
}

pub fn next(self: *Tokenizer) Token {
    var result = Token{
        .id = .eof,
        .loc = .{
            .start = self.index,
            .end = undefined,
        },
    };

    var state: enum {
        start,
        new_line,
        space,
        tab,
        comment,
        single_quoted,
        double_quoted,
        double_quoted_escape,
        literal,
    } = .start;

    while (self.index < self.buffer.len) : (self.index += 1) {
        const c = self.buffer[self.index];
        switch (state) {
            .start => switch (c) {
                ' ' => {
                    state = .space;
                },
                '\t' => {
                    state = .tab;
                },
                '\n' => {
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                '\r' => {
                    state = .new_line;
                },

                '-' => if (self.matchesPattern("---")) {
                    result.id = .doc_start;
                    self.index += "---".len;
                    break;
                } else if (self.matchesPattern("- ")) {
                    result.id = .seq_item_ind;
                    self.index += "- ".len;
                    break;
                } else if (self.matchesPattern("-\n")) {
                    result.id = .seq_item_ind;
                    // we do not skip the newline
                    self.index += "-".len;
                    break;
                } else {
                    state = .literal;
                },

                '.' => if (self.matchesPattern("...")) {
                    result.id = .doc_end;
                    self.index += "...".len;
                    break;
                } else {
                    state = .literal;
                },

                ',' => {
                    result.id = .comma;
                    self.index += 1;
                    break;
                },
                '#' => {
                    result.id = .comment;
                    state = .comment;
                },
                '*' => {
                    result.id = .alias;
                    self.index += 1;
                    break;
                },
                '&' => {
                    result.id = .anchor;
                    self.index += 1;
                    break;
                },
                '!' => {
                    result.id = .tag;
                    self.index += 1;
                    break;
                },
                '[' => {
                    result.id = .flow_seq_start;
                    self.index += 1;
                    self.in_flow += 1;
                    break;
                },
                ']' => {
                    result.id = .flow_seq_end;
                    self.index += 1;
                    self.in_flow -|= 1;
                    break;
                },
                ':' => {
                    result.id = .map_value_ind;
                    self.index += 1;
                    break;
                },
                '{' => {
                    result.id = .flow_map_start;
                    self.index += 1;
                    self.in_flow += 1;
                    break;
                },
                '}' => {
                    result.id = .flow_map_end;
                    self.index += 1;
                    self.in_flow -|= 1;
                    break;
                },
                '\'' => {
                    state = .single_quoted;
                },
                '"' => {
                    state = .double_quoted;
                },
                else => {
                    state = .literal;
                },
            },

            .comment => switch (c) {
                '\r', '\n' => {
                    result.id = .comment;
                    break;
                },
                else => {},
            },

            .space => switch (c) {
                ' ' => {},
                else => {
                    result.id = .space;
                    break;
                },
            },

            .tab => switch (c) {
                '\t' => {},
                else => {
                    result.id = .tab;
                    break;
                },
            },

            .new_line => switch (c) {
                '\n' => {
                    // CRLF: consume the '\n' as part of the same line break.
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                else => {
                    // A lone CR is itself a line break (YAML 1.2). Emit the
                    // new_line token spanning just the '\r' without consuming
                    // the following character.
                    result.id = .new_line;
                    break;
                },
            },

            .single_quoted => switch (c) {
                '\'' => if (!self.matchesPattern("''")) {
                    result.id = .single_quoted;
                    self.index += 1;
                    break;
                } else {
                    self.index += "''".len - 1;
                },
                else => {},
            },

            .double_quoted => switch (c) {
                // A backslash escapes the next character (including `\\` and
                // `\"`); track it explicitly so an escaped quote does not close
                // the string and an escaped backslash is not mistaken for one.
                '\\' => {
                    state = .double_quoted_escape;
                },
                '"' => {
                    result.id = .double_quoted;
                    self.index += 1;
                    break;
                },
                else => {},
            },

            .double_quoted_escape => switch (c) {
                // Consume exactly one character as the escape payload, then
                // resume scanning the string body.
                else => {
                    state = .double_quoted;
                },
            },

            .literal => switch (c) {
                '\r', '\n', ' ', '\'', '"', ']', '}' => {
                    result.id = .literal;
                    break;
                },
                ',', '[', '{' => {
                    result.id = .literal;
                    if (self.in_flow > 0) {
                        break;
                    }
                },
                ':' => {
                    result.id = .literal;
                    // A ':' acts as a map separator when followed by white
                    // space, a line break, or the end of input (e.g. a `key:`
                    // with a null value at the very end of the document).
                    // YAML 1.2 `s-white` is a space *or* a tab, so `a:\tb` is
                    // a mapping just like `a: b`.
                    if (self.matchesPattern(": ") or
                        self.matchesPattern(":\t") or
                        self.matchesPattern(":\n") or
                        self.matchesPattern(":\r") or
                        self.index + 1 >= self.buffer.len)
                    {
                        break;
                    }
                },
                else => {
                    result.id = .literal;
                },
            },
        }
    }

    if (self.index >= self.buffer.len) {
        switch (state) {
            // A token that was still being accumulated when the buffer ran out
            // must keep its in-progress id; otherwise it would masquerade as
            // `.eof` (its initial value), truncating the token stream and
            // dropping the trailing content.
            .literal => result.id = .literal,
            .space => result.id = .space,
            .tab => result.id = .tab,
            .new_line => result.id = .new_line,
            // Unterminated quoted scalars are surfaced as their quote token so
            // that the parser routes them to parseSingleQuoted/parseDoubleQuoted,
            // which detect the missing closing quote and report a parse error.
            .single_quoted => result.id = .single_quoted,
            .double_quoted, .double_quoted_escape => result.id = .double_quoted,
            // `.start` means no token was pending: a genuine end of input.
            // `.comment` already had its id assigned when '#' was seen.
            .start, .comment => {},
        }
    }

    result.loc.end = self.index;

    log.debug("{any}", .{result});
    log.debug("    | {s}", .{self.buffer[result.loc.start..result.loc.end]});

    return result;
}

fn testExpected(source: []const u8, expected: []const Token.Id) !void {
    var tokenizer = Tokenizer{
        .buffer = source,
    };

    var given = std.array_list.Managed(Token.Id).init(testing.allocator);
    defer given.deinit();

    while (true) {
        const token = tokenizer.next();
        try given.append(token.id);
        if (token.id == .eof) break;
    }

    try testing.expectEqualSlices(Token.Id, expected, given.items);
}

test {
    std.testing.refAllDecls(@This());
}

test "empty doc" {
    try testExpected("", &[_]Token.Id{.eof});
}

test "empty doc with explicit markers" {
    try testExpected(
        \\---
        \\...
    , &[_]Token.Id{
        .doc_start, .new_line, .doc_end, .eof,
    });
}

test "empty doc with explicit markers and a directive" {
    try testExpected(
        \\--- !tbd-v1
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "sequence of values" {
    try testExpected(
        \\- 0
        \\- 1
        \\- 2
    , &[_]Token.Id{
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "sequence of sequences" {
    try testExpected(
        \\- [ val1, val2]
        \\- [val3, val4 ]
    , &[_]Token.Id{
        .seq_item_ind,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .literal,
        .flow_seq_end,
        .new_line,
        .seq_item_ind,
        .flow_seq_start,
        .literal,
        .comma,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "mappings" {
    try testExpected(
        \\key1: value1
        \\key2: value2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "inline mapped sequence of values" {
    try testExpected(
        \\key :  [ val1, 
        \\          val2 ]
    , &[_]Token.Id{
        .literal,
        .space,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .new_line,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "part of tbd" {
    try testExpected(
        \\--- !tapi-tbd
        \\tbd-version:     4
        \\targets:         [ x86_64-macos ]
        \\
        \\uuids:
        \\  - target:          x86_64-macos
        \\    value:           F86CC732-D5E4-30B5-AA7D-167DF5EC2708
        \\
        \\install-name:    '/usr/lib/libSystem.B.dylib'
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .new_line,
        .space,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .space,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "Unindented list" {
    try testExpected(
        \\b:
        \\- foo: 1
        \\c: 1
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .new_line,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "escape sequences" {
    try testExpected(
        \\a: 'here''s an apostrophe'
        \\b: "a newline\nand a\ttab"
        \\c: "\"here\" and there"
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .eof,
    });
}

test "comments" {
    try testExpected(
        \\key: # some comment about the key
        \\# first value
        \\- val1
        \\# second value
        \\- val2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .comment,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "quoted literals" {
    try testExpected(
        \\'#000000'
        \\'[000000'
        \\"&someString"
    , &[_]Token.Id{
        .single_quoted,
        .new_line,
        .single_quoted,
        .new_line,
        .double_quoted,
        .eof,
    });
}

test "unquoted literals" {
    try testExpected(
        \\key1: helloWorld
        \\key2: hello,world
        \\key3: [hello,world]
    , &[_]Token.Id{
        // key1
        .literal,
        .map_value_ind,
        .space,
        .literal, // helloWorld
        .new_line,
        // key2
        .literal,
        .map_value_ind,
        .space,
        .literal, // hello,world
        .new_line,
        // key3
        .literal,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .literal, // hello
        .comma,
        .literal, // world
        .flow_seq_end,
        .eof,
    });
}

test "unquoted literal containing colon" {
    try testExpected(
        \\key1: val:ue
        \\key2: val::ue
    , &[_]Token.Id{
        // key1
        .literal,
        .map_value_ind,
        .space,
        .literal, // val:ue
        .new_line,
        // key2
        .literal,
        .map_value_ind,
        .space,
        .literal, // val::ue
        .eof,
    });
}

test "trailing literal without newline keeps its id at eof" {
    try testExpected("abc", &[_]Token.Id{ .literal, .eof });
}

test "trailing spaces without newline keep their id at eof" {
    try testExpected("a:  ", &[_]Token.Id{
        .literal, .map_value_ind, .space, .eof,
    });
}

test "flow mapping tokens" {
    try testExpected("{ a: 1, b: 2 }", &[_]Token.Id{
        .flow_map_start,
        .space,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .comma,
        .space,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .space,
        .flow_map_end,
        .eof,
    });
}

test "unterminated double quote is surfaced as a quote token" {
    // Must not masquerade as `.eof` (which would truncate the stream).
    try testExpected("\"unterminated", &[_]Token.Id{ .double_quoted, .eof });
}

test "unterminated single quote is surfaced as a quote token" {
    try testExpected("'unterminated", &[_]Token.Id{ .single_quoted, .eof });
}

test "double quote with escaped backslash before closing quote" {
    try testExpected("\"a\\\\\"", &[_]Token.Id{ .double_quoted, .eof });
}

test "double quote with escaped quote does not close early" {
    try testExpected("\"a\\\"b\"", &[_]Token.Id{ .double_quoted, .eof });
}

test "lone carriage return is a single new_line token" {
    try testExpected("a\rb", &[_]Token.Id{
        .literal, .new_line, .literal, .eof,
    });
}

test "trailing colon at end of input is a map separator" {
    try testExpected("key:", &[_]Token.Id{
        .literal, .map_value_ind, .eof,
    });
}
