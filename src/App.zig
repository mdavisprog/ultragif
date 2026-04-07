const Camera = @import("Camera.zig");
const canvas = @import("canvas/root.zig");
const colors = @import("colors.zig");
const Exporter = @import("Exporter.zig");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
const input = @import("input.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const TextureCache = @import("TextureCache.zig");
const Viewport = @import("Viewport.zig");

/// State of the application.
const Self = @This();

canvas_scene: *canvas.Scene,
gui_container: gui.Container,
viewport: Viewport = .{},
texture_cache: TextureCache,
allocator: std.mem.Allocator,
export_scene: bool = false,

pub fn init(allocator: std.mem.Allocator) !*Self {
    const canvas_scene = try allocator.create(canvas.Scene);
    canvas_scene.* = .{};

    const result = try allocator.create(Self);
    result.* = .{
        .canvas_scene = canvas_scene,
        .gui_container = try .init(allocator, result),
        .texture_cache = .init(),
        .allocator = allocator,
    };
    return result;
}

pub fn deinit(self: *Self) void {
    const allocator = self.allocator;

    self.gui_container.deinit(allocator);

    self.canvas_scene.deinit(allocator);
    allocator.destroy(self.canvas_scene);

    self.texture_cache.deinit(allocator);
}

pub fn update(self: *Self, delta_time: f32) !void {
    const mouse_state: input.mouse.State = .current();

    switch (self.viewport.nextEvent()) {
        .size_changed => |size| {
            self.gui_container.frameResized(size.previous, size.current);
        },
        else => {},
    }

    const mouse_in_canvas = self.gui_container.isMouseInCanvas();
    self.canvas_scene.update(delta_time, if (mouse_in_canvas) mouse_state else .invalid());

    // Check for dropped files
    if (raylib.isFileDropped()) {
        const files = raylib.loadDroppedFiles();
        defer raylib.unloadDroppedFiles(files);

        var position: raylib.Vector2 = self.canvas_scene.camera.mousePosition();
        const paths = files.getPaths();
        for (paths) |path| {
            const _path = std.mem.span(path);
            const texture = self.texture_cache.loadGIF(self.allocator, _path) catch {
                continue;
            };

            const animation = try self.canvas_scene.addAnimation(self.allocator, texture);
            animation.position = position;

            position.x += texture.sheet.frame_size.x;
        }
    }

    self.gui_container.update();

    if (raylib.isKeyPressed(.e)) {
        self.export_scene = true;
    }
}

pub fn draw(self: *Self) !void {
    if (self.export_scene) {
        self.export_scene = false;

        const exporter: Exporter = .init(self.canvas_scene);
        try exporter.exportScene(self.allocator);
    }

    // Draw canvas
    self.canvas_scene.draw();

    // Draw GUI
    self.gui_container.draw();
}
