const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ultragif",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
            .imports = &.{
                .{ .name = "raylib", .module = raylib.module("raylib") },
            },
        }),
    });
    exe.linkLibrary(raylib.artifact("raylib"));

    b.installArtifact(exe);

    // Set up the 'run' step.
    const run_step = b.step("run", "Runs the application.");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Set up the 'test' step.
    const test_step = b.step("test", "Run tests");
    const exe_test = b.addTest(.{
        .root_module = exe.root_module,
    });
    const test_run = b.addRunArtifact(exe_test);
    test_step.dependOn(&test_run.step);
}
