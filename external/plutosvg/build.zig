const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const plutovg = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    plutovg.addCSourceFiles(.{
        .files = &.{
            "lib/plutovg/source/plutovg-blend.c",
            "lib/plutovg/source/plutovg-canvas.c",
            "lib/plutovg/source/plutovg-font.c",
            "lib/plutovg/source/plutovg-ft-math.c",
            "lib/plutovg/source/plutovg-ft-raster.c",
            "lib/plutovg/source/plutovg-ft-stroker.c",
            "lib/plutovg/source/plutovg-matrix.c",
            "lib/plutovg/source/plutovg-paint.c",
            "lib/plutovg/source/plutovg-path.c",
            "lib/plutovg/source/plutovg-rasterize.c",
            "lib/plutovg/source/plutovg-surface.c",
        },
        .flags = &.{
            "-std=c11",
            "-DPLUTOVG_BUILD",
            "-DPLUTOVG_BUILD_STATIC",
        },
    });
    plutovg.addIncludePath(b.path("lib/plutovg/include/"));

    const plutosvg = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "plutovg", .module = plutovg },
        },
    });
    plutosvg.addCSourceFiles(.{
        .files = &.{
            "lib/plutosvg/source/plutosvg.c",
        },
        .flags = &.{
            "-std=c11",
            "-DPLUTOSVG_BUILD",
            "-DPLUTOSVG_BUILD_STATIC",
            "-DPLUTOVG_BUILD",
            "-DPLUTOVG_BUILD_STATIC",
        },
    });
    plutosvg.addIncludePath(b.path("lib/plutovg/include/"));

    const bindings = b.addModule("plutosvg", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/plutosvg.zig"),
        .link_libc = true,
        .imports = &.{
            .{ .name = "native", .module = plutosvg },
        },
    });
    bindings.addIncludePath(b.path("lib/plutovg/include/"));
}
