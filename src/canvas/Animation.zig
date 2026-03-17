const raylib = @import("raylib");
const SpriteSheet = @import("../SpriteSheet.zig");
const std = @import("std");

/// Manages the animation of a sprite sheet.
const Self = @This();

sprite_sheet: SpriteSheet,
frame_index: usize = 0,
frame_time: f32 = 0.0,

pub fn init(sprite_sheet: SpriteSheet) Self {
    return .{
        .sprite_sheet = sprite_sheet,
    };
}

pub fn set(self: *Self, sprite_sheet: SpriteSheet) void {
    self.sprite_sheet = sprite_sheet;
    self.reset();
}

pub fn reset(self: *Self) void {
    self.frame_index = 0;
    self.frame_time = 0.0;
}

pub fn getFrame(self: Self) raylib.Rectangle {
    return self.sprite_sheet.frames[self.frame_index].bounds;
}

pub fn update(self: *Self, delta_time: f32) void {
    self.frame_time += delta_time;

    const frame = self.sprite_sheet.frames[self.frame_index];
    if (self.frame_time >= frame.delay) {
        self.frame_index = @mod(self.frame_index + 1, self.sprite_sheet.frames.len);
        self.frame_time = 0.0;
    }
}

/// Object Interface
pub fn draw(self: *Self, position: raylib.Vector2) void {
    const frame = self.getFrame();
    raylib.drawTexturePro(
        self.sprite_sheet.texture,
        frame,
        .init(position.x, position.y, frame.width, frame.height),
        .zero,
        0.0,
        .white,
    );
}

pub fn getSize(self: *const Self) raylib.Vector2 {
    return self.sprite_sheet.frame_size;
}

pub fn cleanup(self: *Self, allocator: std.mem.Allocator) void {
    self.sprite_sheet.deinit(allocator);
}
