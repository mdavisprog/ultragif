const Animator = @import("Animator.zig");
const App = @import("App.zig");
const build_config = @import("build_config");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
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

    const app = try allocator.create(App);
    app.* = .init();
    defer {
        app.deinit(allocator);
        allocator.destroy(app);
    }

    log.init(!build_config.shipping);

    const config_flags = @as(u32, @intFromEnum(raylib.ConfigFlags.window_highdpi));
    const window_flags = @as(u32, @intFromEnum(raylib.ConfigFlags.vsync_hint)) |
        @as(u32, @intFromEnum(raylib.ConfigFlags.window_resizable));

    raylib.setConfigFlags(config_flags);
    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setWindowState(window_flags);
    raylib.setTargetFPS(60);

    var gui_container: gui.Container = try .init(allocator, app);
    defer gui_container.deinit(allocator);

    var animator: Animator = .{};

    var locked_mouse_pos: raylib.Vector2 = .zero;

    var viewport: Viewport = .init();

    while (!raylib.windowShouldClose()) {
        const delta_time = raylib.getFrameTime();

        switch (viewport.nextEvent()) {
            .size_changed => |size| {
                gui_container.frameResized(size.previous, size.current);
            },
            else => {},
        }

        // Update sprite sheet animation
        animator.update(delta_time);

        if (gui_container.isMouseInCanvas()) {
            // Begin pan and disable the mouse
            if (raylib.isMouseButtonPressed(.left)) {
                locked_mouse_pos = raylib.getMousePosition();
                raylib.disableCursor();
                app.camera.panning = true;
            }

            // Update zoom
            const wheel_delta = raylib.getMouseWheelMoveV();
            if (wheel_delta.y != 0.0) {
                app.camera.zoomToMouse(wheel_delta.y);
            }
        }

        // End pan and enable the mouse. Reset position back to begin position
        if (raylib.isMouseButtonReleased(.left)) {
            if (app.camera.panning) {
                raylib.enableCursor();
                raylib.setMousePosition(@intFromFloat(locked_mouse_pos.x), @intFromFloat(locked_mouse_pos.y));
            }
            app.camera.panning = false;
        }

        app.camera.update();

        // Check for dropped files
        if (raylib.isFileDropped()) {
            const files = raylib.loadDroppedFiles();
            defer raylib.unloadDroppedFiles(files);

            const paths = files.getPaths();
            if (paths.len > 0) {
                const path = std.mem.span(paths[0]);
                try app.loadGIF(allocator, path);
                try gui_container.loadedGIF(allocator);

                if (app.loaded_gif) |loaded_gif| {
                    animator.set(&loaded_gif.sprite_sheet);
                    app.focusGIF(gui_container.canvas.bounds());
                }
            }
        }

        gui_container.update();

        // Drawing logic
        raylib.beginDrawing();

        // Draw canvas
        app.camera.begin();
        raylib.clearBackground(.darkgray);

        if (app.loaded_gif) |loaded_gif| {
            if (app.show_sprite_sheet) {
                raylib.drawTextureV(loaded_gif.sprite_sheet.texture, .zero, .white);
            } else {
                const frame = animator.getFrame();
                raylib.drawTexturePro(
                    loaded_gif.sprite_sheet.texture,
                    frame,
                    .init(0.0, 0.0, frame.width, frame.height),
                    .zero,
                    0.0,
                    .white,
                );
            }
        }

        app.camera.end();

        // Draw GUI
        gui_container.draw();

        raylib.endDrawing();
    }

    raylib.closeWindow();
}

test {
    _ = @import("Atlas.zig");
    _ = @import("Image.zig");
}
