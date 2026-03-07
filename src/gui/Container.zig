const App = @import("../App.zig");
const clay = @import("clay");
const controls = @import("controls/root.zig");
const raylib = @import("raylib");
const State = @import("State.zig");
const std = @import("std");

/// Manages the GUI
const Self = @This();

const panel_id: clay.ElementId = clay.id("Panel");

app: *App,
font: *raylib.Font,
font_shader: raylib.Shader,
_state: State = .{},
_memory: []const u8,
_arena: clay.Arena,
_context: *clay.Context,

pub fn init(allocator: std.mem.Allocator, app: *App) !Self {
    const min_size: usize = @intCast(clay.minMemorySize());
    const memory = try allocator.alloc(u8, min_size);
    const arena = clay.createArenaWithCapacityAndMemory(min_size, @ptrCast(memory));
    const context = clay.initialize(arena, .{}, .{
        .error_handler_function = onError,
    }) orelse {
        std.debug.panic("Failed to initialize Clay library!", .{});
    };

    const file_data = raylib.loadFileData("assets/fonts/Roboto-Regular.ttf");
    defer raylib.unloadFileData(file_data);

    const font_size: i32 = 32;
    const glyphs = raylib.loadFontData(
        file_data,
        font_size,
        null,
        95,
        .sdf,
    );

    const font = try allocator.create(raylib.Font);
    font.* = .{
        .base_size = font_size,
        .glyphs = glyphs.ptr,
        .glyph_count = @intCast(glyphs.len),
    };

    const font_image = raylib.genImageFontAtlas(font.getGlyphs(), &font.recs, font_size, 0, 0);
    font.texture = raylib.loadTextureFromImage(font_image);
    raylib.setTextureFilter(font.texture, .bilinear);

    const font_shader = raylib.loadShader(null, "assets/shaders/sdf.fs");

    clay.setMeasureTextFunction(onMeasureText, font);

    return .{
        .app = app,
        .font = font,
        .font_shader = font_shader,
        ._state = .{},
        ._memory = memory,
        ._arena = arena,
        ._context = context,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self._memory);
    raylib.unloadFont(self.font.*);
    allocator.destroy(self.font);
    raylib.unloadShader(self.font_shader);
}

pub fn contains(_: Self, point: raylib.Vector2) bool {
    const element_data = clay.getElementData(panel_id);
    if (!element_data.found) {
        return false;
    }

    return element_data.bounding_box.contains(.init(point.x, point.y));
}

pub fn update(self: *Self) void {
    self._state.update();

    if (raylib.isKeyPressed(.f1)) {
        const debug_enabled = clay.isDebugModeEnabled();
        clay.setDebugModeEnabled(!debug_enabled);
    }
}

pub fn draw(self: *Self) void {
    const width: f32 = @floatFromInt(raylib.getRenderWidth());
    const height: f32 = @floatFromInt(raylib.getRenderHeight());

    const mouse_pos = raylib.getMousePosition();
    const mouse_down = raylib.isMouseButtonDown(.left);

    clay.setLayoutDimensions(.init(width, height));
    clay.setPointerState(.init(mouse_pos.x, mouse_pos.y), mouse_down);
    clay.beginLayout();

    // The root element which covers the entire rendering viewport.
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .percent(1.0, 1.0),
        },
    });

    // Left side of the panel is the view of the canvas.
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .percent(0.7, 1.0),
        },
    });
    clay.closeElement();

    self.drawPanel();

    clay.closeElement();

    const commands = clay.endLayout();

    for (commands.slice()) |command| {
        self.processCommand(command);
    }
}

