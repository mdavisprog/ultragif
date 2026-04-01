const Camera = @import("Camera.zig");
const canvas = @import("canvas/root.zig");
const colors = @import("colors.zig");
const gif = @import("gif.zig");
const gui = @import("gui/root.zig");
const input = @import("input.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");
const TextureCache = @import("TextureCache.zig");
const Viewport = @import("Viewport.zig");

pub const LoadedGIF = struct {
    format: gif.Format,
    sprite_sheet: SpriteSheet,
    file_path: []const u8,
};

/// State of the application.
const Self = @This();

loaded_gif: ?LoadedGIF = null,
canvas_scene: *canvas.Scene,
gui_container: gui.Container,
viewport: Viewport = .{},
texture_cache: TextureCache,
allocator: std.mem.Allocator,

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

    self.unloadGIF(allocator);
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
        try self.exportScene();
    }
}

pub fn draw(self: *Self) void {
    // Draw canvas
    self.canvas_scene.draw();

    // Draw GUI
    self.gui_container.draw();
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
        allocator.free(loaded_gif.file_path);
    }
}

fn gifToSpriteSheet(self: Self, path: []const u8) !SpriteSheet {
    const format = try gif.load(self.allocator, path);
    defer format.deinit(self.allocator);

    const sprite_sheet: SpriteSheet = try .init(self.allocator, format);
    std.log.info("Successfully loaded GIF '{s}.", .{path});

    return sprite_sheet;
}

fn exportScene(self: Self) !void {
    if (self.canvas_scene.numObjects(canvas.Animation) == 0) {
        std.log.warn("No animations in current scene.", .{});
        return;
    }

    const dir = try std.fs.cwd().realpathAlloc(self.allocator, ".");
    defer self.allocator.free(dir);

    const path = try std.fs.path.join(self.allocator, &.{ dir, "test.gif" });
    defer self.allocator.free(path);

    std.log.info("Exporting to {s}...", .{path});

    var writer: gif.Writer = try .init(self.allocator);
    defer writer.deinit();

    const animations = try self.canvas_scene.getObjects(self.allocator, canvas.Animation);
    defer self.allocator.free(animations);

    var pixels: std.Io.Writer.Allocating = .init(self.allocator);
    defer pixels.deinit();

    for (animations) |animation| {
        const anim = animation.as(canvas.Animation);
        writer.logical_screen_desc.width = @intFromFloat(anim.texture.sheet.frame_size.x);
        writer.logical_screen_desc.height = @intFromFloat(anim.texture.sheet.frame_size.y);

        const image = try anim.texture.sheet.toImage(self.allocator);
        defer image.deinit(self.allocator);

        var table: colors.ColorTable = try .initImage(self.allocator, image, .{
            .ignore_transparent = true,
        });
        defer table.deinit();

        var quantized = try table.quantize(255);
        defer quantized.deinit();

        var indexer: colors.Indexer = .initQuantized(quantized);
        try indexer.setTransparentColor(.init(204, 75, 202, 255));

        writer.setGlobalColorTable(try indexer.color_table.toBytes(3));

        for (anim.texture.sheet.frames) |frame| {
            const frame_data = try image.getRegionRect(self.allocator, frame.bounds);
            defer self.allocator.free(frame_data);

            const data = try indexer.indexImage(.initWithData(
                frame_data,
                @intFromFloat(frame.bounds.width),
                @intFromFloat(frame.bounds.height),
                .RGBA
            ));

            try writer.addImage(
                0,
                0,
                @intFromFloat(frame.bounds.width),
                @intFromFloat(frame.bounds.height),
                data,
                frame.delay,
                if (indexer.transparent_index) |index| @intCast(index) else null,
            );
        }

        try writer.save(path);

        break;
    }
}
