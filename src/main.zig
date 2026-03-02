const gif = @import("gif.zig");
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

    raylib.initWindow(960, 540, "UltraGIF");
    raylib.setTargetFPS(60);

    const sprite_sheet: SpriteSheet = try .init(allocator, format);
    defer sprite_sheet.deinit(allocator);

    var frame_index: usize = 0;
    var frame_time: f32 = 0.0;
    var show_texture = false;

    while (!raylib.windowShouldClose()) {
        const delta_time = raylib.getFrameTime();

        frame_time += delta_time;
        const frame = sprite_sheet.frames[frame_index];
        if (frame_time >= frame.delay) {
            frame_index = @mod(frame_index + 1, sprite_sheet.frames.len);
            frame_time = 0.0;
        }

        if (raylib.isKeyPressed(.t)) {
            show_texture = !show_texture;
        }

        raylib.beginDrawing();
        raylib.clearBackground(.darkgray);

        if (show_texture) {
            raylib.drawTextureV(sprite_sheet.texture, .zero, .white);
        } else {
            raylib.drawTexturePro(
                sprite_sheet.texture,
                frame.bounds,
                .init(0.0, 0.0, frame.bounds.width, frame.bounds.height),
                .zero,
                0.0,
                .white,
            );
        }

        raylib.endDrawing();
    }

    raylib.closeWindow();
}

test {
    _ = @import("Atlas.zig");
    _ = @import("Image.zig");
}
