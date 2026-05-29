const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
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
pub const OnMenuItemSelected = *const fn (usize, *Container) void;

/// Represents a popup window that can be displayed anywhere in the app.
/// TODO: Split menu popups into separate object to allow for multiple menu popup windows.
const Self = @This();

position: clay.Vector2 = .zero,
state: State = .closed,
on_draw: ?OnDraw = null,
layout: clay.LayoutConfig = .{},
allocator: std.mem.Allocator,
menu_items: ?[]const []const u8 = null,
on_menu_item_selected: ?OnMenuItemSelected = null,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.clearMenu();
}

pub fn isOpen(self: Self) bool {
    return self.state != .closed;
}

pub fn openMenu(
    self: *Self,
    position: Position,
    items: []const []const u8,
    on_menu_item_selected: OnMenuItemSelected,
) void {
    self.clearMenu();
    self.menu_items = self.allocator.dupe([]const u8, items) catch |err| {
        std.debug.panic("Failed to duplicate menu items: {}", .{err});
    };
    self.on_menu_item_selected = on_menu_item_selected;
    self.openFit(position, onDrawMenu);
}

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
    self.clearMenu();
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
                self.close();
            }
        },
        else => {},
    }
}

fn clearMenu(self: *Self) void {
    if (self.menu_items) |menu_items| {
        self.allocator.free(menu_items);
    }
    self.menu_items = null;
}

fn onDrawMenu(container: *Container) void {
    const menu_items = container.popup.menu_items orelse {
        container.popup.close();
        return;
    };
    const callback = container.popup.on_menu_item_selected orelse {
        container.popup.close();
        return;
    };

    const result = controls.list.stringItems(container.state, menu_items, 18);
    if (result) |index| {
        callback(index, container);
        container.popup.close();
    }
}
