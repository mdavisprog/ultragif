const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const std = @import("std");

pub const id: clay.ElementId = .fromLabel("StatusBar");

/// Represents a horizontal bar at the bottom of the application to notify user of any updates.
const Self = @This();

/// The current status string to display. This will hold a copy of the given status.
status: ?[]const u8 = null,

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (self.status) |status| {
        allocator.free(status);
    }
}

pub fn setStatus(
    self: *Self,
    allocator: std.mem.Allocator,
    comptime format: []const u8,
    args: anytype,
) !void {
    if (self.status) |current| {
        allocator.free(current);
    }

    self.status = try std.fmt.allocPrint(allocator, format, args);
}

pub fn draw(self: Self, container: *Container) void {
    const font_size = container.state.theme.constants.font_size;

    clay.openElement();
    clay.configureOpenElement(.{
        .background_color = container.state.theme.colors.background,
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .fixed(@floatFromInt(font_size + 6)),
            },
            .child_alignment = .{
                .y = .center,
            },
            .padding = .axes(4, 0),
        },
        .clip = .all(true),
        .border = .{ .color = .black, .width = .init(0, 0, 1, 0) },
    });
    {
        const status = self.status orelse "";
        controls.text.label(container.state, status, .{ .font_size = font_size });
    }
    clay.closeElement();
}
