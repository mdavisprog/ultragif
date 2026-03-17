const raylib = @import("raylib");
const std = @import("std");

/// Dynamic dispatch of functions.
const VTable = struct {
    update: *const fn (*anyopaque, f32) void,
    draw: *const fn (*anyopaque, raylib.Vector2) void,
    getSize: *const fn (*const anyopaque) raylib.Vector2,
    cleanup: ?*const fn (*anyopaque, std.mem.Allocator) void,
    /// This will be supplied internally. Implementations do not need to provide this.
    dtor: *const fn (*anyopaque, std.mem.Allocator) void,
};

/// Any object that is a part of the scene. An object can be translated and provides a vtable to
/// implement updating and drawing of the object.
const Self = @This();

ptr: *anyopaque,
vtable: VTable,
position: raylib.Vector2 = .zero,

/// This will take ownership of the given implementation.
pub fn init(impl: anytype) Self {
    const Impl = @typeInfo(@TypeOf(impl)).pointer.child;
    const ImplDestructor = Destructor(Impl);
    return .{
        .ptr = impl,
        .vtable = .{
            .update = @ptrCast(&@field(Impl, "update")),
            .draw = @ptrCast(&@field(Impl, "draw")),
            .getSize = @ptrCast(&@field(Impl, "getSize")),
            .cleanup = if (std.meta.hasFn(Impl, "cleanup")) @ptrCast(&@field(Impl, "cleanup")) else null,
            .dtor = @ptrCast(&@field(ImplDestructor, "dtor")),
        },
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (self.vtable.cleanup) |cleanup| {
        cleanup(self.ptr, allocator);
    }

    self.vtable.dtor(self.ptr, allocator);
}

pub fn update(self: Self, delta_time: f32) void {
    self.vtable.update(self.ptr, delta_time);
}

pub fn draw(self: Self) void {
    self.vtable.draw(self.ptr, self.position);
}

pub fn bounds(self: Self) raylib.Rectangle {
    const size = self.vtable.getSize(self.ptr);
    return .init(self.position.x, self.position.y, size.x, size.y);
}

fn Destructor(comptime T: type) type {
    return struct {
        fn dtor(self: *T, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }
    };
}
