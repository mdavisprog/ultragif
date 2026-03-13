const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");
const Theme = @import("../Theme.zig");

/// Represents the area for viewing/editing.
const Self = @This();

const id: clay.ElementId = .fromLabel("Canvas");

pub fn isHovered(_: Self) bool {
    const hovered = clay.getPointerOverIds();
    if (hovered.len() == 0) {
        return false;
    }

    return hovered.get(hovered.len() - 1).eql(id);
}

pub fn bounds(_: Self) raylib.Rectangle {
    const element = clay.getElementData(id);
    if (!element.found) {
        return .zero;
    }

    return .init(
        element.bounding_box.x,
        element.bounding_box.y,
        element.bounding_box.width,
        element.bounding_box.height,
    );
}

pub fn draw(self: Self, container: *Container, width: f32) void {
    const state = container._state;

    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = .{
            .sizing = .{
                .width = .fixed(width),
                .height = .percent(1.0),
            },
        },
    });

    const padding = 6.0;
    clay.openElement();
    clay.configureOpenElement(.{
        .floating = .{
            .attach_to = .parent,
            .attach_points = .{ .parent = .right_top },
            .offset = .init(-Theme.Icons.width - padding, padding),
        },
    });
    {
        if (controls.button.image(
            state,
            .fromLabel("Camera"),
            .init(state.theme.getIcon(.camera)),
            .{
                .layout = .{
                    .sizing = .fit(0.0, 0.0),
                },
                .background_color = .blank,
                .hovered_color = .blank,
                .active_color = .blank,
                .disabled_color = .blank,
            },
        ) == .clicked) {
            container.app.focusGIF(self.bounds());
        }
    }
    clay.closeElement();

    clay.closeElement();
}
