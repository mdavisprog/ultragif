const clay = @import("clay");
const Container = @import("../Container.zig");
const std = @import("std");

pub const State = enum {
    closed,
    open,
};

pub const OnDraw = *const fn (*Container) void;

/// Represents a popup window that can be displayed anywhere in the app.
const Self = @This();

position: clay.Vector2 = .zero,
state: State = .closed,
on_draw: ?OnDraw = null,

pub fn open(self: *Self, position: clay.Vector2, on_draw: OnDraw) void {
    self.state = .open;
    self.position = position;
    self.on_draw = on_draw;
}

pub fn close(self: *Self) void {
    self.state = .closed;
}

pub fn draw(self: *Self, container: *Container) void {
    if (self.state == .closed) return;
    if (self.on_draw == null) return;

    clay.openElement();
    clay.configureOpenElement(.{
        .background_color = container.state.theme.colors.background,
        .layout = .{
            .sizing = .fixed(200.0, 200.0),
        },
        .floating = .{
            .attach_to = .root,
            .offset = self.position,
        },
        .border = .{
            .color = .black,
            .width = .all(1),
        },
    });
    clay.closeElement();
}
