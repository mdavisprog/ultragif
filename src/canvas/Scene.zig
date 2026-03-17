const Camera = @import("../Camera.zig");
const canvas = @import("root.zig");
const raylib = @import("raylib");
const std = @import("std");

/// Holds all objects contained within the Canvas.
const Self = @This();

camera: Camera = .{},
objects: std.ArrayListUnmanaged(canvas.Object) = .empty,

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (self.objects.items) |object| {
        object.deinit(allocator);
    }
    self.objects.deinit(allocator);
}

pub fn addShape(
    self: *Self,
    allocator: std.mem.Allocator,
    shape: canvas.Shape.Data,
    color: raylib.Color,
) !*canvas.Shape {
    const _shape = try allocator.create(canvas.Shape);
    _shape.* = .init(shape);
    _shape.color = color;

    const object: canvas.Object = .init(_shape);
    try self.objects.append(allocator, object);

    return _shape;
}

pub fn draw(self: Self) void {
    self.camera.begin();
    defer self.camera.end();

    raylib.clearBackground(.darkgray);
    for (self.objects.items) |object| {
        object.draw();
    }
}
