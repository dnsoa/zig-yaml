const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The public module consumers import as `@import("yaml")`.
    const mod = b.addModule("yaml", .{
        .root_source_file = b.path("lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests covering the whole library.
    const lib_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
