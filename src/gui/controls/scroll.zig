const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub const BarType = enum {
    horizontal,
    vertical,
    both,
};

pub const Data = struct {
    scroll_position: clay.Vector2 = .zero,
    grab_position: clay.Vector2 = .zero,
};

pub fn bars(state: *State, parent: clay.ElementId, bar_type: BarType) void {
    const scroll = clay.getScrollContainerData(parent);
    if (!scroll.found) return;

    const pos = scroll.scroll_position.*;
    const scroll_dim = scroll.scroll_container_dimensions;
    const content_dim = scroll.content_dimensions;

    const h_overflow = scroll_dim.width < content_dim.width;
    const v_overflow = scroll_dim.height < content_dim.height;

    const bar_size = state.theme.constants.scroll_bar_size;
    const content_ratio = scroll_dim.div(content_dim);
    const scroll_bar_size: clay.Vector2 = .init(
        @max(content_ratio.width * scroll_dim.width, bar_size),
        @max(content_ratio.height * scroll_dim.height, bar_size),
    );

    const normalized_content: clay.Vector2 = .init(
        -pos.x / (content_dim.width - scroll_dim.width),
        -pos.y / (content_dim.height - scroll_dim.height),
    );

    const v_padding = if (h_overflow and bar_type == .both) bar_size else 0.0;
    const normalized_scroll: clay.Vector2 = .init(
        normalized_content.x * (scroll_dim.width - scroll_bar_size.x),
        normalized_content.y * (scroll_dim.height - scroll_bar_size.y - v_padding),
    );

    const arena = state.getArenaAllocator();
    const horizontal_id = getId(arena, parent, .horizontal);
    const vertical_id = getId(arena, parent, .vertical);

    if (bar_type == .horizontal or bar_type == .both) {
        if (h_overflow) {
            const h_options: controls.handle.Options = .{
                .offset = .init(normalized_scroll.x, -bar_size),
                .sizing = .fixed(scroll_bar_size.x, bar_size),
                .background_color = getColor(state.*, horizontal_id),
                .attach_point = .left_bottom,
            };
            drawHandle(state, .horizontal, horizontal_id, h_options, scroll);
        }
    }

    if (bar_type == .vertical or bar_type == .both) {
        if (v_overflow) {
            const v_options: controls.handle.Options = .{
                .offset = .init(-bar_size, normalized_scroll.y),
                .sizing = .fixed(bar_size, scroll_bar_size.y),
                .background_color = getColor(state.*, vertical_id),
                .attach_point = .right_top,
            };
            drawHandle(state, .vertical, vertical_id, v_options, scroll);
        }
    }

    if (clay.pointerOver(parent)) {
        const mouse_wheel = raylib.getMouseWheelMoveV();
        const min = scroll.scroll_container_dimensions.sub(scroll.content_dimensions);
        const step = state.theme.constants.mouse_wheel_scroll_step;
        scroll.scroll_position.*.x = std.math.clamp(
            scroll.scroll_position.*.x + mouse_wheel.x * step,
            min.width,
            0.0,
        );
        scroll.scroll_position.*.y = std.math.clamp(
            scroll.scroll_position.*.y + mouse_wheel.y * step,
            min.height,
            0.0,
        );
    }
}

fn drawHandle(
    state: *State,
    bar_type: BarType,
    id: clay.ElementId,
    options: controls.handle.Options,
    scroll: clay.ScrollContainerData,
) void {
    const data = state.getData(id) orelse state.addData(id, .{ .scroll = .{} });
    const result = controls.handle.draggable(state.*, id, options);
    switch (result.interaction) {
        .dragging => {
            const mouse_position = raylib.getMousePosition();
            if (raylib.isMouseButtonPressed(.left)) {
                data.scroll.grab_position = .init(mouse_position.x, mouse_position.y);
                data.scroll.scroll_position = scroll.scroll_position.*;
                state.scroll_bar = id;
            } else {
                const ratio = scroll.content_dimensions.div(scroll.scroll_container_dimensions);
                const grab_diff: clay.Vector2 = .init(
                    data.scroll.grab_position.x - mouse_position.x,
                    data.scroll.grab_position.y - mouse_position.y,
                );
                const position: clay.Vector2 = .init(
                    data.scroll.scroll_position.x + grab_diff.x * ratio.width,
                    data.scroll.scroll_position.y + grab_diff.y * ratio.height,
                );

                const min = scroll.scroll_container_dimensions.sub(scroll.content_dimensions);
                switch (bar_type) {
                    .horizontal => {
                        scroll.scroll_position.*.x = std.math.clamp(
                            position.x,
                            min.width,
                            0.0,
                        );
                    },
                    .vertical => {
                        scroll.scroll_position.*.y = std.math.clamp(
                            position.y,
                            min.height,
                            0.0,
                        );
                    },
                    .both => {},
                }
            }
        },
        else => {
            if (state.scroll_bar.eql(id)) {
                state.scroll_bar = .{};
            }
        },
    }
}

fn getId(allocator: std.mem.Allocator, parent: clay.ElementId, bar_type: BarType) clay.ElementId {
    const string = std.fmt.allocPrint(allocator, "{s}_{s}", .{
        parent.string_id.str(),
        getSuffix(bar_type),
    }) catch |err| {
        std.debug.panic("Failed to generate scroll bar id: {}", .{err});
    };

    return .fromString(string);
}

fn getSuffix(bar_type: BarType) []const u8 {
    return switch (bar_type) {
        .horizontal => "hsb",
        .vertical => "vsb",
        .both => {
            std.debug.panic("Invalid suffix.", .{});
        },
    };
}

fn getColor(state: State, id: clay.ElementId) clay.Color {
    if (clay.pointerOver(id) or state.scroll_bar.eql(id)) {
        return state.theme.colors.button_hovered;
    }

    return state.theme.colors.button_background;
}
