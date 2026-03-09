const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");

/// Manages the animation of a sprite sheet.
const Self = @This();

sprite_sheet: ?*const SpriteSheet = null,
frame_index: usize = 0,
frame_time: f32 = 0.0,

pub fn set(self: *Self, sprite_sheet: *const SpriteSheet) void {
    self.sprite_sheet = sprite_sheet;
    self.reset();
}

pub fn reset(self: *Self) void {
    self.frame_index = 0;
    self.frame_time = 0.0;
}

pub fn getFrame(self: Self) raylib.Rectangle {
    const sprite_sheet = self.sprite_sheet orelse return .zero;
    return sprite_sheet.frames[self.frame_index].bounds;
}

pub fn update(self: *Self, delta_time: f32) void {
    const sprite_sheet = self.sprite_sheet orelse return;

    self.frame_time += delta_time;

    const frame = sprite_sheet.frames[self.frame_index];
    if (self.frame_time >= frame.delay) {
        self.frame_index = @mod(self.frame_index + 1, sprite_sheet.frames.len);
        self.frame_time = 0.0;
    }
}
