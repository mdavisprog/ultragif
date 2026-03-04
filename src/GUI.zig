const clay = @import("clay");
const raylib = @import("raylib");
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

pub fn draw(self: Self) void {
    clay.beginLayout();
    const commands = clay.endLayout();

    for (commands.slice()) |command| {
        self.processCommand(command);
    }
}

fn processCommand(self: Self, command: clay.RenderCommand) void {
    _ = self;

    const bbox = command.bounding_box;
    switch (command.command_type) {
        .rectangle => {
            const color = command.render_data.rectangle.background_color;
            raylib.drawRectangleV(
                .init(bbox.x, bbox.y),
                .init(bbox.width, bbox.height),
                toRaylibColor(color),
            );
        },
        else => {},
    }
}

fn onError(err: clay.ErrorData) callconv(.c) void {
    std.log.warn("Clay error: {} '{s}'\n", .{ err.error_type, err.error_text.str() });
}

fn toRaylibColor(color: clay.Color) raylib.Color {
    return .init(
        @intFromFloat(color.r),
        @intFromFloat(color.g),
        @intFromFloat(color.b),
        @intFromFloat(color.a),
    );
}
