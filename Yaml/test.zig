const std = @import("std");
const mem = std.mem;
const stringify = @import("../stringify.zig").stringify;
const testing = std.testing;

const Arena = std.heap.ArenaAllocator;
const Yaml = @import("../Yaml.zig");

test "simple list" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const list = yaml.docs.items[0].list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple list parsed as booleans" {
    const source =
        \\- true
        \\- false
        \\- true
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), []const bool);
    try testing.expectEqual(parsed.len, 3);

    try testing.expect(parsed[0]);
    try testing.expect(!parsed[1]);
    try testing.expect(parsed[2]);
}

test "simple list typed as array of strings" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(3, arr.len);
    try testing.expectEqualStrings("a", arr[0]);
    try testing.expectEqualStrings("b", arr[1]);
    try testing.expectEqualStrings("c", arr[2]);
}

test "simple list typed as array of ints" {
    const source =
        \\- 0
        \\- 1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]u8);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 1, 2 }, &arr);
}

test "list of mixed sign integer" {
    const source =
        \\- 0
        \\- -1
        \\- 2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 0, -1, 2 }, &arr);
}

test "several integer bases" {
    const source =
        \\- 10
        \\- -10
        \\- 0x10
        \\- -0X10
        \\- 0o10
        \\- -0O10
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [6]i8);
    try testing.expectEqualSlices(i8, &[_]i8{ 10, -10, 16, -16, 8, -8 }, &arr);
}

test "simple flow sequence / bracket list" {
    const source =
        \\a_key: [a, b, c]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with trailing comma" {
    const source =
        \\a_key: [a, b, c,]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;

    const list = map.get("a_key").?.list;
    try testing.expectEqual(list.len, 3);

    try testing.expectEqualStrings("a", list[0].scalar);
    try testing.expectEqualStrings("b", list[1].scalar);
    try testing.expectEqualStrings("c", list[2].scalar);
}

test "simple flow sequence / bracket list with invalid comment" {
    const source =
        \\a_key: [a, b, c]#invalid
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    const err = yaml.load(testing.allocator);

    try std.testing.expectError(error.ParseFailure, err);
}

test "simple flow sequence / bracket list with double trailing commas" {
    const source =
        \\a_key: [a, b, c,,]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    const err = yaml.load(testing.allocator);

    try std.testing.expectError(error.ParseFailure, err);
}

test "more bools" {
    const source =
        \\- false
        \\- true
        \\- off
        \\- on
        \\- no
        \\- yes
        \\- n
        \\- y
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [8]bool);
    try testing.expectEqualSlices(bool, &[_]bool{
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
    }, &arr);
}

test "invalid enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    const source =
        \\- delta
        \\- echo
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = yaml.parse(arena.allocator(), [2]TestEnum);
    try testing.expectError(Yaml.Error.InvalidEnum, result);
}

test "simple map untyped" {
    const source =
        \\a: 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
}

test "simple map untyped with a list of maps" {
    const source =
        \\a: 0
        \\b:
        \\  - foo: 1
        \\    bar: 2
        \\  - foo: 3
        \\    bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map untyped with a list of maps. no indent" {
    const source =
        \\b:
        \\- foo: 1
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
}

test "simple map untyped with a list of maps. no indent 2" {
    const source =
        \\a: 0
        \\b:
        \\- foo: 1
        \\  bar: 2
        \\- foo: 3
        \\  bar: 4
        \\c: 1
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    try testing.expectEqual(yaml.docs.items.len, 1);

    const map = yaml.docs.items[0].map;
    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("b"));
    try testing.expect(map.contains("c"));
    try testing.expectEqualStrings("0", map.get("a").?.scalar);
    try testing.expectEqualStrings("1", map.get("c").?.scalar);
    try testing.expectEqualStrings("1", map.get("b").?.list[0].map.get("foo").?.scalar);
    try testing.expectEqualStrings("2", map.get("b").?.list[0].map.get("bar").?.scalar);
    try testing.expectEqualStrings("3", map.get("b").?.list[1].map.get("foo").?.scalar);
    try testing.expectEqualStrings("4", map.get("b").?.list[1].map.get("bar").?.scalar);
}

test "simple map typed" {
    const source =
        \\a: 0
        \\b: hello there
        \\c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct { a: usize, b: []const u8, c: []const u8 });
    try testing.expectEqual(@as(usize, 0), simple.a);
    try testing.expectEqualStrings("hello there", simple.b);
    try testing.expectEqualStrings("wait, what?", simple.c);
}

