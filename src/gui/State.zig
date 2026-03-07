const clay = @import("clay");
const raylib = @import("raylib");
const std = @import("std");

/// Manages what control is focused along with control specific data.
const Self = @This();

/// Keep track of the top 8 elements.
focused: [8]clay.ElementId = @splat(.{}),

pub fn isFocused(self: Self, element: clay.ElementId) bool {
    for (self.focused) |focused| {
        if (element.eql(focused)) {
            return true;
        }
    }

    return false;
}

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

    var i = @min(self.focused.len, hovered.len()) -| 1;
    while (i >= 0) : (i -= 1) {
        self.focused[i] = hovered.get(i);
        if (i == 0) break;
    }
}
