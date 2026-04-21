const clay = @import("clay");
const State = @import("../State.zig");

pub const Options = struct {
    padding: u16 = 8,
};

const Type = enum {
    horizontal,
    vertical,
};

pub fn vertical(state: State, options: Options) void {
    container(state, .vertical, options);
}

pub fn horizontal(state: State, options: Options) void {
    container(state, .horizontal, options);
}

fn container(state: State, _type: Type, options: Options) void {
    const layout = getLayout(
        _type,
        state.theme.constants.separator_horizontal_size,
        state.theme.constants.separator_vertical_size,
        options,
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

fn getLayout(_type: Type, horizontal_size: f32, vertical_size: f32, options: Options) clay.LayoutConfig {
    return switch (_type) {
        .horizontal => .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .fixed(horizontal_size),
            },
            .padding = .axes(options.padding, 4),
            .child_alignment = .init(.center, .center),
        },
        .vertical => .{
            .sizing = .{
                .width = .fixed(vertical_size),
                .height = .percent(1.0),
            },
            .padding = .axes(4, options.padding),
            .child_alignment = .init(.center, .center),
        },
    };
}
