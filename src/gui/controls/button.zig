const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub const Config = struct {
    layout: clay.LayoutConfig = .{
        .sizing = .{
            .width = .percent(1.0),
        },
        .child_alignment = .init(.center, .center),
        .padding = .axes(4, 2),
    },
    text_config: controls.text.Config = .{
        .text_alignment = .center,
    },
};

pub fn label(state: State, id: clay.ElementId, text: []const u8, config: Config) bool {
    const color: clay.Color = blk: {
        if (state.isFocused(id) and raylib.isMouseButtonDown(.left)) {
            break :blk state.theme.colors.button_active;
        }

        if (clay.pointerOver(id)) {
            break :blk state.theme.colors.button_hovered;
        }

        break :blk state.theme.colors.button_background;
    };

    const result: bool = blk: {
        if (!state.isFocused(id)) break :blk false;
        if (!raylib.isMouseButtonReleased(.left)) break :blk false;
        if (!clay.pointerOver(id)) break :blk false;
        break :blk true;
    };

    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = config.layout,
        .background_color = color,
    });
    {
        controls.text.label(state, text, .{
            .text_alignment = .center,
        });
    }
    clay.closeElement();

    return result;
}
