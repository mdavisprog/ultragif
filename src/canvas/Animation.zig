const raylib = @import("raylib");
const std = @import("std");
const TextureCache = @import("../TextureCache.zig");

const Texture = TextureCache.Texture;

/// Manages the animation of a sprite sheet.
const Self = @This();

texture: *Texture,

pub fn init(texture: *Texture) Self {
    return .{
        .texture = texture,
    };
}

pub fn set(self: *Self, texture: *Texture) void {
    self.texture = texture;
    self.reset();
}

pub fn getFrame(self: Self) raylib.Rectangle {
    return self.texture.sheet.frames[self.frame_index].bounds;
}

pub fn drawFrameTime(self: Self, position: raylib.Vector2, time: f32) void {
    const local_time = @mod(time, self.totalTime());

    var total_time: f32 = 0.0;
    var index: usize = 0;
    for (self.texture.sheet.frames) |frame| {
        if (local_time <= total_time) {
            break;
        }

        total_time += frame.delay;
        index += 1;
    }

    index = @mod(index, self.texture.sheet.frames.len);

    const frame = self.texture.sheet.frames[index];
    raylib.drawTexturePro(
        self.texture.sheet.texture,
        frame.bounds,
        .init(position.x, position.y, frame.bounds.width, frame.bounds.height),
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

pub fn totalTime(self: Self) f32 {
    return self.texture.sheet.totalTime();
}
