const raylib = @import("raylib");
const std = @import("std");

/// Describes how the bytes in the image are represented.
pub const Format = enum {
    RGBA,

    pub fn bits(self: Format) u8 {
        return switch (self) {
            .RGBA => 32,
        };
    }

    pub fn bytes(self: Format) u8 {
        return self.bits() / 8;
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
    const len: usize = @intCast(width * height * @as(u32, @intCast(format.bytes())));
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

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self.data);
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

pub fn index(self: Self, x: u32, y: u32) usize {
    const bpp = self.format.bytes();
    return y * self.width * bpp + x * bpp;
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
