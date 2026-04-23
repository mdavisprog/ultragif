const canvas = @import("../../canvas/root.zig");
const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const input = @import("../../input.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");
const TextureCache = @import("../../TextureCache.zig");
const Theme = @import("../Theme.zig");
const units = @import("../../units.zig");

const Texture = TextureCache.Texture;

pub const Category = enum {
    animations,
    texture,
    export_,
};

const sizer_size: f32 = 8.0;
const min_size: f32 = 0.2;

/// The right side panel containing information and tools for organizing/manipulating GIFs.
const Self = @This();
const id: clay.ElementId = .fromLabel("Panel");

category: Category = .animations,
x_pos: f32 = 0.0,

pub fn init(x_pos: f32) Self {
    return .{ .x_pos = x_pos };
}

pub fn draw(self: *Self, container: *Container) void {
    // Main background panel
    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = .{
            .sizing = .{
                .width = .grow(0.0, 0.0),
                .height = .percent(1.0),
            },
            .layout_direction = .top_to_bottom,
            .padding = .axes(4, 4),
            .child_gap = 4,
        },
        .background_color = container.state.theme.colors.background,
        .clip = .{
            .horizontal = true,
        },
    });
    {
        switch (self.category) {
            .animations => {
                drawAnimations(container);
            },
            .texture => {
                drawTexturesInfo(container);
            },
            .export_ => {
                drawExport(container);
            },
        }

        const element = clay.getElementData(id);
        const handle_options: controls.handle.Options = .{
            .offset = .init(sizer_size * -0.5, 0.0),
            .sizing = .fixed(sizer_size, element.bounding_box.height),
        };
        const result = controls.handle.draggable(
            container.state,
            .fromLabel("Panel_Sizer"),
            handle_options,
        );

        switch (result.interaction) {
            .hovering => {
                input.mouse.setCursor(.resize_ew);
            },
            .dragging => {
                input.mouse.setCursor(.resize_ew);
                self.x_pos += result.mouse_delta.x;
                self.clampSize();
            },
            .none => {
                input.mouse.setCursor(.default);
            },
        }
    }
    clay.closeElement();

    controls.separator.vertical(container.state, .{});

    self.drawCategories(container);
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

pub fn setPanelPos(self: *Self, pos: f32) void {
    self.x_pos = pos;
    self.clampSize();
}

fn clampSize(self: *Self) void {
    const width: f32 = @floatFromInt(raylib.getScreenWidth());
    const pct = 1.0 - self.x_pos / width;
    if (pct < min_size) {
        self.x_pos = (1.0 - min_size) * width;
    }
}

fn drawTitle(state: State, text: []const u8) void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
            },
            .child_alignment = .init(.center, .center),
        },
    });
    {
        controls.text.label(state, text, .{ .text_alignment = .center });
    }
    clay.closeElement();

    controls.separator.horizontal(state, .{});
}

fn drawTexturesInfo(container: *Container) void {
    const arena = container.state.getArenaAllocator();

    var bytes: usize = 0;
    var textures = container.app.texture_cache.textures.valueIterator();
    while (textures.next()) |texture| {
        bytes += texture.*.sheet.memorySize();
    }

    drawTitle(container.state, "Textures");

    const memory: units.Memory = .fromBytes(bytes);
    const memory_text = formatString(
        arena,
        "Memory: {} {s}",
        .{ memory.amount, memory.symbolString() },
    );

    const config: controls.text.Config = .{ .font_size = 18 };
    controls.text.label(container.state, memory_text, config);

    const current_texture = container.app.canvas_scene.texture;

    controls.list.begin();
    textures = container.app.texture_cache.textures.valueIterator();
    while (textures.next()) |texture| {
        const selected = if (current_texture) |t| t == texture.* else false;
        const clicked = controls.list.beginItem(container.state, .{ .selected = selected });
        controls.text.label(container.state, formatString(arena, "{s}", .{texture.*.name()}), config);
        controls.list.endItem();

        if (clicked) {
            container.app.canvas_scene.texture = texture.*;
        }
    }
    controls.list.end();
}

