const clay = @import("clay");
const std = @import("std");

/// Manages the GUI
const Self = @This();

_memory: []const u8,
_arena: clay.Arena,
_context: *clay.Context,

pub fn init(allocator: std.mem.Allocator) !Self {
    const min_size: usize = @intCast(clay.minMemorySize());
    const memory = try allocator.alloc(u8, min_size);
    const arena = clay.createArenaWithCapacityAndMemory(min_size, @ptrCast(memory));
    const context = clay.initialize(arena, .{}, .{
        .error_handler_function = onError,
    }) orelse {
        std.debug.panic("Failed to initialize Clay library!", .{});
    };

    return .{
        ._memory = memory,
        ._arena = arena,
        ._context = context,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    allocator.free(self._memory);
}

fn onError(err: clay.ErrorData) callconv(.c) void {
    std.log.warn("Clay error: {} '{s}'\n", .{ err.error_type, err.error_text.str() });
}
