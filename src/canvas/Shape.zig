const raylib = @import("raylib");

/// Represents a simple primitive that can be rendered within the canvas.
const Self = @This();

pub const Type = enum {
    rectangle,
};

pub const Data = union(Type) {
    rectangle: struct { size: raylib.Vector2 },
};

data: Data,
color: raylib.Color = .white,

pub fn init(data: Data) Self {
    return .{ .data = data };
}

pub fn update(self: *Self, delta_time: f32) void {
    _ = self;
    _ = delta_time;
}

pub fn draw(self: *Self, position: raylib.Vector2) void {
    switch (self.data) {
        .rectangle => |rectangle| {
            raylib.drawRectangleV(position, rectangle.size, self.color);
        },
    }
}

pub fn getSize(self: *const Self) raylib.Vector2 {
    return switch (self.data) {
        .rectangle => |rectangle| rectangle.size,
    };
}
