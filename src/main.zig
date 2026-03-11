const Animator = @import("Animator.zig");
const App = @import("App.zig");
const Camera = @import("Camera.zig");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
const Image = @import("Image.zig");
const log = @import("log.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const Viewport = @import("Viewport.zig");

pub const std_options = log.options;

pub fn main() !void {
    std.log.info("Hello UltraGIF!", .{});

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

    log.init();

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

    var camera: Camera = .{};
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

        // Reset the camera
        if (raylib.isKeyPressed(.r)) {
            focusGIF(&camera, gui_container.canvasBounds(), app);
        }

        // Only allow canvas input when mouse is not hovering GUI.
        if (!gui_container.contains(raylib.getMousePosition())) {
            // Begin pan and disable the mouse
            if (raylib.isMouseButtonPressed(.left)) {
                locked_mouse_pos = raylib.getMousePosition();
                raylib.disableCursor();
                camera.panning = true;
            }

            // Update zoom
            const wheel_delta = raylib.getMouseWheelMoveV();
            if (wheel_delta.y != 0.0) {
                camera.zoomToMouse(wheel_delta.y);
            }
        }

        // End pan and enable the mouse. Reset position back to begin position
        if (raylib.isMouseButtonReleased(.left)) {
            if (camera.panning) {
                raylib.enableCursor();
                raylib.setMousePosition(@intFromFloat(locked_mouse_pos.x), @intFromFloat(locked_mouse_pos.y));
            }
            camera.panning = false;
        }

        camera.update();

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
                    focusGIF(&camera, gui_container.canvasBounds(), app);
                }
            }
        }

        gui_container.update();

        // Drawing logic
        raylib.beginDrawing();

        // Draw canvas
        camera.begin();
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

        camera.end();

        // Draw GUI
        gui_container.draw();

        raylib.endDrawing();
    }

    raylib.closeWindow();
}

fn focusGIF(camera: *Camera, canvas_bounds: raylib.Rectangle, app: *App) void {
    const loaded_gif = app.loaded_gif orelse return;
    const frame_size = loaded_gif.sprite_sheet.frame_size;

    camera.reset();
    camera.state.target = .init(
        canvas_bounds.width * -0.5 + frame_size.x * 0.5,
        canvas_bounds.height * -0.5 + frame_size.y * 0.5,
    );
}

test {
    _ = @import("Atlas.zig");
    _ = @import("Image.zig");
}
