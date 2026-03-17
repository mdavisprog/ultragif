const Camera = @import("../Camera.zig");
const canvas = @import("root.zig");
const input = @import("../input.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("../SpriteSheet.zig");
const std = @import("std");

/// Holds all objects contained within the Canvas.
const Self = @This();

camera: Camera = .{},
objects: std.ArrayListUnmanaged(*canvas.Object) = .empty,
selected: ?*canvas.Object = null,
locked_mouse_pos: raylib.Vector2 = .zero,
action: Action = .none,

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (self.objects.items) |object| {
        object.deinit(allocator);
        allocator.destroy(object);
    }
    self.objects.deinit(allocator);
}

pub fn addShape(
    self: *Self,
    allocator: std.mem.Allocator,
    shape: canvas.Shape.Data,
    color: raylib.Color,
) !*canvas.Object {
    const _shape = try allocator.create(canvas.Shape);
    _shape.* = .init(shape);
    _shape.color = color;

    return try self.addObject(allocator, _shape);
}

pub fn addAnimation(
    self: *Self,
    allocator: std.mem.Allocator,
    sprite_sheet: SpriteSheet,
) !*canvas.Object {
    const animation = try allocator.create(canvas.Animation);
    animation.* = .init(sprite_sheet);

    return try self.addObject(allocator, animation);
}

pub fn addObject(self: *Self, allocator: std.mem.Allocator, object: anytype) !*canvas.Object {
    const result = try allocator.create(canvas.Object);
    result.* = .init(object);
    try self.objects.append(allocator, result);

    return result;
}

/// The mouse state may be set to be invalid if it is interacting with the GUI layer.
pub fn update(self: *Self, delta_time: f32, mouse_state: input.mouse.State) void {
    var hovered: ?*canvas.Object = null;
    const point = self.camera.mousePosition();
    for (self.objects.items) |object| {
        object.update(delta_time);

        const bounds = object.bounds();
        if (bounds.contains(point)) {
            hovered = object;
        }
    }

    if (mouse_state.isPressed(.left)) {
        if (hovered) |_hovered| {
            self.selected = _hovered;
            self.action = .move_object;
        } else {
            self.selected = null;
            self.locked_mouse_pos = raylib.getMousePosition();
            raylib.disableCursor();
            self.action = .pan_camera;
        }
    }

    // Update zoom
    if (mouse_state.wheel.y != 0.0) {
        self.camera.zoomToMouse(mouse_state.wheel.y);
    }

    // Ignoring the mouse state as this should apply even if hovering the GUI.
    const mouse_button_released = raylib.isMouseButtonReleased(.left);
    const mouse_delta = raylib.getMouseDelta().scale(-1.0 / self.camera.state.zoom);
    switch (self.action) {
        .pan_camera => {
            self.camera.move(mouse_delta);

            // End pan and enable the mouse. Reset position back to begin position.
            if (mouse_button_released) {
                raylib.enableCursor();
                raylib.setMousePosition(
                    @intFromFloat(self.locked_mouse_pos.x),
                    @intFromFloat(self.locked_mouse_pos.y),
                );
                self.action = .none;
            }
        },
        .move_object => {
            if (self.selected) |selected| {
                selected.position.addMut(mouse_delta.scale(-1.0));
            }

            if (mouse_button_released) {
                self.action = .none;
            }
        },
        .none => {},
    }
}

pub fn draw(self: Self) void {
    self.camera.begin();
    defer self.camera.end();

    raylib.clearBackground(.darkgray);

    for (self.objects.items) |object| {
        object.draw();
    }

    if (self.selected) |selected| {
        raylib.drawRectangleLinesEx(selected.bounds(), 1.0, .yellow);
    }
}

const Action = enum {
    none,
    pan_camera,
    move_object,
};
