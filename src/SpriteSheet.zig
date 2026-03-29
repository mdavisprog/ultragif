const gif = @import("gif.zig");
const Image = @import("Image.zig");
const raylib = @import("raylib");
const std = @import("std");

pub const Frame = struct {
    bounds: raylib.Rectangle,
    delay: f32,
};

const Self = @This();

texture: raylib.Texture,
frames: []const Frame,
frame_size: raylib.Vector2 = .zero,

pub fn init(allocator: std.mem.Allocator, format: gif.Format) !Self {
    const gif_frames = try format.getFrames(allocator);
    defer gif_frames.deinit(allocator);

    const num_frames = gif_frames.data.len;
    var frames = try allocator.alloc(Frame, num_frames);
    errdefer allocator.free(frames);

    const columns: u32 = @min(num_frames, 8);
    var rows: u32 = @as(u32, @intCast(num_frames)) / columns;
    // Take into account any left over frames that needs its own row.
    rows += if (@mod(num_frames, columns) == 0) 0 else 1;

    const width: u32 = @intCast(format.logical_screen_descriptor.width);
    const height: u32 = @intCast(format.logical_screen_descriptor.height);

    // Represents the whole sprite sheet. Each frame gets its own cell within the sheet.
    var image: Image = try .init(allocator, columns * width, rows * height, .RGBA);
    defer image.deinit(allocator);

    var position: raylib.Vector2 = .zero;
    for (gif_frames.data, 0..) |frame, i| {
        // Advance into the y position if cursor has reached the end of the row.
        if (i > 0 and @mod(i, columns) == 0) {
            position.x = 0.0;
            position.y += @as(f32, @floatFromInt(height));
        }

        try image.copy(
            frame.image,
            @intFromFloat(position.x),
            @intFromFloat(position.y),
        );

        frames[i] = .{
            .bounds = .init(
                position.x,
                position.y,
                @floatFromInt(width),
                @floatFromInt(height),
            ),
            .delay = frame.delay_time,
        };

        position.x += @as(f32, @floatFromInt(width));
    }

    const texture = raylib.loadTextureFromImage(.init(
        @ptrCast(image.data),
        @intCast(image.width),
        @intCast(image.height),
        .uncompressed_r8g8b8a8,
    ));

    raylib.setTextureFilter(texture, .point);

    return .{
        .texture = texture,
        .frames = frames,
        .frame_size = .init(
            @floatFromInt(width),
            @floatFromInt(height),
        ),
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (raylib.isTextureValid(self.texture)) {
        raylib.unloadTexture(self.texture);
    }

    allocator.free(self.frames);
}

pub fn memorySize(self: Self) usize {
    const width: usize = @intCast(self.texture.width);
    const height: usize = @intCast(self.texture.height);
    return width * height * 4;
}

pub fn totalTime(self: Self) f32 {
    var result: f32 = 0.0;

    for (self.frames) |frame| {
        result += frame.delay;
    }

    return result;
}

pub fn toImage(self: Self, allocator: std.mem.Allocator) !Image {
    return try .fromTexture(allocator, self.texture);
}
