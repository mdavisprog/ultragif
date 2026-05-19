const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub const Options = struct {
    sizing: clay.Sizing = .{
        .width = .percent(1.0),
    },
};

pub const ItemOptions = struct {
    selected: bool = false,
    sizing: clay.Sizing = .{
        .width = .percent(1.0),
    },
};

pub fn stringItems(state: State, items: []const []const u8, font_size: u16) ?usize {
    var max_width: f32 = 0.0;
    for (items) |item| {
        const size = state.theme.measureText(item, @floatFromInt(font_size), 0);
        max_width = @max(max_width, size.x);
    }

    var selected_index: ?usize = null;
    begin(.{
        .sizing = .{ .width = .fixed(max_width) },
    });
    {
        for (items, 0..) |item, i| {
            const selected = beginItem(state, .{});
            controls.text.label(state, item, .{ .font_size = font_size });
            endItem();

            if (selected) selected_index = i;
        }
    }
    end();

    return selected_index;
}

pub fn begin(options: Options) void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = options.sizing,
            .layout_direction = .top_to_bottom,
        },
    });
}

pub fn end() void {
    clay.closeElement();
}

pub fn beginItem(state: State, options: ItemOptions) bool {
    clay.openElement();

    var result = false;
    var background_color: clay.Color = .blank;

    if (clay.hovered()) {
        if (raylib.isMouseButtonPressed(.left)) {
            result = true;
        }

        background_color = state.theme.colors.button_hovered;
    }

    if (options.selected) {
        background_color = state.theme.colors.button_background;
    }

    clay.configureOpenElement(.{
        .layout = .{
            .sizing = options.sizing,
            .padding = .axes(0, 4),
        },
        .background_color = background_color,
    });

    return result;
}

pub fn endItem() void {
    clay.closeElement();
}
