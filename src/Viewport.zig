const raylib = @import("raylib");

/// Events that can occur to a viewport.
pub const EventType = enum {
    /// Nothing happened.
    none,

    /// The viewport was resized. Can be through manual resizing or through maximize button.
    size_changed,
};

/// The tagged union holding data for each event type.
pub const Event = union(EventType) {
    none: void,
    size_changed: struct { previous: raylib.Vector2, current: raylib.Vector2 },
};

/// Manages a window's framebuffer state.
const Self = @This();

size: raylib.Vector2 = .zero,
maximized: bool = false,

pub fn init() Self {
    return .{
        .size = getSize(),
        .maximized = raylib.isWindowMaximized(),
    };
}

pub fn nextEvent(self: *Self) Event {
    const previous = self.size;
    const size = getSize();
    const maximized = raylib.isWindowMaximized();

    if (self.maximized != maximized) {
        self.maximized = maximized;
        self.size = size;
        return .{
            .size_changed = .{
                .previous = previous,
                .current = size,
            },
        };
    }

    if (!self.size.eql(size)) {
        self.size = size;
        return .{
            .size_changed = .{
                .previous = previous,
                .current = size,
            },
        };
    }

    return .none;
}

fn getSize() raylib.Vector2 {
    return .init(
        @floatFromInt(raylib.getRenderWidth()),
        @floatFromInt(raylib.getRenderHeight()),
    );
}
