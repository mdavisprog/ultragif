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

pub const Callbacks = struct {
    const OnAnimationRemoved = *const fn (*canvas.Animation, context: *anyopaque) void;

    context: *anyopaque,
    on_animation_removed: OnAnimationRemoved,

    pub fn init(
        on_animation_removed: OnAnimationRemoved,
        context: *anyopaque,
    ) Callbacks {
        return .{
            .on_animation_removed = on_animation_removed,
            .context = context,
        };
    }

    fn onAnimationRemoved(self: Callbacks, animation: *canvas.Animation) void {
        self.on_animation_removed(animation, self.context);
    }
};

pub const TimelineState = enum {
    pause,
    play,
};

const Action = enum {
    none,
    pan_camera,
    move_object,
};

/// Holds all objects contained within the Canvas.
const Self = @This();

/// Owns the memory for each object.
objects: std.ArrayListUnmanaged(*canvas.Object) = .empty,

/// Holds pointers to objects that are animations.
animations: std.ArrayListUnmanaged(*canvas.Object) = .empty,

camera: Camera = .{},
selected: ?*canvas.Object = null,
hovered: ?*canvas.Object = null,
locked_mouse_pos: raylib.Vector2 = .zero,
action: Action = .none,
texture: ?*Texture = null,
draw_type: DrawType = .animations,
allocator: std.mem.Allocator,
callbacks: Callbacks,
elapsed_time: f32 = 0.0,
timeline_state: TimelineState = .play,

pub fn init(allocator: std.mem.Allocator, callbacks: Callbacks) Self {
    return .{ .allocator = allocator, .callbacks = callbacks };
}

pub fn deinit(self: *Self) void {
    for (self.objects.items) |object| {
        object.deinit(self.allocator);
        self.allocator.destroy(object);
    }
    self.objects.deinit(self.allocator);
    self.animations.deinit(self.allocator);
}

pub fn addShape(self: *Self, shape: canvas.Shape.Data, color: raylib.Color) !*canvas.Object {
    const _shape = try self.allocator.create(canvas.Shape);
    _shape.* = .init(shape);
    _shape.color = color;

    return try self.addObject(self.allocator, _shape);
}

pub fn addAnimation(self: *Self, texture: *Texture) !*canvas.Object {
    const animation = try self.allocator.create(canvas.Animation);
    animation.* = try .init(self.allocator, texture);

    const result = try self.addObject(animation);
    try self.animations.append(self.allocator, result);

    return result;
}

pub fn addObject(self: *Self, object: anytype) !*canvas.Object {
    const result = try self.allocator.create(canvas.Object);
    result.* = .init(object);
    try self.objects.append(self.allocator, result);

    return result;
}

pub fn removeObject(self: *Self, object: *canvas.Object) bool {
    var result = false;
    for (self.objects.items, 0..) |item, i| {
        if (item == object) {
            _ = self.objects.orderedRemove(i);
            result = true;
            break;
        }
    }

    if (result) {
        if (object.isA(canvas.Animation)) {
            self.callbacks.onAnimationRemoved(object.as(canvas.Animation));

            for (self.animations.items, 0..) |animation, i| {
                if (animation == object) {
                    _ = self.animations.orderedRemove(i);
                    break;
                }
            }
        }

        object.deinit(self.allocator);
        self.allocator.destroy(object);
    }

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

pub fn numAnimationsWithTexture(self: Self, texture: *const Texture) usize {
    var result: usize = 0;

    for (self.animations.items) |object| {
        if (!object.isA(canvas.Animation)) continue;

        const animation = object.as(canvas.Animation);
        if (animation.texture == texture) {
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

pub fn deleteSelected(self: *Self) bool {
    const selected = self.selected orelse return false;
    self.selected = null;

    if (self.isHovered(selected)) {
        self.clearHovered();
    }

    return self.removeObject(selected);
}

pub fn isHovered(self: Self, object: *const canvas.Object) bool {
    const hovered = self.hovered orelse return false;
    return hovered == object;
}

pub fn clearHovered(self: *Self) void {
    self.hovered = null;
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

    switch (self.draw_type) {
        .animations => {
            if (raylib.isKeyPressed(.delete)) {
                _ = self.deleteSelected();
            }
        },
        .texture => {},
    }

    switch (self.timeline_state) {
        .pause => {},
        .play => {
            self.elapsed_time += delta_time;
            if (self.elapsed_time > self.getMaxTime()) {
                self.elapsed_time = 0.0;
            }
        },
    }
}

pub fn draw(self: Self) void {
    self.drawInternal(.darkgray);
}

pub fn drawClearBackground(self: Self) void {
    self.drawInternal(.blank);
}

pub fn resetElapsedTime(self: *Self) void {
    self.elapsed_time = 0.0;
}

pub fn advanceTime(self: *Self, time: f32) void {
    self.elapsed_time += time;
}

pub fn getMaxTime(self: Self) f32 {
    var result: f32 = 0.0;

    for (self.animations.items) |animation| {
        const anim = animation.as(canvas.Animation);
        result = @max(result, anim.totalTime());
    }

    return result;
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
        if (!object.isA(canvas.Animation)) {
            object.draw();
        }
    }

    for (self.animations.items) |object| {
        const animation = object.as(canvas.Animation);
        animation.drawElapsed(object.position, self.elapsed_time);
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
