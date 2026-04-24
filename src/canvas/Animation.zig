const raylib = @import("raylib");
const std = @import("std");
const SpriteSheet = @import("../SpriteSheet.zig");
const TextureCache = @import("../TextureCache.zig");

const Frame = SpriteSheet.Frame;
const Texture = TextureCache.Texture;

/// Manages the animation of a sprite sheet.
const Self = @This();

texture: *Texture,
frames: []Frame,

pub fn init(allocator: std.mem.Allocator, texture: *Texture) !Self {
    return .{
        .texture = texture,
        .frames = try allocator.dupe(Frame, texture.sheet.frames),
    };
}

pub fn set(self: *Self, texture: *Texture) void {
    self.texture = texture;
    self.reset();
}

pub fn drawElapsed(self: Self, position: raylib.Vector2, elapsed: f32) void {
    var total: f32 = 0.0;
    var bounds_index: usize = 0;

    for (self.frames) |frame| {
        if (elapsed <= total) {
            bounds_index = frame.bounds_index;
            break;
        }

        total += frame.delay;
    }

    const bounds = self.texture.sheet.frame_bounds[bounds_index];
    raylib.drawTexturePro(
        self.texture.sheet.texture,
        bounds,
        .init(position.x, position.y, bounds.width, bounds.height),
        .zero,
        0.0,
        .white,
    );
}

/// Object Interface
pub fn update(self: *Self, delta_time: f32) void {
    // Empty for now.
    _ = self;
    _ = delta_time;
}

pub fn draw(self: *Self, position: raylib.Vector2) void {
    // Empty for now.
    _ = self;
    _ = position;
}

pub fn getSize(self: *const Self) raylib.Vector2 {
    return self.texture.sheet.frame_size;
}

pub fn cleanup(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.frames);
}

pub fn totalTime(self: Self) f32 {
    var result: f32 = 0.0;

    for (self.frames) |frame| {
        result += frame.delay;
    }

    return result;
}