test "typed nested structs" {
    const source =
        \\a:
        \\  b: hello there
        \\  c: 'wait, what?'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: struct {
            b: []const u8,
            c: []const u8,
        },
    });
    try testing.expectEqualStrings("hello there", simple.a.b);
    try testing.expectEqualStrings("wait, what?", simple.a.c);
}

test "typed union with nested struct" {
    const source =
        \\a:
        \\  b: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_a.a.b);
}

test "typed union with nested struct 2" {
    const source =
        \\c:
        \\  d: hello there
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), union(enum) {
        tag_a: struct {
            a: struct {
                b: []const u8,
            },
        },
        tag_c: struct {
            c: struct {
                d: []const u8,
            },
        },
    });
    try testing.expectEqualStrings("hello there", simple.tag_c.c.d);
}

test "single quoted string" {
    const source =
        \\- 'hello'
        \\- 'here''s an escaped quote'
        \\- 'newlines and tabs\nare not\tsupported'
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [3][]const u8);
    try testing.expectEqual(arr.len, 3);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings("here's an escaped quote", arr[1]);
    try testing.expectEqualStrings("newlines and tabs\\nare not\\tsupported", arr[2]);
}

test "double quoted string" {
    const source =
        \\- "hello"
        \\- "\"here\" are some escaped quotes"
        \\- "newlines and tabs\nare\tsupported"
        \\- "let's have
        \\some fun!"
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const arr = try yaml.parse(arena.allocator(), [4][]const u8);
    try testing.expectEqual(arr.len, 4);
    try testing.expectEqualStrings("hello", arr[0]);
    try testing.expectEqualStrings(
        \\"here" are some escaped quotes
    , arr[1]);
    try testing.expectEqualStrings("newlines and tabs\nare\tsupported", arr[2]);
    try testing.expectEqualStrings(
        \\let's have
        \\some fun!
    , arr[3]);
}

test "commas in string" {
    const source =
        \\a: 900,50,50
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a: []const u8,
    });
    try testing.expectEqualStrings("900,50,50", simple.a);
}

test "multidoc typed as a slice of structs" {
    const source =
        \\---
        \\a: 0
        \\---
        \\a: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    {
        const result = try yaml.parse(arena.allocator(), [2]struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }

    {
        const result = try yaml.parse(arena.allocator(), []struct { a: usize });
        try testing.expectEqual(result.len, 2);
        try testing.expectEqual(result[0].a, 0);
        try testing.expectEqual(result[1].a, 1);
    }
}

test "multidoc typed as a struct is an error" {
    const source =
        \\---
        \\a: 0
        \\---
        \\b: 1
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { b: usize }));
    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), struct { a: usize, b: usize }));
}

test "multidoc typed as a slice of structs with optionals" {
    const source =
        \\---
        \\a: 0
        \\c: 1.0
        \\---
        \\a: 1
        \\b: different field
        \\...
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), []struct { a: usize, b: ?[]const u8, c: ?f16 });
    try testing.expectEqual(result.len, 2);

    try testing.expectEqual(result[0].a, 0);
    try testing.expect(result[0].b == null);
    try testing.expect(result[0].c != null);
    try testing.expectEqual(result[0].c.?, 1.0);

    try testing.expectEqual(result[1].a, 1);
    try testing.expect(result[1].b != null);
    try testing.expectEqualStrings("different field", result[1].b.?);
    try testing.expect(result[1].c == null);
}

test "empty yaml can be represented as void" {
    const source = "";

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const result = try yaml.parse(arena.allocator(), void);
    try testing.expect(@TypeOf(result) == void);
}

test "nonempty yaml cannot be represented as void" {
    const source =
        \\a: b
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.TypeMismatch, yaml.parse(arena.allocator(), void));
}

test "typed array size mismatch" {
    const source =
        \\- 0
        \\- 0
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [1]usize));
    try testing.expectError(Yaml.Error.ArraySizeMismatch, yaml.parse(arena.allocator(), [5]usize));
}

test "comments" {
    const source =
        \\
        \\key: # this is the key
        \\# first value
        \\
        \\- val1
        \\
        \\# second value
        \\- val2
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        key: []const []const u8,
    });
    try testing.expect(simple.key.len == 2);
    try testing.expectEqualStrings("val1", simple.key[0]);
    try testing.expectEqualStrings("val2", simple.key[1]);
}

