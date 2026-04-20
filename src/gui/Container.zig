const App = @import("../App.zig");
const build_config = @import("build_config");
const clay = @import("clay");
const controls = @import("controls/root.zig");
const gif = @import("../gif.zig");
const input = @import("../input.zig");
const raylib = @import("raylib");
const State = @import("State.zig");
const std = @import("std");
const version = @import("version");
const widgets = @import("widgets/root.zig");

/// Manages the GUI
const Self = @This();

app: *App,
canvas: widgets.Canvas = .{},
panel: widgets.Panel = .{},
status_bar: widgets.StatusBar,
state: State,
_memory: []const u8,
_arena: clay.Arena,
_context: *clay.Context,
_resizing: bool = false,
_delta_time: f32 = 0.0,

pub fn create(allocator: std.mem.Allocator, app: *App) !*Self {
    const result = try allocator.create(Self);

    const min_size: usize = @intCast(clay.minMemorySize());
    const memory = try allocator.alloc(u8, min_size);
    const arena = clay.createArenaWithCapacityAndMemory(min_size, @ptrCast(memory));
    const context = clay.initialize(arena, .{}, .{
        .error_handler_function = onError,
    }) orelse {
        std.debug.panic("Failed to initialize Clay library!", .{});
    };

    clay.setMeasureTextFunction(onMeasureText, result);

    var status_bar: widgets.StatusBar = .{};
    try status_bar.setStatus(allocator, "Welcome to UltraGIF v{s}!", .{version.full});

    result.* = .{
        .app = app,
        .panel = .init(@as(f32, @floatFromInt(raylib.getScreenWidth())) * 0.7),
        .status_bar = status_bar,
        .state = try .init(allocator),
        ._memory = memory,
        ._arena = arena,
        ._context = context,
    };

    return result;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self._memory);

    self.status_bar.deinit(allocator);
    self.state.deinit();
}

pub fn isMouseInCanvas(self: Self) bool {
    return self.canvas.isHovered();
}

pub fn update(self: *Self, delta_time: f32) void {
    self._delta_time = delta_time;
    self.state.update(delta_time);

    if (!build_config.shipping and raylib.isKeyPressed(.f1)) {
        const debug_enabled = clay.isDebugModeEnabled();
        clay.setDebugModeEnabled(!debug_enabled);
    }
}

pub fn frameResized(self: *Self, old_size: raylib.Vector2, new_size: raylib.Vector2) void {
    const current_pct = self.panel.x_pos / old_size.x;
    self.panel.setPanelPos(current_pct * new_size.x);
}

pub fn draw(self: *Self) void {
    const width: f32 = @as(f32, @floatFromInt(raylib.getScreenWidth()));
    const height: f32 = @as(f32, @floatFromInt(raylib.getScreenHeight()));

    const mouse_pos = raylib.getMousePosition();
    const mouse_down = raylib.isMouseButtonDown(.left);

    clay.setLayoutDimensions(.init(width, height));
    clay.setPointerState(.init(mouse_pos.x, mouse_pos.y), mouse_down);
    // Currently not using this function due to how clay handles scrolling. Clay uses the entire
    // element content space to scroll the element either with mouse button or mouse wheel.
    // We only want scrolling to occur with either mouse wheel or the scroll bar, so it is handled
    // manually for now.
    //clay.updateScrollContainers(...);
    clay.beginLayout();

    // The root element which covers the entire rendering viewport.
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .percent(1.0, 1.0),
        },
    });

    // Vertical container that holds two controls. The first being the horizontal container holding
    // the canvas and the panel. The second will be the status bar.
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .layout_direction = .top_to_bottom,
            .sizing = .percent(1.0, 1.0),
        },
    });
    {
        // Horizontal container for the canvas and panel.
        clay.openElement();
        clay.configureOpenElement(.{
            .layout = .{
                .sizing = .{
                    .width = .percent(1.0),
                    .height = .grow(0.0, 0.0),
                },
            },
        });
        {
            self.canvas.draw(self, self.panel.x_pos);
            self.panel.draw(self);
        }
        clay.closeElement();

        // Status bar
        self.status_bar.draw(self);
    }
    clay.closeElement();

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

            raylib.beginShaderMode(self.state.theme.font_shader);
            raylib.drawTextEx(
                self.state.theme.font.*,
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
        .image => {
            const image = command.render_data.image;
            const image_data = image.image_data orelse return;
            const texture: *raylib.Texture2D = @ptrCast(@alignCast(image_data));
            const color = image.background_color;
            raylib.drawTextureV(texture.*, .init(bbox.x, bbox.y), toRaylibColor(color));
        },
        else => {
            std.debug.print("Unhandled render command: {s}\n", .{@tagName(command.command_type)});
        },
    }
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
    const self: *Self = @ptrCast(@alignCast(ptr));

    const size = self.state.theme.measureText(
        text.str(),
        @floatFromInt(config.*.font_size),
        config.*.letter_spacing,
    );

    return .init(size.x, size.y);
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
