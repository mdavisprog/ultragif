const Camera = @import("../Camera.zig");
const canvas = @import("root.zig");
const hash = @import("../hash.zig");
const input = @import("../input.zig");
const raylib = @import("raylib");
const std = @import("std");
const TextureCache = @import("../TextureCache.zig");

const Texture = TextureCache.Texture;

/// What should be rendered by the scene.
pub const DrawType = enum {
    animations,
    texture,
};

const Action = enum {
    none,
    pan_camera,
    move_object,
};

/// Animation times will be synced based on what texture they use.
const Timeline = struct {
    objects: std.ArrayListUnmanaged(*canvas.Object) = .empty,
    time: f32 = 0.0,
    max: f32 = 0.0,
};

/// Holds all objects contained within the Canvas.
const Self = @This();

camera: Camera = .{},
objects: std.ArrayListUnmanaged(*canvas.Object) = .empty,
selected: ?*canvas.Object = null,
hovered: ?*canvas.Object = null,
locked_mouse_pos: raylib.Vector2 = .zero,
action: Action = .none,
texture: ?*Texture = null,
draw_type: DrawType = .animations,
timelines: std.AutoHashMapUnmanaged(*Texture, Timeline) = .empty,

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (self.objects.items) |object| {
        object.deinit(allocator);
        allocator.destroy(object);
    }
    self.objects.deinit(allocator);

    var timelines = self.timelines.valueIterator();
    while (timelines.next()) |timeline| {
        timeline.objects.deinit(allocator);
    }
    self.timelines.deinit(allocator);
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
    texture: *Texture,
) !*canvas.Object {
    const animation = try allocator.create(canvas.Animation);
    animation.* = .init(texture);

    const result = try self.addObject(allocator, animation);

    if (self.timelines.getPtr(animation.texture)) |timeline| {
        try timeline.objects.append(allocator, result);
    } else {
        try self.timelines.put(allocator, animation.texture, .{
            .max = animation.texture.sheet.totalTime(),
        });
        try self.timelines.getPtr(animation.texture).?.objects.append(allocator, result);
    }

    return result;
}

pub fn addObject(self: *Self, allocator: std.mem.Allocator, object: anytype) !*canvas.Object {
    const result = try allocator.create(canvas.Object);
    result.* = .init(object);
    try self.objects.append(allocator, result);

    return result;
}

/// Returns a list of objects that matches the specific type. The returned array is owned by the caller.
pub fn getObjects(self: Self, allocator: std.mem.Allocator, comptime T: type) ![]const *canvas.Object {
    var result: std.ArrayListUnmanaged(*canvas.Object) = .empty;

    const type_id = hash.hashStruct(T);
    for (self.objects.items) |object| {
        if (object.type_id == type_id) {
            try result.append(allocator, object);
        }
    }

    return try result.toOwnedSlice(allocator);
}

pub fn numObjects(self: Self, comptime T: type) usize {
    var result: usize = 0;

    const type_id = hash.hashStruct(T);
    for (self.objects.items) |object| {
        if (object.type_id == type_id) {
            result += 1;
        }
    }

    return result;
}

pub fn setSelection(self: *Self, object: *canvas.Object) void {
    self.selected = object;
}

pub fn isSelected(self: Self, object: *const canvas.Object) bool {
    const selected = self.selected orelse return false;
    return selected == object;
}

/// The mouse state may be set to be invalid if it is interacting with the GUI layer.
pub fn update(self: *Self, delta_time: f32, mouse_state: input.mouse.State) void {
    if (self.action == .none) {
        self.hovered = null;
        const point = self.camera.mousePositionFrom(mouse_state.position);
        for (self.objects.items) |object| {
            object.update(delta_time);

            const bounds = object.bounds();
            if (bounds.contains(point)) {
                self.hovered = object;
            }
        }
    }

    if (mouse_state.isPressed(.left)) {
        if (self.hovered) |hovered| {
            self.selected = hovered;
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
                selected.position = selected.position.add(mouse_delta.scale(-1.0)).round();
            }

            if (mouse_button_released) {
                self.action = .none;
            }
        },
        .none => {},
    }

    self.updateTimelines(delta_time);
}

pub fn draw(self: Self) void {
    self.drawInternal(.darkgray);
}

pub fn drawClearBackground(self: Self) void {
    self.drawInternal(.blank);
}

pub fn resetAnimationTimes(self: Self) void {
    var timelines = self.timelines.valueIterator();
    while (timelines.next()) |timeline| {
        timeline.time = 0.0;
    }
}

pub fn advanceTime(self: Self, time: f32) void {
    self.updateTimelines(time);
}

fn drawInternal(self: Self, background_color: raylib.Color) void {
    self.camera.begin();
    defer self.camera.end();

    raylib.clearBackground(background_color);

    switch (self.draw_type) {
        .animations => {
            self.drawAnimations();
        },
        .texture => {
            self.drawTexture();
        },
    }
}

fn drawAnimations(self: Self) void {
    for (self.objects.items) |object| {
        if (!self.isTimelineObject(object)) {
            object.draw();
        }
    }

    var timelines = self.timelines.valueIterator();
    while (timelines.next()) |timeline| {
        for (timeline.objects.items) |object| {
            const animation = object.as(canvas.Animation);
            animation.drawFrameTime(object.position, timeline.time);
        }
    }

    if (self.hovered) |hovered| {
        raylib.drawRectangleLinesEx(hovered.bounds(), 1.0, .yellow);
    }

    if (self.selected) |selected| {
        raylib.drawRectangleLinesEx(selected.bounds(), 1.0, .yellow);
    }
}

fn drawTexture(self: Self) void {
    const texture = self.texture orelse return;
    raylib.drawTextureV(texture.sheet.texture, .zero, .white);
}

fn updateTimelines(self: Self, delta_time: f32) void {
    var timelines = self.timelines.valueIterator();
    while (timelines.next()) |timeline| {
        timeline.time += delta_time;

        if (timeline.time > timeline.max) {
            timeline.time = 0.0;
        }
    }
}

fn isTimelineObject(self: Self, object: *const canvas.Object) bool {
    var timelines = self.timelines.valueIterator();
    while (timelines.next()) |timeline| {
        for (timeline.objects.items) |item| {
            if (item == object) {
                return true;
            }
        }
    }

    return false;
}