test "promote ints to floats in a list mixed numeric types" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const simple = try yaml.parse(arena.allocator(), struct {
        a_list: []const f64,
    });
    try testing.expectEqualSlices(f64, &[_]f64{ 0.0, 1.0 }, simple.a_list);
}

test "demoting floats to ints in a list is an error" {
    const source =
        \\a_list: [0, 1.0]
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.InvalidCharacter, yaml.parse(arena.allocator(), struct {
        a_list: []const u64,
    }));
}

test "duplicate map keys" {
    const source =
        \\a: b
        \\a: c
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.DuplicateMapKey, yaml.load(testing.allocator));
}

fn testStringify(expected: []const u8, input: anytype) !void {
    var writer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer writer.deinit();

    try stringify(testing.allocator, input, &writer.writer);
    try testing.expectEqualStrings(expected, writer.written());
}

test "stringify an int" {
    try testStringify("128", @as(u32, 128));
}

test "stringify a simple struct" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });
}

test "stringify a struct with an optional" {
    try testStringify(
        \\a: 1
        \\b: 2
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = 2.0, .c = 2.5 });

    try testStringify(
        \\a: 1
        \\c: 2.5
    , struct { a: i64, b: ?f64, c: f64 }{ .a = 1, .b = null, .c = 2.5 });
}

test "stringify a struct with all optionals" {
    try testStringify("", struct { a: ?i64, b: ?f64 }{ .a = null, .b = null });
}

test "stringify an optional" {
    try testStringify("", null);
    try testStringify("", @as(?u64, null));
}

test "stringify a union" {
    const Dummy = union(enum) {
        x: u64,
        y: f64,
    };
    try testStringify("a: 1", struct { a: Dummy }{ .a = .{ .x = 1 } });
    try testStringify("a: 2.1", struct { a: Dummy }{ .a = .{ .y = 2.1 } });
}

test "stringify a string" {
    try testStringify("a: name", struct { a: []const u8 }{ .a = "name" });
    try testStringify("name", "name");
}

test "stringify a list" {
    try testStringify("[ 1, 2, 3 ]", @as([]const u64, &.{ 1, 2, 3 }));
    try testStringify("[ 1, 2, 3 ]", .{ @as(i64, 1), 2, 3 });
    try testStringify("[ 1, name, 3 ]", .{ 1, "name", 3 });

    const arr: [3]i64 = .{ 1, 2, 3 };
    try testStringify("[ 1, 2, 3 ]", arr);
}

test "pointer of a value" {
    const TestStruct = struct {
        a: usize,
        b: i64,
        c: u12,
        d: ?*const @This() = null,
    };

    const source =
        \\a: 1
        \\b: 2
        \\c: 3
        \\d:
        \\  a: 4
        \\  b: 5
        \\  c: 6
    ;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var yaml = Yaml{ .source = source };
    try yaml.load(arena.allocator());

    const parsed = try yaml.parse(arena.allocator(), *TestStruct);
    try testing.expectEqual(1, parsed.a);
    try testing.expectEqual(2, parsed.b);
    try testing.expectEqual(3, parsed.c);
    try testing.expectEqual(4, parsed.d.?.a);
    try testing.expectEqual(5, parsed.d.?.b);
    try testing.expectEqual(6, parsed.d.?.c);
    try testing.expectEqual(@as(?*const TestStruct, null), parsed.d.?.d);
}

test "struct default value test" {
    const TestStruct = struct {
        a: i32,
        b: ?[]const u8 = "test",
        c: ?u8 = 5,
        d: u8 = 12,
    };

    const TestCase = struct {
        yaml: []const u8,
        container: TestStruct,
    };

    const tcs = [_]TestCase{
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\c: 3
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "test",
                .c = 3,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\d: 1
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 1,
            },
        },
        .{
            .yaml =
            \\---
            \\a: 1
            \\b: "asd"
            \\...
            ,
            .container = .{
                .a = 1,
                .b = "asd",
                .c = 5,
                .d = 12,
            },
        },
    };

    for (&tcs) |tc| {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        var yamlParser = Yaml{ .source = tc.yaml };
        try yamlParser.load(arena.allocator());
        const parsed = try yamlParser.parse(arena.allocator(), TestStruct);
        try testing.expectEqual(tc.container.a, parsed.a);
        try testing.expectEqualDeep(tc.container.b, parsed.b);
        try testing.expectEqual(tc.container.c, parsed.c);
        try testing.expectEqual(tc.container.d, parsed.d);
    }
}

