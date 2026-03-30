const raylib = @import("raylib");
const std = @import("std");

/// Describes how the bytes in the image are represented.
pub const Format = enum {
    RGBA,

    pub fn fromRaylib(format: raylib.PixelFormat) Format {
        return switch (format) {
            .uncompressed_r8g8b8a8 => .RGBA,
            else => {
                std.debug.panic("Unsupported pixel format {s}", .{@tagName(format)});
            },
        };
    }

    pub fn bits(self: Format) u8 {
        return switch (self) {
            .RGBA => 32,
        };
    }

    pub fn bytes(self: Format) u8 {
        return self.bits() / 8;
    }

    fn size(self: Format, width: usize, height: usize) usize {
        return width * height * @as(usize, @intCast(self.bytes()));
    }
};

/// Possible error values.
pub const Error = error{
    InvalidPosition,
    FormatMismatch,
};

/// Represents a buffer of bytes in a specific format.
const Self = @This();

data: []u8,
format: Format,
width: u32,
height: u32,

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: Format) !Self {
    const len: usize = format.size(@intCast(width), @intCast(height));
    const data = try allocator.alloc(u8, len);
    @memset(data, 0);

    return .{
        .data = data,
        .format = format,
        .width = width,
        .height = height,
    };
}

pub fn initWithData(data: []u8, width: u32, height: u32, format: Format) Self {
    return .{
        .data = data,
        .format = format,
        .width = width,
        .height = height,
    };
}

pub fn fromTexture(allocator: std.mem.Allocator, texture: raylib.Texture2D) !Self {
    const image = raylib.loadImageFromTexture(texture);
    defer raylib.unloadImage(image);

    const data = try allocator.dupe(u8, image.getData());

    return .{
        .data = data,
        .width = @intCast(image.width),
        .height = @intCast(image.height),
        .format = .fromRaylib(image.getFormat()),
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.data);
}

pub fn put(self: *Self, color: raylib.Color, x: u32, y: u32) void {
    const idx = self.index(x, y);
    self.data[idx + 0] = color.r;
    self.data[idx + 1] = color.g;
    self.data[idx + 2] = color.b;
    self.data[idx + 3] = color.a;
}

pub fn fill(self: *Self, color: raylib.Color) void {
    for (0..self.height) |y| {
        for (0..self.width) |x| {
            const idx = self.index(@intCast(x), @intCast(y));
            self.data[idx + 0] = color.r;
            self.data[idx + 1] = color.g;
            self.data[idx + 2] = color.b;
            self.data[idx + 3] = color.a;
        }
    }
}

pub fn fillRegion(self: *Self, color: raylib.Color, x: u32, y: u32, width: u32, height: u32) void {
    for (y..height) |_y| {
        for (x..width) |_x| {
            const idx = self.index(@intCast(_x), @intCast(_y));
            self.data[idx + 0] = color.r;
            self.data[idx + 1] = color.g;
            self.data[idx + 2] = color.b;
            self.data[idx + 3] = color.a;
        }
    }
}

pub fn getRegion(
    self: Self,
    allocator: std.mem.Allocator,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = try .initCapacity(
        allocator,
        self.format.size(@intCast(width), @intCast(height)),
    );

    for (y..(y + height)) |_y| {
        for (x..(x + width)) |_x| {
            const idx = self.index(@intCast(_x), @intCast(_y));
            try result.appendSlice(allocator, &.{
                self.data[idx + 0],
                self.data[idx + 1],
                self.data[idx + 2],
                self.data[idx + 3],
            });
        }
    }

    return try result.toOwnedSlice(allocator);
}

pub fn getRegionRect(self: Self, allocator: std.mem.Allocator, rect: raylib.Rectangle) ![]u8 {
    return self.getRegion(
        allocator,
        @intFromFloat(rect.x),
        @intFromFloat(rect.y),
        @intFromFloat(rect.width),
        @intFromFloat(rect.height),
    );
}

pub fn copy(self: *Self, image: Self, x: u32, y: u32) !void {
    if (self.format != image.format) {
        return Error.FormatMismatch;
    }

    const min_x = x;
    const min_y = y;
    const max_x = min_x + image.width;
    const max_y = min_y + image.height;

    if (max_x > self.width or max_y > self.height) {
        return Error.InvalidPosition;
    }

    var src_y: usize = 0;
    for (@intCast(min_y)..@intCast(max_y)) |dst_y| {
        const dst_start: usize = self.index(@intCast(min_x), @intCast(dst_y));
        const dst_end: usize = self.index(@intCast(max_x), @intCast(dst_y));

        const src_start: usize = image.index(0, @intCast(src_y));
        const src_end: usize = image.index(@intCast(image.width), @intCast(src_y));

        const dst = self.data[dst_start..dst_end];
        const src = image.data[src_start..src_end];

        @memcpy(dst, src);
        src_y += 1;
    }
}

