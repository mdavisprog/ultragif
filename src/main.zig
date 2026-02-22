const gif = @import("gif.zig");
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello UltraGIF!\n", .{});

    var heap = std.heap.GeneralPurposeAllocator(.{}).init;
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

    if (!try gif.load(allocator, absolute_path)) {
        return;
    }

    std.debug.print("Successfully loaded GIF file '{s}'.", .{path});
}
