const clay = @import("clay");
const controls = @import("controls/root.zig");
const raylib = @import("raylib");
const std = @import("std");
const Theme = @import("Theme.zig");

/// Simple struct to hold information about the blinking cursor.
pub const BlinkingCursor = struct {
    const max_time: f32 = 0.5;

    time: f32 = 0.0,
    on: bool = true,

    pub fn reset(self: *BlinkingCursor) void {
        self.time = 0.0;
        self.on = true;
    }
};

/// Alias for mapping between an element and its data.
pub const ControlData = std.AutoHashMap(clay.ElementId, controls.Data);

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

/// Global blinking text input cursor
blinking_cursor: BlinkingCursor = .{},

/// Mapped data between an element and its data.
control_data: ControlData,

/// The current scroll bar that is being dragged.
scroll_bar: clay.ElementId = .{},

/// Keep track of the focused items last frame to determine when a control was focused on the current frame.
_last_frame_focused: [8]clay.ElementId = @splat(.{}),

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .theme = try .init(allocator),
        .allocator = allocator,
        .arena = .init(allocator),
        .control_data = .init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    var it = self.control_data.valueIterator();
    while (it.next()) |data| {
        data.deinit(self.allocator);
    }
    self.control_data.deinit();

    self.theme.deinit(self.allocator);
    self.arena.deinit();
}

pub fn isFocused(self: Self, element: clay.ElementId) bool {
    return contains(&self.focused, element);
}

pub fn isFocusedTop(self: Self, element: clay.ElementId) bool {
    return self.focused[0].eql(element);
}

pub fn isFocusedThisFrame(self: Self, element: clay.ElementId) bool {
    return contains(&self.focused, element) and !contains(&self._last_frame_focused, element);
}

pub fn clearFocused(self: *Self) void {
    self.focused = @splat(.{});
}

pub fn getAllocator(self: Self) std.mem.Allocator {
    return self.allocator;
}

pub fn getArenaAllocator(self: *Self) std.mem.Allocator {
    return self.arena.allocator();
}

pub fn getData(self: Self, id: clay.ElementId) ?*controls.Data {
    return self.control_data.getPtr(id);
}

pub fn addData(self: *Self, id: clay.ElementId, data: controls.Data) *controls.Data {
    if (self.control_data.contains(id)) {
        std.debug.panic("Given id already exists!", .{});
    }

    self.control_data.put(id, data) catch |err| {
        std.debug.panic("Failed to add data of type '{s}': {}", .{ @tagName(data), err });
    };

    return self.control_data.getPtr(id).?;
}

pub fn formatStringTemp(self: *Self, comptime format: []const u8, args: anytype) []const u8 {
    const result = std.fmt.allocPrint(
        self.getArenaAllocator(),
        format,
        args,
    ) catch |err| {
        std.debug.panic("Failed to allocate temporary string: {}", .{err});
    };

    return result;
}

pub fn update(self: *Self, delta_time: f32) void {
    self.blinking_cursor.time += delta_time;
    if (self.blinking_cursor.time >= BlinkingCursor.max_time) {
        self.blinking_cursor.time = 0.0;
        self.blinking_cursor.on = !self.blinking_cursor.on;
    }

    self.updateFocused();
    _ = self.arena.reset(.retain_capacity);
}

fn updateFocused(self: *Self) void {
    @memcpy(&self._last_frame_focused, &self.focused);

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

fn contains(items: []const clay.ElementId, id: clay.ElementId) bool {
    for (items) |item| {
        if (item.eql(id)) {
            return true;
        }
    }

    return false;
}