pub fn duplicate(self: Self, allocator: std.mem.Allocator) !Self {
    return .{
        .data = try allocator.dupe(u8, self.data),
        .width = self.width,
        .height = self.height,
        .format = self.format,
    };
}

pub fn index(self: Self, x: u32, y: u32) usize {
    const bpp = self.format.bytes();
    return y * self.width * bpp + x * bpp;
}

pub fn length(self: Self) usize {
    return self.format.size(@intCast(self.width), @intCast(self.height));
}

test "fill" {
    const allocator = std.testing.allocator;

    var image: Self = try .init(allocator, 2, 2, .RGBA);
    defer image.deinit(allocator);

    image.fill(.init(0, 0, 255, 255));

    for (0..image.height) |y| {
        for (0..image.width) |x| {
            const idx = image.index(@intCast(x), @intCast(y));
            try std.testing.expectEqual(0, image.data[idx + 0]);
            try std.testing.expectEqual(0, image.data[idx + 1]);
            try std.testing.expectEqual(255, image.data[idx + 2]);
            try std.testing.expectEqual(255, image.data[idx + 3]);
        }
    }
}

test "fill region" {
    const allocator = std.testing.allocator;

    var image: Self = try .init(allocator, 6, 6, .RGBA);
    defer image.deinit(allocator);

    const x: u32 = 2;
    const y: u32 = 2;
    const w: u32 = 2;
    const h: u32 = 2;
    const fill_color: raylib.Color = .init(255, 0, 0, 255);
    image.fillRegion(fill_color, x, y, w, h);

    for (0..image.height) |_y| {
        for (0..image.width) |_x| {
            const idx = image.index(@intCast(_x), @intCast(_y));
            const in_fill = _x >= x + w and x < x + w and _y >= y + h and _y < y + h;
            const color: raylib.Color = if (in_fill) fill_color else .blank;

            try std.testing.expectEqual(image.data[idx + 0], color.r);
            try std.testing.expectEqual(image.data[idx + 1], color.g);
            try std.testing.expectEqual(image.data[idx + 2], color.b);
            try std.testing.expectEqual(image.data[idx + 3], color.a);
        }
    }
}

test "copy" {
    const allocator = std.testing.allocator;

    var outer: Self = try .init(allocator, 6, 6, .RGBA);
    defer outer.deinit(allocator);
    outer.fill(.init(255, 0, 0, 255));

    var inner: Self = try .init(allocator, 2, 2, .RGBA);
    defer inner.deinit(allocator);
    inner.fill(.init(0, 0, 255, 255));

    const inner_x_min: u32 = 4;
    const inner_y_min: u32 = 4;
    const inner_x_max: u32 = inner_x_min + inner.width;
    const inner_y_max: u32 = inner_y_min + inner.height;
    try outer.copy(inner, inner_x_min, inner_y_min);

    for (0..outer.height) |y| {
        for (0..outer.width) |x| {
            const idx = outer.index(@intCast(x), @intCast(y));

            if (x >= inner_x_min and x < inner_x_max and y >= inner_y_min and y < inner_y_max) {
                try std.testing.expectEqual(0, outer.data[idx + 0]);
                try std.testing.expectEqual(0, outer.data[idx + 1]);
                try std.testing.expectEqual(255, outer.data[idx + 2]);
                try std.testing.expectEqual(255, outer.data[idx + 3]);
            } else {
                try std.testing.expectEqual(255, outer.data[idx + 0]);
                try std.testing.expectEqual(0, outer.data[idx + 1]);
                try std.testing.expectEqual(0, outer.data[idx + 2]);
                try std.testing.expectEqual(255, outer.data[idx + 3]);
            }
        }
    }
}

test "copy invalid position" {
    const allocator = std.testing.allocator;

    var outer: Self = try .init(allocator, 6, 6, .RGBA);
    defer outer.deinit(allocator);
    outer.fill(.init(255, 0, 0, 255));

    var inner: Self = try .init(allocator, 2, 2, .RGBA);
    defer inner.deinit(allocator);
    inner.fill(.init(0, 0, 255, 255));

    const err = outer.copy(inner, 6, 6);
    try std.testing.expectEqual(Error.InvalidPosition, err);
}
