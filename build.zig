const std = @import("std");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clay = b.dependency("clay", .{
        .target = target,
        .optimize = optimize,
    });

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
                .{ .name = "clay", .module = clay.module("root") },
                .{ .name = "raylib", .module = raylib.module("raylib") },
            },
        }),
    });
    exe.linkLibrary(raylib.artifact("raylib"));

    const version_string = zon.version;
    const version = std.SemanticVersion.parse(version_string) catch |err| {
        std.log.err("Failed to parse semantic version from zon.\n{any}", .{err});
        return;
    };

    const version_options = b.addOptions();
    version_options.addOption([]const u8, "full", version_string);
    version_options.addOption(usize, "major", version.major);
    version_options.addOption(usize, "minor", version.minor);
    version_options.addOption(usize, "patch", version.patch);
    exe.root_module.addOptions("version", version_options);

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