fn processCommand(self: Self, command: clay.RenderCommand) void {
    const bbox = command.bounding_box;
    switch (command.command_type) {
        .rectangle => {
            const color = command.render_data.rectangle.background_color;
            const corners = command.render_data.rectangle.corner_radius;

            // Only support rounded corners on all or none.
            if (corners.top_left != 0.0) {
                raylib.drawRectangleRounded(
                    toRectangle(bbox),
                    corners.top_left,
                    8,
                    toRaylibColor(color),
                );
            } else {
                raylib.drawRectangleV(
                    .init(bbox.x, bbox.y),
                    .init(bbox.width, bbox.height),
                    toRaylibColor(color),
                );
            }
        },
        .text => {
            const color = command.render_data.text.text_color;
            const string = command.render_data.text.string_contents;
            const font_size = command.render_data.text.font_size;

            // Using raylib text functions for formatting for now. The library has a static buffer
            // already allocated for this case.
            const text = raylib.textSubtext(string.chars[0..@intCast(string.length)], 0, string.length);

            raylib.beginShaderMode(self.font_shader);
            raylib.drawTextEx(
                self.font.*,
                text,
                .init(bbox.x, bbox.y),
                @floatFromInt(font_size),
                0.0,
                toRaylibColor(color),
            );
            raylib.endShaderMode();
        },
        .border => {
            const border = command.render_data.border;
            const border_top: f32 = @floatFromInt(border.width.top);
            const border_right: f32 = @floatFromInt(border.width.right);
            const border_bottom: f32 = @floatFromInt(border.width.bottom);
            // Left border
            if (border.width.left > 0) {
                raylib.drawRectangle(
                    @intFromFloat(@round(bbox.x)),
                    @intFromFloat(@round(bbox.y + border.corner_radius.top_left)),
                    @intCast(border.width.left),
                    @intFromFloat(@round(bbox.height - border.corner_radius.top_left - border.corner_radius.bottom_left)),
                    toRaylibColor(border.color),
                );
            }
            // Right border
            if (border.width.right > 0) {
                raylib.drawRectangle(
                    @intFromFloat(@round(bbox.x + bbox.width - border_right)),
                    @intFromFloat(@round(bbox.y + border.corner_radius.top_right)),
                    @intCast(border.width.right),
                    @intFromFloat(@round(bbox.height - border.corner_radius.top_right - border.corner_radius.bottom_right)),
                    toRaylibColor(border.color),
                );
            }
            // Top border
            if (border.width.top > 0) {
                raylib.drawRectangle(
                    @intFromFloat(@round(bbox.x + border.corner_radius.top_left)),
                    @intFromFloat(@round(bbox.y)),
                    @intFromFloat(@round(bbox.width - border.corner_radius.top_left - border.corner_radius.top_right)),
                    @intCast(border.width.top),
                    toRaylibColor(border.color),
                );
            }
            // Bottom border
            if (border.width.bottom > 0) {
                raylib.drawRectangle(
                    @intFromFloat(@round(bbox.x + border.corner_radius.bottom_left)),
                    @intFromFloat(@round(bbox.y + bbox.height - border_bottom)),
                    @intFromFloat(@round(bbox.width - border.corner_radius.bottom_left - border.corner_radius.bottom_right)),
                    @intCast(border.width.bottom),
                    toRaylibColor(border.color),
                );
            }
            if (border.corner_radius.top_left > 0) {
                raylib.drawRing(
                    .init(@round(bbox.x + border.corner_radius.top_left), @round(bbox.y + border.corner_radius.top_left)),
                    @round(border.corner_radius.top_left - border_top),
                    border.corner_radius.top_left,
                    180.0,
                    270.0,
                    10,
                    toRaylibColor(border.color),
                );
            }
            if (border.corner_radius.top_right > 0) {
                raylib.drawRing(
                    .init(@round(bbox.x + bbox.width - border.corner_radius.top_right), @round(bbox.y + border.corner_radius.top_right)),
                    @round(border.corner_radius.top_right - border_top),
                    border.corner_radius.top_right,
                    270.0,
                    360.0,
                    10,
                    toRaylibColor(border.color),
                );
            }
            if (border.corner_radius.bottom_left > 0) {
                raylib.drawRing(
                    .init(@round(bbox.x + border.corner_radius.bottom_left), @round(bbox.y + bbox.height - border.corner_radius.bottom_left)),
                    @round(border.corner_radius.bottom_left - border_bottom),
                    border.corner_radius.bottom_left,
                    90.0,
                    180.0,
                    10,
                    toRaylibColor(border.color),
                );
            }
            if (border.corner_radius.bottom_right > 0) {
                raylib.drawRing(
                    .init(@round(bbox.x + bbox.width - border.corner_radius.bottom_right), @round(bbox.y + bbox.height - border.corner_radius.bottom_right)),
                    @round(border.corner_radius.bottom_right - border_bottom),
                    border.corner_radius.bottom_right,
                    0.1,
                    90.0,
                    10,
                    toRaylibColor(border.color),
                );
            }
        },
        .scissor_start => {
            raylib.beginScissorMode(
                @intFromFloat(bbox.x),
                @intFromFloat(bbox.y),
                @intFromFloat(bbox.width),
                @intFromFloat(bbox.height),
            );
        },
        .scissor_end => {
            raylib.endScissorMode();
        },
        else => {
            std.debug.print("Unhandled render command: {s}\n", .{@tagName(command.command_type)});
        },
    }
}

fn drawPanel(self: Self) void {
    // Main background panel
    clay.openElement();
    clay.configureOpenElement(.{
        .id = panel_id,
        .layout = .{
            .sizing = .percent(1.0, 1.0),
            .layout_direction = .top_to_bottom,
            .padding = .axes(4, 4),
        },
        .background_color = .initu8(32, 32, 32, 255),
    });
    {
        const file_name = if (self.app.loaded_gif) |loaded_gif|
            std.fs.path.basename(loaded_gif.file_path)
        else
            "Drop file";

        controls.text.label(file_name, .{});
    }
    clay.closeElement();
}

fn onError(err: clay.ErrorData) callconv(.c) void {
    std.log.warn("Clay error: {} '{s}'\n", .{ err.error_type, err.error_text.str() });
}

fn onMeasureText(
    text: clay.StringSlice,
    config: [*c]clay.TextElementConfig,
    user_data: ?*anyopaque,
) callconv(.c) clay.Dimensions {
    const ptr = user_data orelse return .{};
    const font: *raylib.Font = @ptrCast(@alignCast(ptr));
    const size = raylib.measureTextEx(
        font.*,
        text.str(),
        @floatFromInt(config.*.font_size),
        @floatFromInt(config.*.letter_spacing),
    );
    return toDimensions(size);
}

fn toRaylibColor(color: clay.Color) raylib.Color {
    return .init(
        @intFromFloat(color.r),
        @intFromFloat(color.g),
        @intFromFloat(color.b),
        @intFromFloat(color.a),
    );
}

fn toRectangle(bbox: clay.BoundingBox) raylib.Rectangle {
    return .init(
        bbox.x,
        bbox.y,
        bbox.width,
        bbox.height,
    );
}

fn toDimensions(dimensions: raylib.Vector2) clay.Dimensions {
    return .init(dimensions.x, dimensions.y);
}
