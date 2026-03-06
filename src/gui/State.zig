const clay = @import("clay");
const raylib = @import("raylib");

/// Manages what control is focused along with control specific data.
const Self = @This();

focused: ?clay.ElementId = null,

pub fn update(self: *Self) void {
    self.updateFocused();
}

fn updateFocused(self: *Self) void {
    const hovered = clay.getPointerOverIds();
    if (hovered.len() == 0) {
        return;
    }

    if (!raylib.isMouseButtonPressed(.left)) {
        return;
    }

    self.focused = hovered.get(0);
}
