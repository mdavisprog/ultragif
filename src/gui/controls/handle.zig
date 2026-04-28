const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");
const Theme = @import("../Theme.zig");

pub const Result = struct {
    pub const Interaction = enum {
        none,
        hovering,
        dragging,
    };

    mouse_delta: clay.Vector2 = .zero,
    interaction: Interaction = .none,
};

pub const Options = struct {
    sizing: clay.Sizing,
    offset: clay.Vector2 = .zero,
    background_color: ?clay.Color = null,
    attach_point: clay.FloatingAttachPoints.Type = .left_top,
};

/// Handles are invisible elements that can be interacted with. This is useful for behaviors such
/// as sizers for a panel.
pub fn draggable(
    state: State,
    id: clay.ElementId,
    options: Options,
) Result {
    const background_color: clay.Color = options.background_color orelse .blank;

    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .background_color = background_color,
        .layout = .{
            .sizing = options.sizing,
        },
        .floating = .{
            .attach_to = .parent,
            .attach_points = .{
                .parent = options.attach_point,
            },
            .offset = .init(options.offset.x, options.offset.y),
            .z_index = Theme.z_index.handle,
        },
    });

    var result: Result = .{};

    if (clay.hovered()) {
        result.interaction = .hovering;
    }

    if (state.isFocusedTop(id) and raylib.isMouseButtonDown(.left)) {
        const delta = raylib.getMouseDelta();
        result.mouse_delta.x = delta.x;
        result.mouse_delta.y = delta.y;
        result.interaction = .dragging;
    }

    clay.closeElement();

    return result;
}
