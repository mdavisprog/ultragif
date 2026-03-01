const std = @import("std");

/// Supported sorting types.
pub const Sort = enum {
    area,
    width,
    height,
};

/// Uses integer coordinates. Provides an Id field for mapping back to custom data.
pub const Rectangle = struct {
    pub const zero: Rectangle = .init(0.0, 0.0, 0.0, 0.0);

    x: u32,
    y: u32,
    width: u32,
    height: u32,
    id: u32 = 0,

    pub fn init(x: u32, y: u32, width: u32, height: u32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn initId(x: u32, y: u32, width: u32, height: u32, id: u32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height, .id = id };
    }

    pub fn area(self: Rectangle) u32 {
        return self.width * self.height;
    }
};

/// A single packed item.
pub const Item = struct {
    rect: Rectangle = .zero,
    rotated: bool = false,

    pub fn init(x: u32, y: u32, width: u32, height: u32, rotated: bool) Item {
        return .{
            .rect = .init(x, y, width, height),
            .rotated = rotated,
        };
    }
};

/// Alias
const RectList = std.ArrayListUnmanaged(Item);

/// Growable atlas. Uses the MaxRects algorithm to efficiently pack each rect.
const Self = @This();

packed_list: RectList = .empty,
width: u32 = 0,
height: u32 = 0,
_initial_width: u32,
_initial_height: u32,
_padding: u32,
_free_list: RectList,

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, padding: u32) !Self {
    var free_list: RectList = .empty;
    try free_list.append(allocator, .init(0, 0, width, height, false));

    return .{
        .width = width,
        .height = height,
        ._initial_width = width,
        ._initial_height = height,
        ._padding = padding,
        ._free_list = free_list,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.packed_list.deinit(allocator);
    self._free_list.deinit(allocator);
}

pub fn pack(self: *Self, allocator: std.mem.Allocator, rects: []Rectangle) !void {
    sort(rects, .area);

    var index: usize = 0;
    while (index < rects.len) : (index += 1) {
        const rect = rects[index];

        const result = self.findBestRect(rect) orelse {
            // Increase size of atlas and reset state.
            index = 0;
            self.packed_list.clearRetainingCapacity();

            self.width += self._initial_width / 2;
            self.height += self._initial_height / 2;

            self._free_list.clearRetainingCapacity();
            try self._free_list.append(allocator, .init(0, 0, self.width, self.height, false));
            continue;
        };

        var packed_rect: Item = .init(
            result.best.rect.x,
            result.best.rect.y,
            if (result.best.rotated) rect.height else rect.width,
            if (result.best.rotated) rect.width else rect.height,
            result.best.rotated,
        );
        packed_rect.rect.id = rect.id;
        try self.packed_list.append(allocator, packed_rect);

        _ = self._free_list.swapRemove(result.index);
        const pair = split(result.best, packed_rect, self._padding);
        for (pair) |item| {
            const _item = item orelse continue;
            try self._free_list.append(allocator, _item);
        }
    }
}

const FindResult = struct {
    best: Item,
    index: usize,
};

fn findBestRect(self: Self, rect: Rectangle) ?FindResult {
    var result: ?FindResult = null;

    var min_remaining_area: u32 = std.math.maxInt(u32);
    const rect_width = @as(u32, @intCast(rect.width)) + self._padding;
    const rect_height = @as(u32, @intCast(rect.height)) + self._padding;
    const rect_area = rect_width + rect_height;

    const rotated_width = rect_height;
    const rotated_height = rect_width;

    for (self._free_list.items, 0..) |item, i| {
        if (rect_width <= item.rect.width and rect_height <= item.rect.height) {
            const remaining_area = item.rect.area() - rect_area;
            if (remaining_area < min_remaining_area) {
                min_remaining_area = remaining_area;
                result = .{
                    .best = .{
                        .rect = item.rect,
                        .rotated = false,
                    },
                    .index = i,
                };
            }
        }

        if (rotated_width <= item.rect.width and rotated_height <= item.rect.height) {
            const remaining_area = item.rect.area() - rect_area;
            if (remaining_area < min_remaining_area) {
                min_remaining_area = remaining_area;
                result = .{
                    .best = .{
                        .rect = item.rect,
                        .rotated = true,
                    },
                    .index = i,
                };
            }
        }
    }

    return result;
}

fn split(original: Item, placed: Item, padding: u32) [2]?Item {
    var result: [2]?Item = @splat(null);

    const item_width = if (placed.rotated)
        placed.rect.height + padding
    else
        placed.rect.width + padding;

    const item_height = if (placed.rotated)
        placed.rect.width + padding
    else
        placed.rect.height + padding;

    if (original.rect.width > item_width) {
        result[0] = .init(
            original.rect.x + item_width,
            original.rect.y,
            original.rect.width - item_width,
            original.rect.height,
            false,
        );
    }

    if (original.rect.height > item_height) {
        result[1] = .init(
            original.rect.x,
            original.rect.y + item_height,
            original.rect.width,
            original.rect.height - item_height,
            false,
        );
    }

    return result;
}

fn sort(rects: []Rectangle, sort_type: Sort) void {
    switch (sort_type) {
        .area => std.mem.sort(Rectangle, rects, {}, sortArea),
        .width => std.mem.sort(Rectangle, rects, {}, sortWidth),
        .height => std.mem.sort(Rectangle, rects, {}, sortHeight),
    }
}

fn sortArea(_: void, a: Rectangle, b: Rectangle) bool {
    const a_area = a.width * a.height;
    const b_area = b.width * b.height;
    return b_area < a_area;
}

fn sortWidth(_: void, a: Rectangle, b: Rectangle) bool {
    return b.width < a.width;
}

fn sortHeight(_: void, a: Rectangle, b: Rectangle) bool {
    return b.height < a.height;
}

test "Rectangle.area" {
    const rectangle: Rectangle = .init(0, 0, 20, 20);
    try std.testing.expectEqual(400, rectangle.area());
}

test "Sort.area" {
    var rects = [4]Rectangle{
        .init(0, 0, 5, 5),
        .init(0, 0, 10, 5),
        .init(0, 0, 6, 7),
        .init(0, 0, 2, 4),
    };

    sort(&rects, .area);

    try std.testing.expectEqual(50, rects[0].area());
    try std.testing.expectEqual(42, rects[1].area());
    try std.testing.expectEqual(25, rects[2].area());
    try std.testing.expectEqual(8, rects[3].area());
}

test "Sort.width" {
    var rects = [4]Rectangle{
        .init(0, 0, 5, 5),
        .init(0, 0, 12, 5),
        .init(0, 0, 2, 7),
        .init(0, 0, 6, 4),
    };

    sort(&rects, .width);

    try std.testing.expectEqual(12, rects[0].width);
    try std.testing.expectEqual(6, rects[1].width);
    try std.testing.expectEqual(5, rects[2].width);
    try std.testing.expectEqual(2, rects[3].width);
}

test "Sort.height" {
    var rects = [4]Rectangle{
        .init(0, 0, 5, 5),
        .init(0, 0, 12, 20),
        .init(0, 0, 2, 7),
        .init(0, 0, 6, 12),
    };

    sort(&rects, .height);

    try std.testing.expectEqual(20, rects[0].height);
    try std.testing.expectEqual(12, rects[1].height);
    try std.testing.expectEqual(7, rects[2].height);
    try std.testing.expectEqual(5, rects[3].height);
}
