const App = @import("App.zig");
const gif = @import("gif.zig");
const GUI = @import("GUI.zig");
const Image = @import("Image.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello UltraGIF!\n", .{});

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

    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setTargetFPS(60);

    var gui: GUI = try .init(allocator, app);
    defer gui.deinit(allocator);

    var frame_index: usize = 0;
    var frame_time: f32 = 0.0;
    var show_texture = false;

    var camera: raylib.Camera2D = .{};
    var locked_mouse_pos: raylib.Vector2 = .zero;
    const zoom_amount: f32 = 0.05;

    while (!raylib.windowShouldClose()) {
        const delta_time = raylib.getFrameTime();

        // Update sprite sheet animation
        if (app.loaded_gif) |loaded_gif| {
            frame_time += delta_time;
            const frame = loaded_gif.sprite_sheet.frames[frame_index];
            if (frame_time >= frame.delay) {
                frame_index = @mod(frame_index + 1, loaded_gif.sprite_sheet.frames.len);
                frame_time = 0.0;
            }
        }

        // Toggle sprite sheet/texture
        if (raylib.isKeyPressed(.t)) {
            show_texture = !show_texture;
        }

        // Reset the camera
        if (raylib.isKeyPressed(.r)) {
            camera.target = .zero;
            camera.offset = .zero;
            camera.zoom = 1.0;
        }

        // Begin pan and disable the mouse
        if (raylib.isMouseButtonPressed(.left)) {
            locked_mouse_pos = raylib.getMousePosition();
            raylib.disableCursor();
        }

        // End pan and enable the mouse. Reset position back to begin position
        if (raylib.isMouseButtonReleased(.left)) {
            raylib.enableCursor();
            raylib.setMousePosition(@intFromFloat(locked_mouse_pos.x), @intFromFloat(locked_mouse_pos.y));
        }

        // Translate the camera
        if (raylib.isMouseButtonDown(.left)) {
            const mouse_delta = raylib.getMouseDelta().scale(-1.0 / camera.zoom);
            camera.target.addMut(mouse_delta);
        }

        // Update zoom
        const wheel_delta = raylib.getMouseWheelMoveV();
        if (wheel_delta.y != 0.0) {
            const mouse_pos = raylib.getMousePosition();
            const world_pos = raylib.getScreenToWorld2D(mouse_pos, camera);

            camera.offset = mouse_pos;
            camera.target = world_pos;
            camera.zoom += zoom_amount * wheel_delta.y;
        }

        // Check for dropped files
        if (raylib.isFileDropped()) {
            const files = raylib.loadDroppedFiles();
            defer raylib.unloadDroppedFiles(files);

            const paths = files.getPaths();
            if (paths.len > 0) {
                const path = std.mem.span(paths[0]);
                try app.loadGIF(allocator, path);
                frame_time = 0.0;
                frame_index = 0;
            }
        }

        // Drawing logic
        raylib.beginDrawing();

        // Draw canvas
        raylib.beginMode2D(camera);
        raylib.clearBackground(.darkgray);

        if (app.loaded_gif) |loaded_gif| {
            if (show_texture) {
                raylib.drawTextureV(loaded_gif.sprite_sheet.texture, .zero, .white);
            } else {
                const frame = loaded_gif.sprite_sheet.frames[frame_index];
                raylib.drawTexturePro(
                    loaded_gif.sprite_sheet.texture,
                    frame.bounds,
                    .init(0.0, 0.0, frame.bounds.width, frame.bounds.height),
                    .zero,
                    0.0,
                    .white,
                );
            }
        }

        raylib.endMode2D();

        // Draw GUI
        gui.draw();

        raylib.endDrawing();
    }

    raylib.closeWindow();
}

test {
    _ = @import("Atlas.zig");
    _ = @import("Image.zig");
}
