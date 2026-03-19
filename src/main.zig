const App = @import("App.zig");
const build_config = @import("build_config");
const gif = @import("gif.zig");
const Image = @import("Image.zig");
const log = @import("log.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const Viewport = @import("Viewport.zig");
const version = @import("version");

pub const std_options = log.options;

pub fn main() !void {
    std.log.info("Starting up UltraGIF version {s}...", .{version.full});

    var heap = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = heap.deinit();

    const allocator = heap.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    log.init(!build_config.shipping);

    const config_flags = @as(u32, @intFromEnum(raylib.ConfigFlags.window_highdpi));
    const window_flags = @as(u32, @intFromEnum(raylib.ConfigFlags.vsync_hint)) |
        @as(u32, @intFromEnum(raylib.ConfigFlags.window_resizable));

    raylib.setConfigFlags(config_flags);
    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setWindowState(window_flags);
    raylib.setTargetFPS(60);

    const app: *App = try .init(allocator);
    defer {
        app.deinit();
        allocator.destroy(app);
    }

    while (!raylib.windowShouldClose()) {
        const delta_time = raylib.getFrameTime();

        try app.update(delta_time);

        // Drawing logic
        raylib.beginDrawing();
        app.draw();
        raylib.endDrawing();
    }

    raylib.closeWindow();
}

test {
    _ = @import("Atlas.zig");
    _ = @import("Image.zig");
}
