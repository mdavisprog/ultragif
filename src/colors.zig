const Image = @import("Image.zig");
const std = @import("std");

pub const Channel = enum {
    r,
    g,
    b,
    a,
};

/// 4-channel color.
pub const Color = struct {
    pub const lightgray: Color = .init(200, 200, 200, 255);
    pub const gray: Color = .init(130, 130, 130, 255);
    pub const darkgray: Color = .init(80, 80, 80, 255);
    pub const yellow: Color = .init(253, 249, 0, 255);
    pub const gold: Color = .init(255, 203, 0, 255);
    pub const orange: Color = .init(255, 161, 0, 255);
    pub const pink: Color = .init(255, 109, 194, 255);
    pub const red: Color = .init(230, 41, 55, 255);
    pub const maroon: Color = .init(190, 33, 55, 255);
    pub const green: Color = .init(0, 228, 48, 255);
    pub const lime: Color = .init(0, 158, 47, 255);
    pub const darkgreen: Color = .init(0, 117, 44, 255);
    pub const skyblue: Color = .init(102, 191, 255, 255);
    pub const blue: Color = .init(0, 121, 241, 255);
    pub const darkblue: Color = .init(0, 82, 172, 255);
    pub const purple: Color = .init(200, 122, 255, 255);
    pub const violet: Color = .init(135, 60, 190, 255);
    pub const darkpurple: Color = .init(112, 31, 126, 255);
    pub const beige: Color = .init(211, 176, 131, 255);
    pub const brown: Color = .init(127, 106, 79, 255);
    pub const darkbrown: Color = .init(76, 63, 47, 255);
    pub const white: Color = .init(255, 255, 255, 255);
    pub const black: Color = .init(0, 0, 0, 255);
    pub const blank: Color = .init(0, 0, 0, 0);
    pub const magenta: Color = .init(255, 0, 255, 255);
    pub const raywhite: Color = .init(245, 245, 245, 255);

    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn init3(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn fromArray(data: [4]u8) Color {
        return .{ .r = data[0], .g = data[1], .b = data[2], .a = data[3] };
    }

    pub fn eql(self: Color, value: Color) bool {
        return self.r == value.r and
            self.g == value.g and
            self.b == value.b and
            self.a == value.a;
    }

    pub fn dominantChannel(self: Color) Channel {
        if (self.r > self.g and self.r > self.b and self.r > self.a) {
            return .r;
        }

        if (self.g > self.r and self.g > self.b and self.g > self.a) {
            return .g;
        }

        if (self.b > self.r and self.b > self.g and self.b > self.a) {
            return .b;
        }

        if (self.a > self.r and self.a > self.g and self.a > self.b) {
            return .a;
        }

        return .r;
    }

    pub fn format(self: Color, writer: *std.Io.Writer) !void {
        try writer.print("{} {} {} {}", .{ self.r, self.g, self.b, self.a });
    }
};

/// Struct to provide functions for managing a list of colors.
pub const ColorList = struct {
    data: []Color,

    fn average(self: ColorList) Color {
        var r: usize = 0;
        var g: usize = 0;
        var b: usize = 0;
        var a: usize = 0;

        for (self.data) |color| {
            r += @as(usize, @intCast(color.r));
            g += @as(usize, @intCast(color.g));
            b += @as(usize, @intCast(color.b));
            a += @as(usize, @intCast(color.a));
        }

        const len = self.data.len;
        return .init(
            @intCast(r / len),
            @intCast(g / len),
            @intCast(b / len),
            @intCast(a / len),
        );
    }

    fn getChannelVariations(self: ColorList) Color {
        var result: Color = .blank;

        var min: Color = .blank;
        var max: Color = .blank;

        for (self.data) |color| {
            min.r = @min(min.r, color.r);
            min.g = @min(min.g, color.g);
            min.b = @min(min.b, color.b);
            min.a = @max(min.a, color.a);

            max.r = @max(max.r, color.r);
            max.g = @max(max.g, color.g);
            max.b = @max(max.b, color.b);
            max.a = @max(max.a, color.a);
        }

        result.r = max.r - min.r;
        result.g = max.g - min.g;
        result.b = max.b - min.b;
        result.a = max.a - min.a;

        return result;
    }

    fn sortAndSplit(self: ColorList) [2]ColorList {
        // If the bucket only contains a single item, then return this bucket as a slice and
        // an empty bucket.
        if (self.data.len < 2) {
            return .{
                .{ .data = self.data[0..] },
                .{ .data = &.{} },
            };
        }

        const variations = self.getChannelVariations();
        const sort_channel = variations.dominantChannel();
        std.mem.sort(Color, self.data, sort_channel, sort);

        const half = self.data.len / 2;
        return .{
            .{ .data = self.data[0..half] },
            .{ .data = self.data[half..] },
        };
    }

    fn sort(channel: Channel, lhs: Color, rhs: Color) bool {
        return switch (channel) {
            .r => rhs.r > lhs.r,
            .g => rhs.g > lhs.g,
            .b => rhs.b > lhs.b,
            .a => rhs.a > lhs.a,
        };
    }
};

/// Manages a map of a color and their entry in the table.
pub const ColorTable = struct {
    pub const Options = struct {
        ignore_transparent: bool = false,
    };

    map: std.AutoHashMap(Color, u32),
    options: Options = .{},
    _index: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) ColorTable {
        return .{ .map = .init(allocator) };
    }

    pub fn initOptions(allocator: std.mem.Allocator, options: Options) ColorTable {
        return .{ .map = .init(allocator), .options = options };
    }

    pub fn initImage(allocator: std.mem.Allocator, image: Image, options: Options) !ColorTable {
        var result: ColorTable = .initOptions(allocator, options);
        errdefer result.deinit();

        switch (image.format) {
            .RGBA => {
                var index: usize = 0;
                while (index < image.length()) : (index += 4) {
                    const color: Color = .init(
                        image.data[index + 0],
                        image.data[index + 1],
                        image.data[index + 2],
                        image.data[index + 3],
                    );

                    _ = try result.add(color);
                }
            },
            else => {
                std.debug.panic("Unhandled image format: {s}", .{@tagName(image.format)});
            },
        }

        return result;
    }

    pub fn deinit(self: *ColorTable) void {
        self.map.deinit();
    }

    pub fn clone(self: ColorTable) !ColorTable {
        return .{
            .map = try self.map.clone(),
            .options = self.options,
            ._index = self._index,
        };
    }

    pub fn add(self: *ColorTable, color: Color) !?u32 {
        if (color.a == 0 and self.options.ignore_transparent) {
            return null;
        }

        if (self.map.get(color)) |index| {
            return index;
        }

        const index = self._index;
        try self.map.put(color, index);
        self._index += 1;

        return index;
    }

    pub fn remove(self: *ColorTable, color: Color) bool {
        return self.map.remove(color);
    }

    pub fn get(self: ColorTable, color: Color) ?u32 {
        return self.map.get(color);
    }

    pub fn count(self: ColorTable) usize {
        return self.map.count();
    }

    pub fn contains(self: ColorTable, color: Color) bool {
        return self.map.contains(color);
    }

    pub fn toBytes(self: ColorTable, channels: u2) ![]u8 {
        if (channels == 0) {
            return error.InvalidChannels;
        }

        const _channels: usize = @intCast(channels);
        var result = try self.map.allocator.alloc(u8, self.count() * _channels);

        var it = self.map.iterator();
        while (it.next()) |entry| {
            const index = @as(usize, @intCast(entry.value_ptr.*)) * _channels;
            result[index + 0] = entry.key_ptr.r;

            if (channels >= 2) result[index + 1] = entry.key_ptr.g;
            if (channels >= 3) result[index + 2] = entry.key_ptr.b;
            if (channels >= 4) result[index + 3] = entry.key_ptr.a;
        }

        return result;
    }

    pub fn colorArray(self: ColorTable) ![]Color {
        const allocator = self.getAllocator();
        var result = try allocator.alloc(Color, self.count());

        var it = self.map.iterator();
        while (it.next()) |entry| {
            const index = entry.value_ptr.*;
            result[index] = entry.key_ptr.*;
        }

        return result;
    }

    pub fn quantize(self: ColorTable, size: usize) !QuantizedColorMap {
        const allocator = self.getAllocator();

        // If the table already meets the size requirements, then just clone the data and
        // set the quantized color map to just be the colors in the current table.
        if (self.count() < size) {
            var result: QuantizedColorMap = .init(allocator);
            result.table = try self.clone();

            var colors = self.map.keyIterator();
            while (colors.next()) |color| {
                try result.map.put(allocator, color.*, color.*);
            }

            return result;
        }

        // Keep track of all buckets until desired size is reached.
        var buckets: std.ArrayListUnmanaged(ColorList) = .empty;
        defer buckets.deinit(allocator);

        // Start with the full color list from this table.
        const bucket = try self.colorArray();
        defer allocator.free(bucket);
        try buckets.append(allocator, .{ .data = bucket });

        while (buckets.items.len < size) {
            // Grab the first added bucket in the list and split.
            const popped = buckets.pop() orelse break;
            const split = popped.sortAndSplit();

            for (split) |item| {
                // Ignore empty buckets. Can occur if a bucket only had a single color
                if (item.data.len > 0) {
                    // Push new items to front of the list so the next item to split can
                    // be popped off of the list.
                    try buckets.insert(allocator, 0, item);
                }
            }
        }

        var result: QuantizedColorMap = .init(allocator);
        errdefer result.deinit();

        result.table.options = self.options;

        // Average all colors in the bucket and add to result color table.
        for (buckets.items) |item| {
            const color = item.average();
            _ = try result.table.add(color);

            for (item.data) |old_color| {
                try result.map.put(allocator, old_color, color);
            }
        }

        return result;
    }

    pub fn reindex(self: *ColorTable) void {
        var index: u32 = 0;
        var it = self.map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = index;
            index += 1;
        }
        self._index = index;
    }

    pub fn format(self: ColorTable, writer: *std.Io.Writer) !void {
        try writer.print("count: {}\n", .{self.count()});

        var it = self.map.iterator();
        while (it.next()) |item| {
            try writer.print("   ({f}) => {}\n", .{ item.key_ptr.*, item.value_ptr.* });
        }
    }

    fn getAllocator(self: ColorTable) std.mem.Allocator {
        return self.map.allocator;
    }
};

