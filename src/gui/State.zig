const clay = @import("clay");
const raylib = @import("raylib");
const std = @import("std");
const Theme = @import("Theme.zig");

/// Manages what control is focused along with control specific data.
const Self = @This();

/// Keep track of the top 8 elements.
focused: [8]clay.ElementId = @splat(.{}),

/// The current theme to use for the UI
theme: Theme,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .theme = try .init(allocator),
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    self.theme.deinit(allocator);
}

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

    // Clear the current focus stack.
    self.focused = @splat(.{});

    var i = @min(self.focused.len, hovered.len()) -| 1;
    while (i >= 0) : (i -= 1) {
        self.focused[i] = hovered.get(i);
        if (i == 0) break;
    }
}
