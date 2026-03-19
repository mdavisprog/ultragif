const raylib = @import("raylib");
const std = @import("std");
const TextureCache = @import("../TextureCache.zig");

const Texture = TextureCache.Texture;

/// Manages the animation of a sprite sheet.
const Self = @This();

texture: *Texture,
frame_index: usize = 0,
frame_time: f32 = 0.0,

pub fn init(texture: *Texture) Self {
    return .{
        .texture = texture,
    };
}

pub fn set(self: *Self, texture: *Texture) void {
    self.texture = texture;
    self.reset();
}

pub fn reset(self: *Self) void {
    self.frame_index = 0;
    self.frame_time = 0.0;
}

pub fn getFrame(self: Self) raylib.Rectangle {
    return self.texture.sheet.frames[self.frame_index].bounds;
}

pub fn update(self: *Self, delta_time: f32) void {
    self.frame_time += delta_time;

    const frame = self.texture.sheet.frames[self.frame_index];
    if (self.frame_time >= frame.delay) {
        self.frame_index = @mod(self.frame_index + 1, self.texture.sheet.frames.len);
        self.frame_time = 0.0;
    }
}

/// Object Interface
pub fn draw(self: *Self, position: raylib.Vector2) void {
    const frame = self.getFrame();
    raylib.drawTexturePro(
        self.texture.sheet.texture,
        frame,
        .init(position.x, position.y, frame.width, frame.height),
        .zero,
        0.0,
        .white,
    );
}

pub fn getSize(self: *const Self) raylib.Vector2 {
    return self.texture.sheet.frame_size;
}
