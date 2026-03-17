const Animator = @import("Animator.zig");
const Camera = @import("Camera.zig");
const canvas = @import("canvas/root.zig");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
const input = @import("input.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const Viewport = @import("Viewport.zig");

pub const LoadedGIF = struct {
    format: gif.Format,
    sprite_sheet: SpriteSheet,
    file_path: []const u8,
};

/// State of the application.
const Self = @This();

loaded_gif: ?LoadedGIF = null,
show_sprite_sheet: bool = false,
animator: Animator = .{},
canvas_scene: *canvas.Scene,
gui_container: gui.Container,
viewport: Viewport = .{},
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !*Self {
    const canvas_scene = try allocator.create(canvas.Scene);
    canvas_scene.* = .{};

    const result = try allocator.create(Self);
    result.* = .{
        .canvas_scene = canvas_scene,
        .gui_container = try .init(allocator, result),
        .allocator = allocator,
    };
    return result;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.unloadGIF(allocator);
    self.gui_container.deinit(allocator);

    self.canvas_scene.deinit(allocator);
    allocator.destroy(self.canvas_scene);
}

pub fn update(self: *Self, delta_time: f32) !void {
    const mouse_state: input.mouse.State = .current();

    switch (self.viewport.nextEvent()) {
        .size_changed => |size| {
            self.gui_container.frameResized(size.previous, size.current);
        },
        else => {},
    }

    // Update sprite sheet animation
    self.animator.update(delta_time);

    const mouse_in_canvas = self.gui_container.isMouseInCanvas();
    self.canvas_scene.update(delta_time, if (mouse_in_canvas) mouse_state else .invalid());

    // Check for dropped files
    if (raylib.isFileDropped()) {
        const files = raylib.loadDroppedFiles();
        defer raylib.unloadDroppedFiles(files);

        const paths = files.getPaths();
        if (paths.len > 0) {
            const path = std.mem.span(paths[0]);
            try self.loadGIF(self.allocator, path);
            try self.gui_container.loadedGIF(self.allocator);

            if (self.loaded_gif) |loaded_gif| {
                self.animator.set(&loaded_gif.sprite_sheet);
                self.focusGIF(self.gui_container.canvas.bounds());
            }
        }
    }

    self.gui_container.update();
}

pub fn draw(self: *Self) void {
     // Draw canvas
    self.canvas_scene.camera.begin();
    raylib.clearBackground(.darkgray);

    if (self.loaded_gif) |loaded_gif| {
        if (self.show_sprite_sheet) {
            raylib.drawTextureV(loaded_gif.sprite_sheet.texture, .zero, .white);
        } else {
            const frame = self.animator.getFrame();
            raylib.drawTexturePro(
                loaded_gif.sprite_sheet.texture,
                frame,
                .init(0.0, 0.0, frame.width, frame.height),
                .zero,
                0.0,
                .white,
            );
        }
    }

    self.canvas_scene.camera.end();

    // Draw GUI
    self.gui_container.draw();
}

pub fn focusGIF(self: *Self, bounds: raylib.Rectangle) void {
    const loaded_gif = self.loaded_gif orelse return;
    const frame_size = loaded_gif.sprite_sheet.frame_size;
    self.canvas_scene.camera.focusWithin(bounds, frame_size);
}

pub fn loadGIF(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    self.unloadGIF(allocator);

    const format = try gif.load(allocator, path);
    errdefer format.deinit(allocator);

    const sprite_sheet = try SpriteSheet.init(allocator, format);
    errdefer sprite_sheet.deinit(allocator);

    self.loaded_gif = .{
        .format = format,
        .sprite_sheet = sprite_sheet,
        .file_path = try allocator.dupe(u8, path),
    };

    std.debug.print("Successfully loaded GIF file '{s}'.\n", .{path});
}

fn unloadGIF(self: *Self, allocator: std.mem.Allocator) void {
    if (self.loaded_gif) |loaded_gif| {
        loaded_gif.format.deinit(allocator);
        loaded_gif.sprite_sheet.deinit(allocator);
        allocator.free(loaded_gif.file_path);
    }
}
