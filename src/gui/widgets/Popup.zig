const clay = @import("clay");
const Container = @import("../Container.zig");
const raylib = @import("raylib");
const std = @import("std");

pub const State = enum {
    closed,
    opening,
    open,
};

pub const Options = struct {
    layout: clay.LayoutConfig = .{
        .sizing = .fixed(200.0, 200.0),
    },
};

pub const Position = union(enum) {
    mouse: void,
    at: clay.Vector2,
};

pub const OnDraw = *const fn (*Container) void;

/// Represents a popup window that can be displayed anywhere in the app.
const Self = @This();

position: clay.Vector2 = .zero,
state: State = .closed,
on_draw: ?OnDraw = null,
layout: clay.LayoutConfig = .{},

pub fn openFit(self: *Self, position: Position, on_draw: OnDraw) void {
    self.open(position, on_draw, .{
        .layout = .{
            .sizing = .fit(0.0, 0.0),
            .padding = .axes(12, 12),
        },
    });
}

pub fn open(self: *Self, position: Position, on_draw: OnDraw, options: Options) void {
    const mouse_pos = raylib.getMousePosition();
    const pos: clay.Vector2 = switch (position) {
        .mouse => .init(mouse_pos.x, mouse_pos.y),
        .at => |at| at,
    };

    self.state = .opening;
    self.position = pos;
    self.on_draw = on_draw;
    self.layout = options.layout;
}

pub fn close(self: *Self) void {
    self.state = .closed;
}

pub fn draw(self: *Self, container: *Container) void {
    if (self.state == .closed) return;
    const on_draw = self.on_draw orelse return;

    const id: clay.ElementId = .fromLabel("Popup");

    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .background_color = container.state.theme.colors.background,
        .layout = self.layout,
        .floating = .{
            .attach_to = .root,
            .offset = self.position,
        },
        .border = .{
            .color = .black,
            .width = .all(1),
        },
    });
    {
        on_draw(container);
    }
    clay.closeElement();

    switch (self.state) {
        .opening => {
            self.state = .open;
        },
        .open => {
            const mouse_pos = raylib.getMousePosition();
            const element = clay.getElementData(id);
            const hovered = element.bounding_box.contains(.init(mouse_pos.x, mouse_pos.y));
            if (!hovered and raylib.isMouseButtonPressed(.left)) {
                std.log.debug("Closing", .{});
                self.close();
            }
        },
        else => {},
    }
}
