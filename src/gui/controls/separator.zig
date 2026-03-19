const clay = @import("clay");
const State = @import("../State.zig");

const Type = enum {
    horizontal,
    vertical,
};

pub fn vertical(state: State) void {
    container(state, .vertical);
}

pub fn horizontal(state: State) void {
    container(state, .horizontal);
}

fn container(state: State, _type: Type) void {
    const layout = getLayout(
        _type,
        state.theme.constants.separator_horizontal_size,
        state.theme.constants.separator_vertical_size,
    );

    clay.openElement();
    clay.configureOpenElement(.{
        .layout = layout,
        .background_color = state.theme.colors.background,
    });
    {
        clay.openElement();
        clay.configureOpenElement(.{
            .layout = layout,
            .background_color = state.theme.colors.separator,
        });
        clay.closeElement();
    }
    clay.closeElement();
}

fn getLayout(_type: Type, horizontal_size: f32, vertical_size: f32) clay.LayoutConfig {
    return switch (_type) {
        .horizontal => .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .fixed(horizontal_size),
            },
            .padding = .axes(8, 4),
            .child_alignment = .init(.center, .center),
        },
        .vertical => .{
            .sizing = .{
                .width = .fixed(vertical_size),
                .height = .percent(1.0),
            },
            .padding = .axes(4, 8),
            .child_alignment = .init(.center, .center),
        },
    };
}
