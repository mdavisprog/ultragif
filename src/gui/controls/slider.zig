const clay = @import("clay");
const controls = @import("root.zig");
const State = @import("../State.zig");
const std = @import("std");
const Theme = @import("../Theme.zig");

pub const Data = struct {
    position: f32 = 0.0,
};

pub const Options = struct {
    min: f32 = 0.0,
    max: f32 = std.math.floatMax(f32),
};

pub fn range(state: *State, id: clay.ElementId, options: Options) f32 {
    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = .{
            .sizing = .{
                .width = .grow(0.0, 0.0),
                .height = .fixed(Theme.Icons.height),
            },
        },
    });
    {
        drawBar();
        drawHandle(state, id);
    }
    clay.closeElement();

    const data = state.getData(id) orelse return 0.0;
    const element = clay.getElementData(id);
    const ratio = data.slider.position / (element.bounding_box.size().x - Theme.Icons.height);
    return (ratio * (options.max - options.min)) + options.min;
}

fn drawBar() void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .percent(1.0, 1.0),
            .child_alignment = .{
                .y = .center,
            },
        },
    });
    {
        clay.openElement();
        clay.configureOpenElement(.{
            .background_color = .initu8(224, 224, 224, 255),
            .layout = .{
                .sizing = .{
                    .width = .percent(1.0),
                    .height = .fixed(8.0),
                },
            },
            .corner_radius = .all(std.math.degreesToRadians(45.0)),
        });
        clay.closeElement();
    }
    clay.closeElement();
}

fn drawHandle(state: *State, id: clay.ElementId) void {
    const data = state.getData(id) orelse state.addData(id, .{ .slider = .{} });
    const slider_id: clay.ElementId = .fromStringOffset("slider_handle", id.base_id);

    clay.openElement();
    clay.configureOpenElement(.{
        .floating = .{
            .attach_to = .parent,
            .offset = .{
                .x = data.slider.position,
            },
        },
    });
    {
        const slider_data = clay.getElementData(id);

        const result = controls.handle.draggable(state.*, slider_id, .{
            .sizing = .grow(0.0, 0.0),
        });
        controls.image.tint(state.*, state.theme.getIcon(.slider_handle), .white);

        switch (result.interaction) {
            .dragging => {
                data.slider.position = std.math.clamp(
                    data.slider.position + result.mouse_delta.x,
                    0.0,
                    slider_data.bounding_box.size().x - Theme.Icons.height,
                );
            },
            else => {},
        }
    }
    clay.closeElement();
}
