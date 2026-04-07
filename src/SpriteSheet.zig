const gif = @import("gif.zig");
const Image = @import("Image.zig");
const raylib = @import("raylib");
const std = @import("std");

pub const Frame = struct {
    bounds: raylib.Rectangle,
    delay: f32,
};

/// Handles allocating an image to build a sprite sheet. User is responsible for freeing the
/// allocated memory.
pub const Builder = struct {
    image: Image,
    frames: []Frame,

    pub fn init(
        allocator: std.mem.Allocator,
        num_frames: usize,
        frame_size: raylib.Vector2,
    ) !Builder {
        const columns: u32 = @min(num_frames, 8);
        var rows: u32 = @as(u32, @intCast(num_frames)) / columns;
        // Take into account any left over frames that needs its own row.
        rows += if (@mod(num_frames, columns) == 0) 0 else 1;

        const width: u32 = @intFromFloat(frame_size.x);
        const height: u32 = @intFromFloat(frame_size.y);

        const image: Image = try .init(allocator, columns * width, rows * height, .RGBA);
        errdefer image.deinit(allocator);

        var position: raylib.Vector2 = .zero;
        var frames = try allocator.alloc(Frame, num_frames);
        for (0..num_frames) |i| {
            // Advance into the y position if cursor has reached the end of the row.
            if (i > 0 and @mod(i, columns) == 0) {
                position.x = 0.0;
                position.y += @as(f32, @floatFromInt(height));
            }

            frames[i] = .{
                .bounds = .init(
                    position.x,
                    position.y,
                    @floatFromInt(width),
                    @floatFromInt(height),
                ),
                .delay = 0.0,
            };

            position.x += @as(f32, @floatFromInt(width));
        }

        return .{
            .image = image,
            .frames = frames,
        };
    }

    pub fn deinit(self: Builder, allocator: std.mem.Allocator) void {
        self.image.deinit(allocator);
        allocator.free(self.frames);
    }

    pub fn setFrameImage(self: *Builder, image: Image, frame_index: usize, delay: f32) !void {
        if (self.image.format != image.format) {
            return error.InvalidFormat;
        }

        var frame: *Frame = &self.frames[frame_index];
        frame.delay = delay;

        if (@as(u32, @intFromFloat(frame.bounds.width)) != image.width) {
            return error.InvalidSize;
        }

        if (@as(u32, @intFromFloat(frame.bounds.height)) != image.height) {
            return error.InvalidSize;
        }

        try self.image.copy(image, @intFromFloat(frame.bounds.x), @intFromFloat(frame.bounds.y));
    }
};

const Self = @This();

texture: raylib.Texture,
frames: []const Frame,
frame_size: raylib.Vector2 = .zero,

pub fn init(allocator: std.mem.Allocator, format: gif.Format) !Self {
    const gif_frames = try format.getFrames(allocator);
    defer gif_frames.deinit(allocator);

    const num_frames = gif_frames.data.len;

    const width: u32 = @intCast(format.logical_screen_descriptor.width);
    const height: u32 = @intCast(format.logical_screen_descriptor.height);

    var builder: Builder = try .init(allocator, num_frames, .init(
        @floatFromInt(width),
        @floatFromInt(height),
    ));
    defer builder.image.deinit(allocator);

    for (gif_frames.data, 0..) |frame, i| {
        try builder.setFrameImage(frame.image, i, frame.delay_time);
    }

    const texture = raylib.loadTextureFromImage(.init(
        @ptrCast(builder.image.data),
        @intCast(builder.image.width),
        @intCast(builder.image.height),
        .uncompressed_r8g8b8a8,
    ));

    raylib.setTextureFilter(texture, .point);

    return .{
        .texture = texture,
        .frames = builder.frames,
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

pub fn getFrameTimes(self: Self, allocator: std.mem.Allocator) ![]f32 {
    if (self.frames.len < 2) {
        return &.{};
    }

    var result: std.ArrayListUnmanaged(f32) = .empty;

    var time: f32 = 0.0;
    for (self.frames) |frame| {
        time += frame.delay;
        try result.append(allocator, time);
    }

    return try result.toOwnedSlice(allocator);
}

pub fn toImage(self: Self, allocator: std.mem.Allocator) !Image {
    return try .fromTexture(allocator, self.texture);
}
