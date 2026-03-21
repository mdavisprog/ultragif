const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");

pub const ItemConfig = struct {
    selected: bool = false,
};

pub fn begin() void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{ .width = .percent(1.0) },
            .layout_direction = .top_to_bottom,
        },
    });
}

pub fn end() void {
    clay.closeElement();
}

pub fn beginItem(state: State, config: ItemConfig) bool {
    clay.openElement();

    var result = false;
    var background_color: clay.Color = .blank;

    if (clay.hovered()) {
        if (raylib.isMouseButtonPressed(.left)) {
            result = true;
        }

        background_color = state.theme.colors.button_hovered;
    }

    if (config.selected) {
        background_color = state.theme.colors.button_background;
    }

    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{ .width = .percent(1.0) },
            .padding = .axes(0, 4),
        },
        .background_color = background_color,
    });

    return result;
}

pub fn endItem() void {
    clay.closeElement();
}
