const Image = @import("Image.zig");
const std = @import("std");

pub const Color3Table = ColorTable(Color3);
pub const Color4Table = ColorTable(Color4);

/// 3-component color.
pub const Color3 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn init(r: u8, g: u8, b: u8) Color3 {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn eql(self: Color3, value: Color3) bool {
        return self.r == value.r and self.g == value.g and self.b == value.b;
    }

    pub fn format(self: Color3, writer: *std.Io.Writer) !void {
        try writer.print("{} {} {}", .{ self.r, self.g, self.b });
    }
};

/// 4-component color.
pub const Color4 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color4 {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn eql(self: Color4, value: Color4) bool {
        return self.r == value.r and
            self.g == value.g and
            self.b == value.b and
            self.a == value.a;
    }

    pub fn toColor3(self: Color4) Color3 {
        return .init(self.r, self.g, self.b);
    }

    pub fn format(self: Color4, writer: *std.Io.Writer) !void {
        try writer.print("{} {} {} {}", .{ self.r, self.g, self.b, self.a });
    }
};

/// A Color3 table with an entry reserved as the tranparent color.
///
/// TODO: Properly handle changing transparent color if the given color equals it. The transparent
/// color could be chosen by the user instead of generating one.
pub const Color3TableTransparency = struct {
    const transparent_color: Color3 = .init(204, 75, 202);

    table: Color3Table,
    transparent_index: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator) Color3TableTransparency {
        return .{ .table = .init(allocator) };
    }

    pub fn initFromImage(allocator: std.mem.Allocator, image: Image) !Color3TableTransparency {
        var result: Color3TableTransparency = .init(allocator);

        switch (image.format) {
            .RGBA => {
                var index: usize = 0;
                while (index < image.length()) : (index += 4) {
                    const color: Color4 = .init(
                        image.data[index + 0],
                        image.data[index + 1],
                        image.data[index + 2],
                        image.data[index + 3],
                    );

                    _ = try result.add(color);
                }
            },
        }

        return result;
    }

    pub fn deinit(self: *Color3TableTransparency) void {
        self.table.deinit();
    }

    pub fn add(self: *Color3TableTransparency, color: Color4) !u32 {
        if (color.a == 0) {
            if (self.transparent_index) |index| {
                return index;
            }

            self.transparent_index = try self.table.add(transparent_color);
            return self.transparent_index.?;
        }

        return self.table.add(color.toColor3());
    }

    pub fn count(self: Color3TableTransparency) usize {
        return self.table.count();
    }

    pub fn toBytes(self: Color3TableTransparency) ![]u8 {
        return self.table.toBytes();
    }

    /// Caller owns the returned memory.
    pub fn indexImage(self: Color3TableTransparency, image: Image) ![]u8 {
        const len = @as(usize, @intCast(image.width)) * @as(usize, @intCast(image.height));
        var result = try self.table.getAllocator().alloc(u8, len);

        for (0..len) |index| {
            const src_index = index * image.format.bytes();
            const color: Color3 = .init(
                image.data[src_index + 0],
                image.data[src_index + 1],
                image.data[src_index + 2],
            );

            const color_index = self.table.get(color) orelse if (self.transparent_index) |t_index|
                t_index
            else
                0;
            result[index] = @intCast(color_index);
        }

        return result;
    }

    pub fn format(self: Color3TableTransparency, writer: *std.Io.Writer) !void {
        if (self.transparent_index) |index| {
            try writer.print("transparent_index: {}\n", .{index});
        } else {
            try writer.print("transparent_index: null\n", .{});
        }

        try writer.print("{f}", .{self.table});
    }
};

fn ColorTable(comptime T: type) type {
    if (T != Color3 and T != Color4) {
        @compileError(std.fmt.comptimePrint("ColorTable type {} is not a Color3/Color4", .{T}));
    }

    return struct {
        const Self = @This();

        map: std.AutoHashMap(T, u32),
        _index: u32 = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .map = .init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn add(self: *Self, color: T) !u32 {
            if (self.map.get(color)) |index| {
                return index;
            }

            const index = self._index;
            try self.map.put(color, index);
            self._index += 1;

            return index;
        }

        pub fn get(self: Self, color: T) ?u32 {
            return self.map.get(color);
        }

        pub fn count(self: Self) usize {
            return self.map.count();
        }

        pub fn contains(self: Self, color: T) bool {
            return self.map.contains(color);
        }

        pub fn toBytes(self: Self) ![]u8 {
            const color_size = if (T == Color3) 3 else 4;
            var result = try self.map.allocator.alloc(u8, self.count() * color_size);

            var it = self.map.iterator();
            while (it.next()) |entry| {
                const index = @as(usize, @intCast(entry.value_ptr.*)) * color_size;
                result[index + 0] = entry.key_ptr.r;
                result[index + 1] = entry.key_ptr.g;
                result[index + 2] = entry.key_ptr.b;

                if (T == Color4) {
                    result[index + 3] = entry.key_ptr.a;
                }
            }

            return result;
        }

        pub fn format(self: Self, writer: *std.Io.Writer) !void {
            try writer.print("count: {}\n", .{self.count()});

            var it = self.map.iterator();
            while (it.next()) |item| {
                try writer.print("   ({f}) => {}\n", .{ item.key_ptr.*, item.value_ptr.* });
            }
        }

        fn getAllocator(self: Self) std.mem.Allocator {
            return self.map.allocator;
        }
    };
}
