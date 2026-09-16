# zig-yaml

A YAML parser for Zig, targeting Zig `0.16.0`. It aims to be YAML 1.2 compatible,
one step at a time. This is a fork of [kubkon/zig-yaml](https://github.com/kubkon/zig-yaml).

## Features

* explicit documents (`---`, `...`) and directives (`--- !tag`)
* block and flow mappings (`key: value`, `{ a: 1, b: 2 }`)
* block and flow sequences (`- item`, `[ a, b, c ]`)
* single- and double-quoted scalars with escape sequences
* multiple documents per source
* typed parsing into Zig structs, unions, enums, arrays, slices, optionals,
  ints, floats and booleans
* serialization (`stringify`) of Zig values to YAML

## Building and testing

```
zig build test
```

The library is exposed as a module named `yaml` (root source file `lib.zig`).

## Usage

Add the dependency to your project:

```
zig fetch --save <url-to-this-repo-archive>
```

Then wire it into your `build.zig`:

```zig
const yaml = b.dependency("yaml", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("yaml", yaml.module("yaml"));
```

And use it from your code:

```zig
const std = @import("std");
const Yaml = @import("yaml").Yaml;

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const source =
        \\names: [ John Doe, MacIntosh, Jane Austin ]
        \\numbers: [ 10, -8, 6 ]
    ;

    var untyped: Yaml = .{ .source = source };
    defer untyped.deinit(gpa);
    try untyped.load(gpa);

    // Access the untyped document tree.
    const map = untyped.docs.items[0].map;
    std.debug.print("first name: {s}\n", .{map.get("names").?.list[0].scalar});

    // Or parse into a typed structure.
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const Simple = struct {
        names: []const []const u8,
        numbers: []const i16,
    };
    const parsed = try untyped.parse(arena.allocator(), Simple);
    std.debug.print("first number: {d}\n", .{parsed.numbers[0]});
}
```

## License

MIT. See [LICENSE](LICENSE).
