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

pub fn init(allocator: std.mem.Allocator, format: gif.Format) !Self {
    const images = try format.getImages(allocator);
    defer images.deinit(allocator);

    const num_frames = images.data.len;
    var frames = try allocator.alloc(Frame, num_frames);
    errdefer allocator.free(frames);

    const columns: u32 = 8;
    // Always include the first row.
    var rows: u32 = 1 + (@as(u32, @intCast(num_frames)) / columns);
    // Take into account any left over frames that needs its own row.
    rows += if (@mod(num_frames, columns) == 0) 0 else 1;

    const width: u32 = @intCast(format.logical_screen_descriptor.width);
    const height: u32 = @intCast(format.logical_screen_descriptor.height);

    var image: Image = try .init(allocator, columns * width, rows * height, .RGBA);
    defer image.deinit(allocator);

    var position: raylib.Vector2 = .zero;
    for (images.data, 0..) |data, i| {
        const left: u32 = @intCast(data.left);
        const top: u32 = @intCast(data.top);

        const frame_image: Image = .initWithData(@constCast(data.data), data.width, data.height, .RGBA);
        try image.copy(
            frame_image,
            @as(u32, @intFromFloat(position.x)) + left,
            @as(u32, @intFromFloat(position.y)) + top,
        );

        frames[i] = .{
            .bounds = .init(
                position.x,
                position.y,
                @floatFromInt(width),
                @floatFromInt(height),
            ),
            .delay = @as(f32, @floatFromInt(data.delay_time)) * 0.01,
        };

        position.x += @as(f32, @floatFromInt(width));
        if (i > 0 and @mod(i, columns - 1) == 0) {
            position.x = 0.0;
            position.y += @as(f32, @floatFromInt(height));
        }
    }

    const texture = raylib.loadTextureFromImage(.init(
        @ptrCast(image.data),
        @intCast(image.width),
        @intCast(image.height),
        .uncompressed_r8g8b8a8,
    ));

    return .{
        .texture = texture,
        .frames = frames,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (raylib.isTextureValid(self.texture)) {
        raylib.unloadTexture(self.texture);
    }

    allocator.free(self.frames);
}
