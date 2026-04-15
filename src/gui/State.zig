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

/// An allocator for persistent memory.
allocator: std.mem.Allocator,

/// An arena allocator that can be used by all controls and widgets to allocate strings and other
/// needed objects for a single frame.
arena: std.heap.ArenaAllocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .theme = try .init(allocator),
        .allocator = allocator,
        .arena = .init(allocator),
    };
}

pub fn deinit(self: Self) void {
    self.theme.deinit(self.allocator);
    self.arena.deinit();
}

pub fn isFocused(self: Self, element: clay.ElementId) bool {
    for (self.focused) |focused| {
        if (element.eql(focused)) {
            return true;
        }
    }

    return false;
}

pub fn isFocusedTop(self: Self, element: clay.ElementId) bool {
    return self.focused[0].eql(element);
}

pub fn getAllocator(self: Self) std.mem.Allocator {
    return self.allocator;
}

pub fn getArenaAllocator(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}

pub fn update(self: *Self) void {
    self.updateFocused();
    _ = self.arena.reset(.retain_capacity);
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
