const App = @import("../App.zig");
const clay = @import("clay");
const controls = @import("controls.zig");
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
}

pub fn draw(self: Self) void {
    const width: f32 = @floatFromInt(raylib.getRenderWidth());
    const height: f32 = @floatFromInt(raylib.getRenderHeight());

    clay.setLayoutDimensions(.init(width, height));
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
        },
        .background_color = .initu8(32, 32, 32, 255),
    });
    {
        const file_name = if (self.app.loaded_gif) |loaded_gif|
            std.fs.path.basename(loaded_gif.file_path)
        else
            "Drop file";

        controls.label(file_name, .{});
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
