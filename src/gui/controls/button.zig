const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub fn label(state: State, id: clay.ElementId, text: []const u8) bool {
    const color: clay.Color = blk: {
        if (state.isFocused(id) and raylib.isMouseButtonDown(.left)) {
            break :blk .initu8(64, 64, 64, 255);
        }

        if (clay.pointerOver(id)) {
            break :blk .initu8(72, 72, 72, 255);
        }

        break :blk .initu8(48, 48, 48, 255);
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
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
            },
        },
        .background_color = color,
    });
    {
        controls.text.label(text, .{});
    }
    clay.closeElement();

    return result;
}