test "enums" {
    const source =
        \\- a
        \\- b
        \\- c
    ;

    const Enum = enum { a, b, c };

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), []const Enum);
    try testing.expectEqualDeep(&[_]Enum{
        .a,
        .b,
        .c,
    }, parsed);
}

test "stringify a bool" {
    try testStringify("false", false);
    try testStringify("true", true);
}

test "stringify an enum" {
    const TestEnum = enum {
        alpha,
        bravo,
        charlie,
    };

    try testStringify("alpha", TestEnum.alpha);
    try testStringify("bravo", TestEnum.bravo);
    try testStringify("charlie", TestEnum.charlie);
}

test "parse struct as list of structs" {
    const source =
        \\a: 1
    ;

    const Struct = struct { a: u32 };

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    // A single document is still a valid one-element list of documents.
    const as_list = try yaml.parse(arena.allocator(), []Struct);
    try testing.expectEqualDeep(@as([]const Struct, &.{.{ .a = 1 }}), @as([]const Struct, as_list));

    const as_array = try yaml.parse(arena.allocator(), [1]Struct);
    try testing.expectEqualDeep([1]Struct{.{ .a = 1 }}, as_array);

    // ... but only at the matching length.
    try testing.expectError(error.ArraySizeMismatch, yaml.parse(arena.allocator(), [2]Struct));

    const parsed = try yaml.parse(arena.allocator(), Struct);
    try testing.expectEqualDeep(Struct{ .a = 1 }, parsed);
}

// ---------------------------------------------------------------------------
// Regression tests for bugs found during audit.
// ---------------------------------------------------------------------------

test "flow mapping untyped" {
    const source =
        \\m: { a: 1, b: 2 }
        \\empty: {}
        \\spaced: { }
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const root = yaml.docs.items[0].map;
    const m = root.get("m").?.map;
    try testing.expectEqual(@as(usize, 2), m.count());
    try testing.expectEqualStrings("1", m.get("a").?.scalar);
    try testing.expectEqualStrings("2", m.get("b").?.scalar);
    try testing.expectEqual(@as(usize, 0), root.get("empty").?.map.count());
    try testing.expectEqual(@as(usize, 0), root.get("spaced").?.map.count());
}

