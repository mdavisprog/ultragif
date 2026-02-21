const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ultragif",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
        })
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Runs the application.");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
