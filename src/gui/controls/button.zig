const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub const Config = struct {
    disabled: bool = false,
    background_color: ?clay.Color = null,
    hovered_color: ?clay.Color = null,
    active_color: ?clay.Color = null,
    disabled_color: ?clay.Color = null,
    layout: clay.LayoutConfig = .{
        .sizing = .{
            .width = .percent(1.0),
        },
        .child_alignment = .init(.center, .center),
        .padding = .axes(4, 2),
    },
    corner_radius: ?f32 = null,
};

pub const TextConfig = struct {
    text: []const u8,
    config: controls.text.Config = .{
        .text_alignment = .center,
    },

    pub fn init(text: []const u8) TextConfig {
        return .{
            .text = text,
        };
    }
};

pub const Result = enum {
    none,
    hovered,
    pressed,
    clicked,
};

pub fn label(state: State, id: clay.ElementId, text_config: TextConfig, config: Config) Result {
    const result = begin(state, id, config);
    {
        var _text_config = text_config.config;
        _text_config.disabled = config.disabled;

        controls.text.label(state, text_config.text, _text_config);
    }
    end();

    return result;
}

pub const ImageConfig = struct {
    texture: *raylib.Texture,
    color: clay.Color = .white,

    pub fn init(texture: *raylib.Texture) ImageConfig {
        return .{ .texture = texture };
    }
};

pub fn image(state: State, id: clay.ElementId, image_config: ImageConfig, config: Config) Result {
    const result = begin(state, id, config);
    {
        controls.image.tint(state, image_config.texture, image_config.color);
    }
    end();

    return result;
}

pub fn begin(state: State, id: clay.ElementId, config: Config) Result {
    const color: clay.Color = blk: {
        if (config.disabled) {
            break :blk config.disabled_color orelse state.theme.colors.button_disabled;
        }

        if (state.isFocused(id) and raylib.isMouseButtonDown(.left)) {
            break :blk config.active_color orelse state.theme.colors.button_active;
        }

        if (clay.pointerOver(id)) {
            break :blk config.hovered_color orelse state.theme.colors.button_hovered;
        }

        break :blk config.background_color orelse state.theme.colors.button_background;
    };

    const result: Result = blk: {
        if (config.disabled) break :blk .none;
        if (state.isFocused(id) and raylib.isMouseButtonDown(.left)) break :blk .pressed;
        if (state.isFocused(id) and clay.pointerOver(id) and raylib.isMouseButtonReleased(.left)) break :blk .clicked;
        if (clay.pointerOver(id)) break :blk .hovered;
        break :blk .none;
    };

    const corner_radius = if (config.corner_radius) |radius|
        radius
    else
        state.theme.constants.button_corner_radius;

    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = config.layout,
        .background_color = color,
        .corner_radius = .all(corner_radius),
    });

    return result;
}

pub fn end() void {
    clay.closeElement();
}
