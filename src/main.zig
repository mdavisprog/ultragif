const gif = @import("gif.zig");
const raylib = @import("raylib");
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello UltraGIF!\n", .{});

    var heap = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = heap.deinit();

    const allocator = heap.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            "Argument was not given. The .gif file to load must be given as the first argument.",
            .{},
        );
        return;
    }

    const path = args[1];
    const absolute_path = try std.fs.cwd().realpathAlloc(allocator, path);
    defer allocator.free(absolute_path);

    const format = try gif.load(allocator, absolute_path);
    defer format.deinit(allocator);

    std.debug.print("Successfully loaded GIF file '{s}'.\n", .{path});

    const images = try format.getImages(allocator);
    defer images.deinit(allocator);

    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setTargetFPS(60);

    while (!raylib.windowShouldClose()) {
        raylib.beginDrawing();
        raylib.clearBackground(.darkgray);
        raylib.endDrawing();
    }

    raylib.closeWindow();
}

test {
    _ = @import("Atlas.zig");
}
