const raylib = @import("raylib");
const std = @import("std");

const Self = @This();

state: raylib.Camera2D = .{},
zoom_step: f32 = 0.05,

pub fn reset(self: *Self) void {
    self.state.target = .{};
    self.state.offset = .{};
    self.state.zoom = 1.0;
}

pub fn mousePosition(self: Self) raylib.Vector2 {
    const mouse_pos = raylib.getMousePosition();
    return raylib.getScreenToWorld2D(mouse_pos, self.state);
}

pub fn mousePositionFrom(self: Self, point: raylib.Vector2) raylib.Vector2 {
    return raylib.getScreenToWorld2D(point, self.state);
}

pub fn zoomToMouse(self: *Self, delta: f32) void {
    const mouse_pos = raylib.getMousePosition();
    const world_pos = raylib.getScreenToWorld2D(mouse_pos, self.state);

    const zoom_delta = self.zoom_step * delta;
    self.state.offset = mouse_pos;
    self.state.target = world_pos;
    self.state.zoom = @max(self.state.zoom + zoom_delta, 0.05);
}

pub fn focusWithin(self: *Self, bounds: raylib.Rectangle, target_size: raylib.Vector2) void {
    self.reset();
    self.state.target = .init(
        bounds.width * -0.5 + target_size.x * 0.5,
        bounds.height * -0.5 + target_size.y * 0.5,
    );
}

pub fn move(self: *Self, delta: raylib.Vector2) void {
    self.state.target = self.state.target.add(delta).round();
}

pub fn begin(self: Self) void {
    raylib.beginMode2D(self.state);
}

pub fn end(_: Self) void {
    raylib.endMode2D();
}
