const gif = @import("gif.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");

pub const LoadedGIF = struct {
    format: gif.Format,
    sprite_sheet: SpriteSheet,
    file_path: []const u8,
};

/// State of the application.
const Self = @This();

loaded_gif: ?LoadedGIF = null,
show_sprite_sheet: bool = false,

pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.unloadGIF(allocator);
}

pub fn loadGIF(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    self.unloadGIF(allocator);

    const format = try gif.load(allocator, path);
    errdefer format.deinit(allocator);

    const sprite_sheet = try SpriteSheet.init(allocator, format);
    errdefer sprite_sheet.deinit(allocator);

    self.loaded_gif = .{
        .format = format,
        .sprite_sheet = sprite_sheet,
        .file_path = try allocator.dupe(u8, path),
    };

    std.debug.print("Successfully loaded GIF file '{s}'.\n", .{path});
}

fn unloadGIF(self: *Self, allocator: std.mem.Allocator) void {
    if (self.loaded_gif) |loaded_gif| {
        loaded_gif.format.deinit(allocator);
        loaded_gif.sprite_sheet.deinit(allocator);
        allocator.free(loaded_gif.file_path);
    }
}
