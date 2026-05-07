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
    value: f32 = 0.0,
};

pub fn range(state: *State, id: clay.ElementId, options: Options) f32 {
    const element = clay.getElementData(id);
    const width = element.bounding_box.size().x - Theme.Icons.slider_handle_size;

    const data = state.getData(id) orelse state.addData(id, .{ .slider = .{} });
    const value = @max(options.value, options.min);
    const value_range = options.max - options.min;
    const value_ratio = (value - options.min) / value_range;
    data.slider.position = value_ratio * width;

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

    const ratio = data.slider.position / width;
    return ratio * value_range + options.min;
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
                    .height = .fixed(Theme.Icons.slider_handle_size * 0.4),
                },
            },
            .corner_radius = .all(std.math.degreesToRadians(45.0)),
        });
        clay.closeElement();
    }
    clay.closeElement();
}

fn drawHandle(state: *State, id: clay.ElementId) void {
    const data = state.getData(id) orelse return;
    const slider_id: clay.ElementId = .fromStringOffset("slider_handle", id.base_id);
    const slider_data = clay.getElementData(id);

    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .height = .grow(0.0, 0.0),
            },
        },
        .floating = .{
            .attach_to = .parent,
            .offset = .{
                .x = data.slider.position,
            },
        },
    });
    {
        const result = controls.handle.draggable(state.*, slider_id, .{
            .sizing = .grow(0.0, 0.0),
        });

        clay.openElement();
        clay.configureOpenElement(.{
            .layout = .{
                .sizing = .{
                    .height = .percent(1.0),
                },
                .child_alignment = .{
                    .y = .center,
                },
            },
        });
        {
            controls.image.tint(state.*, state.theme.icons.slider_handle, .white);
        }
        clay.closeElement();

        switch (result.interaction) {
            .dragging => {
                data.slider.position = std.math.clamp(
                    data.slider.position + result.mouse_delta.x,
                    0.0,
                    slider_data.bounding_box.size().x - Theme.Icons.slider_handle_size,
                );
            },
            else => {},
        }
    }
    clay.closeElement();
}
