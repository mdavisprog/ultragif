const Animator = @import("Animator.zig");
const App = @import("App.zig");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
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

    const flags = @as(u32, @intFromEnum(raylib.ConfigFlags.vsync_hint)) |
        @as(u32, @intFromEnum(raylib.ConfigFlags.window_resizable)) |
        @as(u32, @intFromEnum(raylib.ConfigFlags.window_highdpi));

    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setWindowState(flags);
    raylib.setTargetFPS(60);

    var gui_container: gui.Container = try .init(allocator, app);
    defer gui_container.deinit(allocator);

    var animator: Animator = .{};

    var camera: raylib.Camera2D = .{};
    var locked_mouse_pos: raylib.Vector2 = .zero;
    var panning = false;
    const zoom_amount: f32 = 0.05;

    while (!raylib.windowShouldClose()) {
        const delta_time = raylib.getFrameTime();

        // Update sprite sheet animation
        animator.update(delta_time);

        // Reset the camera
        if (raylib.isKeyPressed(.r)) {
            camera.target = .zero;
            camera.offset = .zero;
            camera.zoom = 1.0;
        }

        // Only allow canvas input when mouse is not hovering GUI.
        if (!gui_container.contains(raylib.getMousePosition())) {
            // Begin pan and disable the mouse
            if (raylib.isMouseButtonPressed(.left)) {
                locked_mouse_pos = raylib.getMousePosition();
                raylib.disableCursor();
                panning = true;
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
        }

        // End pan and enable the mouse. Reset position back to begin position
        if (raylib.isMouseButtonReleased(.left)) {
            if (panning) {
                raylib.enableCursor();
                raylib.setMousePosition(@intFromFloat(locked_mouse_pos.x), @intFromFloat(locked_mouse_pos.y));
            }
            panning = false;
        }

        // Translate the camera
        if (panning) {
            const mouse_delta = raylib.getMouseDelta().scale(-1.0 / camera.zoom);
            camera.target.addMut(mouse_delta);
        }

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
                }
            }
        }

        gui_container.update();

        // Drawing logic
        raylib.beginDrawing();

        // Draw canvas
        raylib.beginMode2D(camera);
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

        raylib.endMode2D();

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