test "flow mapping with trailing comma" {
    var yaml: Yaml = .{ .source = "{ a: 1, b: 2, }" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const m = yaml.docs.items[0].map;
    try testing.expectEqual(@as(usize, 2), m.count());
    try testing.expectEqualStrings("1", m.get("a").?.scalar);
}

test "flow mapping nested in flow sequence and vice versa" {
    var yaml: Yaml = .{ .source = "x: { a: [1, 2], b: { c: 3 } }" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const x = yaml.docs.items[0].map.get("x").?.map;
    try testing.expectEqual(@as(usize, 2), x.get("a").?.list.len);
    try testing.expectEqualStrings("3", x.get("b").?.map.get("c").?.scalar);
}

test "flow mapping typed as struct" {
    const S = struct { a: u32, b: u32 };
    var yaml: Yaml = .{ .source = "{ a: 10, b: 20 }" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();
    const s = try yaml.parse(arena.allocator(), S);
    try testing.expectEqualDeep(S{ .a = 10, .b = 20 }, s);
}

test "optional type at the top level" {
    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    var yaml: Yaml = .{ .source = "42" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const parsed = try yaml.parse(arena.allocator(), ?u32);
    try testing.expectEqual(@as(?u32, 42), parsed);
}

test "unterminated double quoted string is an error" {
    var yaml: Yaml = .{ .source = "key: \"unterminated" };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.UnterminatedString, yaml.load(testing.allocator));
}

test "unterminated single quoted string is an error" {
    var yaml: Yaml = .{ .source = "key: 'unterminated" };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.UnterminatedString, yaml.load(testing.allocator));
}

test "double quoted escape sequences" {
    const source =
        \\a: "tab\there"
        \\b: "line\nbreak"
        \\c: "carriage\rreturn"
        \\d: "back\\slash"
        \\e: "quote\"inside"
        \\f: "slash\/escaped"
    ;
    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const m = yaml.docs.items[0].map;
    try testing.expectEqualStrings("tab\there", m.get("a").?.scalar);
    try testing.expectEqualStrings("line\nbreak", m.get("b").?.scalar);
    try testing.expectEqualStrings("carriage\rreturn", m.get("c").?.scalar);
    try testing.expectEqualStrings("back\\slash", m.get("d").?.scalar);
    try testing.expectEqualStrings("quote\"inside", m.get("e").?.scalar);
    try testing.expectEqualStrings("slash/escaped", m.get("f").?.scalar);
}

test "double quoted string ending in escaped backslash" {
    var yaml: Yaml = .{ .source = "a: \"ends with\\\\\"" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    try testing.expectEqualStrings("ends with\\", yaml.docs.items[0].map.get("a").?.scalar);
}

test "invalid escape sequence is an error" {
    var yaml: Yaml = .{ .source = "a: \"bad\\xescape\"" };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.InvalidEscapeSequence, yaml.load(testing.allocator));
}

test "crlf line endings" {
    var yaml: Yaml = .{ .source = "a: 1\r\nb: 2\r\n" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const m = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1", m.get("a").?.scalar);
    try testing.expectEqualStrings("2", m.get("b").?.scalar);
}

test "lone carriage return is a line break" {
    var yaml: Yaml = .{ .source = "a: 1\rb: 2" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const m = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1", m.get("a").?.scalar);
    try testing.expectEqualStrings("2", m.get("b").?.scalar);
}

test "deeply nested map does not crash" {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(testing.allocator);
    for (0..500) |i| {
        for (0..i) |_| try buf.append(testing.allocator, ' ');
        try buf.appendSlice(testing.allocator, "k:\n");
    }

    var yaml: Yaml = .{ .source = buf.items };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    try testing.expectEqual(@as(usize, 1), yaml.docs.items.len);
}

test "map with trailing empty value" {
    // Exercises the value()-restores-position fix: a key whose value is empty
    // and is the last token before eof must not read past the token stream.
    var yaml: Yaml = .{ .source = "a: 1\nb:" };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    const m = yaml.docs.items[0].map;
    try testing.expectEqualStrings("1", m.get("a").?.scalar);
    try testing.expect(m.get("b").? == .empty);
}

test "duplicate key in a nested map frees the outer map exactly once" {
    const source =
        \\a:
        \\  b: 1
        \\  b: 2
        \\c: 3
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try testing.expectError(error.DuplicateMapKey, yaml.load(testing.allocator));
}

test "stringify a pointer to a struct" {
    const S = struct { a: i64, b: i64 };
    const s: S = .{ .a = 1, .b = 2 };
    try testStringify(
        \\a: 1
        \\b: 2
    , &s);
}

test "parse more documents than the target array holds" {
    const source =
        \\--- 1
        \\--- 2
        \\--- 3
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);
    try testing.expectEqual(@as(usize, 3), yaml.docs.items.len);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.ArraySizeMismatch, yaml.parse(arena.allocator(), [2]u8));
    try testing.expectEqualDeep([3]u8{ 1, 2, 3 }, try yaml.parse(arena.allocator(), [3]u8));
}

test "tab as separation after a map separator" {
    const source = "a:\tb\nc: 2\n";

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), struct { a: []const u8, c: u32 });
    try testing.expectEqualStrings("b", parsed.a);
    try testing.expectEqual(@as(u32, 2), parsed.c);
}

test "stringify nested maps through a small writer buffer" {
    // Deep enough that both the map and the nested-list indentation exceed
    // the writer buffer below.
    const source =
        \\a:
        \\    b:
        \\        c:
        \\            d: 1
        \\        e:
        \\            - f: 1
        \\              g: 2
        \\            - h: 3
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var allocating: std.Io.Writer.Allocating = .init(testing.allocator);
    defer allocating.deinit();
    try yaml.stringify(&allocating.writer);

    // A buffer narrower than the deepest indentation must not be assumed to
    // have room for it in one go.
    var buf: [8]u8 = undefined;
    var discarding: std.Io.Writer.Discarding = .init(&buf);
    try yaml.stringify(&discarding.writer);

    try testing.expectEqual(allocating.written().len, discarding.fullCount());
}

test "optional struct field with an explicit empty value" {
    const source =
        \\a: 1
        \\b:
    ;

    var yaml: Yaml = .{ .source = source };
    defer yaml.deinit(testing.allocator);
    try yaml.load(testing.allocator);

    var arena = Arena.init(testing.allocator);
    defer arena.deinit();

    const parsed = try yaml.parse(arena.allocator(), struct { a: u32, b: ?[]const u8 });
    try testing.expectEqual(@as(u32, 1), parsed.a);
    try testing.expectEqual(@as(?[]const u8, null), parsed.b);
}