fn drawAnimations(container: *Container) void {
    const arena = container.state.getArenaAllocator();

    const animations = container.app.canvas_scene.getObjects(arena, canvas.Animation) catch |err| {
        std.debug.panic("Failed to get animations from canvas. Error: {}", .{err});
    };
    defer arena.free(animations);

    drawTitle(container.state, "Canvas");

    const config: controls.text.Config = .{ .font_size = 18 };
    controls.list.begin();
    for (animations) |animation| {
        const selected = container.app.canvas_scene.isSelected(animation);
        const _animation = animation.as(canvas.Animation);
        const name = _animation.texture.name();
        const clicked = controls.list.beginItem(container.state, .{ .selected = selected });
        controls.text.label(container.state, formatString(arena, "{s}", .{name}), config);
        controls.list.endItem();

        if (clicked) {
            container.app.canvas_scene.setSelection(animation);
        }
    }
    controls.list.end();
}

fn drawExport(container: *Container) void {
    drawTitle(container.state, "Export");

    const export_file_name: clay.ElementId = .fromLabel("Export_File_Name");

    // Container to hold all options.
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .grow(0.0, 0.0),
            },
            .layout_direction = .top_to_bottom,
            .child_gap = 4,
            .child_alignment = .init(.center, .top),
        },
        .clip = .all(true),
    });
    {
        controls.text.label(container.state, "File Name", .{ .text_alignment = .center });
        _ = controls.input.text(&container.state, export_file_name, .{
            .default_text = "export",
        });
    }
    clay.closeElement();

    // Export button
    const disabled = container.app.canvas_scene.numObjects(canvas.Animation) == 0;
    const export_result = controls.button.label(
        container.state,
        clay.idc("export"),
        .init("Export"),
        .{ .disabled = disabled },
    );

    if (export_result == .clicked) {
        const export_data = container.state.getData(export_file_name).?;
        if (export_data.input.len() == 0) {
            export_data.input.setContents(container.state.getAllocator(), "export");
        }
        container.app.exportScene(export_data.input.str());
    }
}

fn drawCategories(self: *Self, container: *Container) void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .height = .percent(1.0),
            },
            .layout_direction = .top_to_bottom,
            .padding = .axes(8, 8),
            .child_gap = 4,
        },
        .background_color = container.state.theme.colors.background,
    });
    {
        const count = @typeInfo(Category).@"enum".fields.len;
        for (0..count) |i| {
            self.drawCategoryIcon(container, @enumFromInt(i));
        }
    }
    clay.closeElement();
}

fn drawCategoryIcon(self: *Self, container: *Container, category: Category) void {
    const is_selected = self.category == category;
    const background_color: clay.Color = if (is_selected)
        container.state.theme.colors.button_background
    else
        .blank;

    clay.openElement();
    clay.configureOpenElement(.{
        .corner_radius = .all(container.state.theme.constants.button_corner_radius),
        .background_color = background_color,
    });

    const icon = switch (category) {
        .animations => Theme.Icon.animated_images,
        .texture => Theme.Icon.texture,
        .export_ => Theme.Icon.export_,
    };

    const layout: clay.LayoutConfig = .{
        .child_alignment = .init(.center, .center),
        .padding = .splat(4.0),
    };

    const result = controls.button.image(
        container.state,
        getCategoryId(category),
        .{ .texture = container.state.theme.getIcon(icon) },
        .{ .background_color = .blank, .layout = layout },
    );

    if (result == .clicked) {
        self.category = category;

        container.app.canvas_scene.draw_type = switch (category) {
            .animations, .export_ => .animations,
            .texture => .texture,
        };
    }

    clay.closeElement();
}

fn getCategoryId(category: Category) clay.ElementId {
    const prefix = "category_";
    return switch (category) {
        .animations => clay.idc(prefix ++ "animation"),
        .texture => clay.idc(prefix ++ "texture"),
        .export_ => clay.idc(prefix ++ "export"),
    };
}

fn formatString(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) []const u8 {
    const result = std.fmt.allocPrint(allocator, format, args) catch |err| {
        std.debug.panic("Failed to allocate string. Error: {}", .{err});
    };

    return result;
}
