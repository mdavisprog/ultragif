const canvas = @import("canvas/root.zig");
const colors = @import("colors.zig");
const gif = @import("gif.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const TextureCache = @import("TextureCache.zig");

const Texture = TextureCache.Texture;

const Self = @This();

scene: *const canvas.Scene,

pub fn init(scene: *const canvas.Scene) Self {
    return .{ .scene = scene };
}

/// This function must be called between raylibs BeginDrawing/EndDrawing block.
pub fn exportScene(self: Self, allocator: std.mem.Allocator) !void {
    const animations = try self.scene.getObjects(allocator, canvas.Animation);
    defer allocator.free(animations);

    if (animations.len == 0) {
        std.log.info("No animations available to export.", .{});
        return;
    }

    std.log.info("Exporting {} animations", .{animations.len});

    // Figure out the bounds of the canvas that needs to be exported.
    // Store the animation with the longest time.
    var max_time: f32 = 0.0;
    var min: raylib.Vector2 = .init(std.math.floatMax(f32), std.math.floatMax(f32));
    var max: raylib.Vector2 = .init(-min.x, -min.y);
    for (animations) |animation| {
        const bounds = animation.bounds();
        min.x = @min(min.x, bounds.x);
        min.y = @min(min.y, bounds.y);

        const bounds_max = bounds.max();
        max.x = @max(max.x, bounds_max.x);
        max.y = @max(max.y, bounds_max.y);

        const anim = animation.as(canvas.Animation);
        max_time = @max(max_time, anim.max_frame_time);
    }

    var times: std.ArrayListUnmanaged(f32) = .empty;
    defer times.deinit(allocator);

    // Loop through each animation and store what the elapsed time will be. Any animation that
    // is shorter than the max time will be looped until the max time is reached.
    for (animations) |animation| {
        const anim = animation.as(canvas.Animation);

        var elapsed: f32 = 0.0;
        while (elapsed < max_time) {
            for (anim.texture.sheet.frames) |frame| {
                elapsed += frame.delay;

                if (elapsed > max_time) {
                    break;
                }

                try times.append(allocator, elapsed);
            }
        }
    }

    // Sort the times in ascending order.
    std.mem.sort(f32, times.items, {}, sortTimes);

    var remove: std.ArrayListUnmanaged(usize) = .empty;
    defer remove.deinit(allocator);

    // Remove any times that are less than 0.01 seconds in length. GIFs don't support precisions
    // higher than this so eliminate these frames.
    var previous: f32 = 0.0;
    for (times.items, 0..) |time, i| {
        const delta = time - previous;
        previous = time;

        const delay: u16 = @intFromFloat(@round(delta * 100.0));
        if (delay <= 1) {
            try remove.append(allocator, i);
        }
    }
    times.orderedRemoveMany(remove.items);

    // Create a render target to render each frame to. The contents of this rendered texture
    // will be used to place frames inside the GIF.
    const framebuffer = raylib.loadRenderTexture(raylib.getScreenWidth(), raylib.getScreenHeight());
    defer raylib.unloadRenderTexture(framebuffer);

    const bounds: raylib.Rectangle = .init(min.x, min.y, max.x - min.x, max.y - min.y);
    var builder: SpriteSheet.Builder = try .init(allocator, times.items.len, .init(bounds.width, bounds.height));
    defer builder.deinit(allocator);

    // Reset and advance by each delay time from the gathered times above from all animations.
    self.scene.resetAnimationTimes();

    previous = 0.0;
    for (times.items, 0..) |time, i| {
        const delay = time - previous;
        previous = time;

        // TODO: Determine which animation frame changed and only update the bounds of that
        // animation.
        const image = try self.renderFrame(framebuffer, bounds);
        try builder.setFrameImage(.fromRaylibImage(image), i, delay);

        self.scene.advanceTime(delay);
    }

    try exportSpriteSheet(allocator, builder);
}

fn renderFrame(
    self: Self,
    framebuffer: raylib.RenderTexture2D,
    bounds: raylib.Rectangle,
) !raylib.Image {
    raylib.beginTextureMode(framebuffer);
    self.scene.drawClearBackground();
    raylib.endTextureMode();

    var image = raylib.loadImageFromTexture(framebuffer.texture);

    raylib.imageFlipVertical(&image);
    raylib.imageCrop(&image, bounds);

    return image;
}

fn exportSpriteSheet(allocator: std.mem.Allocator, builder: SpriteSheet.Builder) !void {
    var gif_writer: gif.Writer = try .init(allocator);
    defer gif_writer.deinit();

    var image_writer: std.Io.Writer.Allocating = .init(allocator);
    defer image_writer.deinit();

    var table: colors.ColorTable = try .initImage(allocator, builder.image, .{
        .ignore_transparent = true,
    });
    defer table.deinit();

    var quantized = try table.quantize(255);
    defer quantized.deinit();

    gif_writer.setGlobalColorTable(try quantized.table.toBytes(3));

    var indexer: colors.Indexer = .initQuantized(&quantized);
    try indexer.setTransparentColor(.init(204, 75, 202, 255));

    for (builder.frames, 0..) |frame, i| {
        // The first frame should take up the whole screen.
        if (i == 0) {
            gif_writer.logical_screen_desc.width = @intFromFloat(frame.bounds.width);
            gif_writer.logical_screen_desc.height = @intFromFloat(frame.bounds.height);
        }

        // TODO: Only render the part of the image associated with a specific animation.
        const width: u32 = @intFromFloat(frame.bounds.width);
        const height: u32 = @intFromFloat(frame.bounds.height);

        const frame_data = try builder.image.getRegionRect(allocator, frame.bounds);
        defer allocator.free(frame_data);

        const indexed_data = try indexer.indexImage(.initWithData(
            frame_data, 
            width,
            height,
            .RGBA,
        ));
        defer indexed_data.deinit(allocator);

        try gif_writer.addImage(
            0,
            0,
            @intCast(width),
            @intCast(height),
            indexed_data.data,
            frame.delay,
            if (indexer.transparent_index) |index| @intCast(index) else null,
        );
    }

    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const path = try std.fmt.allocPrint(allocator, "{s}/export.gif", .{exe_dir});
    defer allocator.free(path);

    try gif_writer.save(path);
    std.log.info("GIF exported to '{s}'.", .{path});
}

fn sortTimes(_: void, lhs: f32, rhs: f32) bool {
    return lhs < rhs;
}
