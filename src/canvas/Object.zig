const raylib = @import("raylib");
const std = @import("std");

/// Dynamic dispatch of functions.
const VTable = struct {
    draw: *const fn (*anyopaque, raylib.Vector2) void,
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
            .draw = @ptrCast(&@field(Impl, "draw")),
            .dtor = @ptrCast(&@field(ImplDestructor, "dtor")),
        },
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    self.vtable.dtor(self.ptr, allocator);
}

pub fn draw(self: Self) void {
    self.vtable.draw(self.ptr, self.position);
}

fn Destructor(comptime T: type) type {
    return struct {
        fn dtor(self: *T, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }
    };
}