/// Maps a palette from a pre-quantized color table to new colors.
pub const QuantizedColorMap = struct {
    map: std.AutoHashMapUnmanaged(Color, Color) = .empty,
    table: ColorTable,

    pub fn deinit(self: *QuantizedColorMap) void {
        self.map.deinit(self.table.getAllocator());
        self.table.deinit();
    }

    fn init(allocator: std.mem.Allocator) QuantizedColorMap {
        return .{ .table = .init(allocator) };
    }
};

pub const Indexer = struct {
    color_table: *ColorTable,
    quantized_colors: *std.AutoHashMapUnmanaged(Color, Color),
    transparent_index: ?u32 = null,

    pub fn init(color_table: ColorTable) Indexer {
        return .{ .color_table = color_table };
    }

    pub fn initQuantized(quantized: *QuantizedColorMap) Indexer {
        return .{ .color_table = &quantized.table, .quantized_colors = &quantized.map };
    }

    pub fn indexImage(self: Indexer, image: Image) ![]u8 {
        const len = @as(usize, @intCast(image.width)) * @as(usize, @intCast(image.height));
        var result = try self.color_table.getAllocator().alloc(u8, len);

        for (0..len) |index| {
            // TODO: Handle different formats (grayscale, rgba, rgb, etc.)
            const src_index = index * image.format.bytes();
            const color: Color = .init(
                image.data[src_index + 0],
                image.data[src_index + 1],
                image.data[src_index + 2],
                image.data[src_index + 3],
            );

            if (color.a == 0 and self.color_table.options.ignore_transparent) {
                result[index] = if (self.transparent_index) |i| @as(u8, @intCast(i)) else 0;
            } else {
                const new_color = self.quantized_colors.get(color) orelse color;
                const color_index = self.color_table.get(new_color) orelse 0;
                result[index] = @intCast(color_index);
            }
        }

        return result;
    }

    pub fn setTransparentColor(self: *Indexer, color: Color) !void {
        if (self.color_table.contains(color)) {
            return error.ColorAlreadyExists;
        }

        self.transparent_index = try self.color_table.add(color);
    }
};

test "quantize" {
    const allocator = std.testing.allocator;

    var color_table: ColorTable = .init(allocator);
    defer color_table.deinit();

    _ = try color_table.add(.init3(55, 109, 214));
    _ = try color_table.add(.init3(128, 86, 135));
    _ = try color_table.add(.init3(69, 56, 100));
    _ = try color_table.add(.init3(125, 131, 224));
    _ = try color_table.add(.init3(187, 153, 223));
    _ = try color_table.add(.init3(221, 126, 151));
    _ = try color_table.add(.init3(246, 185, 205));
    _ = try color_table.add(.init3(21, 21, 39));

    var quantized = try color_table.quantize(4);
    defer quantized.deinit();

    try std.testing.expectEqual(4, quantized.table.count());
    try std.testing.expect(quantized.table.contains(.init3(157, 119, 179)));
    try std.testing.expect(quantized.table.contains(.init3(45, 38, 69)));
    try std.testing.expect(quantized.table.contains(.init3(233, 155, 178)));
    try std.testing.expect(quantized.table.contains(.init3(90, 120, 219)));
}
