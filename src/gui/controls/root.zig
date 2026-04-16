pub const button = @import("button.zig");
pub const handle = @import("handle.zig");
pub const image = @import("image.zig");
pub const input = @import("input.zig");
pub const list = @import("list.zig");
pub const separator = @import("separator.zig");
const std = @import("std");
pub const text = @import("text.zig");

pub const Type = enum {
    input,
};

pub const Data = union(Type) {
    input: input.Data,

    pub fn deinit(self: *Data, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .input => |*data| {
                data.deinit(allocator);
            },
        }
    }
};
