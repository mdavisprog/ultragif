const App = @import("../App.zig");
const clay = @import("clay");
const controls = @import("controls/root.zig");
const gif = @import("../gif.zig");
const panels = @import("panels.zig");
const raylib = @import("raylib");
const State = @import("State.zig");
const std = @import("std");

const roboto_regular = @embedFile("../assets/fonts/Roboto-Regular.ttf");
const sdf_fs = @embedFile("../assets/shaders/sdf.fs");

pub const GIFSummary = struct {
    version: []const u8,
    dimensions: []const u8,
    frame_count: []const u8,
    compressed_size: []const u8,
    uncompressed_size: []const u8,

    pub fn init(allocator: std.mem.Allocator, app: *const App) !GIFSummary {
        const loaded_gif = app.loaded_gif.?;
        const version = try std.fmt.allocPrint(allocator, "Version: {s}", .{loaded_gif.format.header.version});
        const dimensions = try std.fmt.allocPrint(
            allocator,
            "Size: {} x {}",
            .{ loaded_gif.format.logical_screen_descriptor.width, loaded_gif.format.logical_screen_descriptor.height },
        );
        const frame_count = try std.fmt.allocPrint(allocator, "Frames: {}", .{loaded_gif.format.getFrameCount()});

        const compressed_size_amount = try convertBytes(allocator, loaded_gif.format.getCompressedImageSize());
        defer allocator.free(compressed_size_amount);

        const compressed_size = try std.fmt.allocPrint(
            allocator,
            "Compressed Size: {s}",
            .{compressed_size_amount},
        );

        const uncompressed_size_amount = try convertBytes(allocator, loaded_gif.sprite_sheet.memorySize());
        defer allocator.free(uncompressed_size_amount);

        const uncompressed_size = try std.fmt.allocPrint(
            allocator,
            "Uncompressed Size: {s}",
            .{uncompressed_size_amount},
        );

        return .{
            .version = version,
            .dimensions = dimensions,
            .frame_count = frame_count,
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
        };
    }

    pub fn deinit(self: GIFSummary, allocator: std.mem.Allocator) void {
        allocator.free(self.version);
        allocator.free(self.dimensions);
        allocator.free(self.frame_count);
        allocator.free(self.compressed_size);
        allocator.free(self.uncompressed_size);
    }

    fn convertBytes(allocator: std.mem.Allocator, bytes: usize) ![]const u8 {
        // Bytes
        if (bytes < 1024) {
            return try std.fmt.allocPrint(allocator, "{} B", .{bytes});
        }

        // Kilobytes
        if (bytes < 1024 * 1024) {
            return try std.fmt.allocPrint(allocator, "{} KB", .{bytes / 1024});
        }

        if (bytes < 1024 * 1024 * 1024) {
            return try std.fmt.allocPrint(allocator, "{} MB", .{bytes / 1024 / 1024});
        }

        return try std.fmt.allocPrint(allocator, "{} GB", .{bytes / 1024 / 1024 / 1024});
    }
};

/// Manages the GUI
const Self = @This();

const panel_id: clay.ElementId = clay.id("Panel");

app: *App,
font: *raylib.Font,
font_shader: raylib.Shader,
_state: State = .{},
_summary: ?GIFSummary = null,
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

    const font_size: i32 = 32;
    const glyphs = raylib.loadFontData(
        roboto_regular,
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

    const font_shader = raylib.loadShaderFromMemory(null, sdf_fs);

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
    if (self._summary) |summary| {
        summary.deinit(allocator);
    }

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

    if (clay.isDebugModeEnabled()) {
        return true;
    }

    return element_data.bounding_box.contains(.init(point.x, point.y));
}

pub fn canvasBounds(_: Self) raylib.Rectangle {
    const element_data = clay.getElementData(panel_id);
    if (!element_data.found) {
        return .zero;
    }

    return .init(
        0.0,
        0.0,
        element_data.bounding_box.x,
        element_data.bounding_box.height,
    );
}

pub fn loadedGIF(self: *Self, allocator: std.mem.Allocator) !void {
    if (self._summary) |summary| {
        summary.deinit(allocator);
    }

    self._summary = try .init(allocator, self.app);
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
            .sizing = .{
                .width = .grow(0.0, 0.0),
                .height = .percent(1.0),
            },
            .layout_direction = .top_to_bottom,
            .padding = .axes(4, 4),
            .child_gap = 4,
        },
        .background_color = self._state.theme.colors.background,
    });
    {
        panels.info(&self);
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

    const scale_factor = @as(f32, @floatFromInt(config.*.font_size)) /
        @as(f32, @floatFromInt(font.base_size));

    var max_text_width: f32 = 0.0;
    var line_text_width: f32 = 0.0;
    var max_line_char_count: i32 = 0;
    var line_char_count: i32 = 0;

    for (0..@intCast(text.length)) |i| {
        defer line_char_count += 1;

        const ch = text.chars[i];
        if (ch == '\n') {
            max_text_width = @max(max_text_width, line_text_width);
            max_line_char_count = @max(max_line_char_count, line_char_count);
            line_text_width = 0.0;
            line_char_count = 0;
            continue;
        }

        if (ch < 32) continue;

        const codepoint: usize = @intCast(ch - 32);
        const glyph = font.*.glyphs[codepoint];

        if (glyph.advance_x != 0) {
            line_text_width += @as(f32, @floatFromInt(glyph.advance_x));
        } else {
            line_text_width += font.*.recs[codepoint].width + @as(f32, @floatFromInt(glyph.offset_x));
        }
    }

    max_text_width = @max(max_text_width, line_text_width);
    max_line_char_count = @max(max_line_char_count, line_char_count);

    const letter_spacing: f32 = @floatFromInt(line_char_count * config.*.letter_spacing);
    return .init(
        max_text_width * scale_factor + letter_spacing,
        @floatFromInt(config.*.font_size),
    );
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
