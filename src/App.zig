const gif = @import("gif.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");

/// State of the application.
const Self = @This();

current_gif: ?*gif.Format = null,
sprite_sheet: ?*SpriteSheet = null,

pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.unloadGIF(allocator);

    if (self.sprite_sheet) |sheet| {
        sheet.deinit(allocator);
        allocator.destroy(sheet);
    }
}

pub fn loadGIF(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
    self.unloadGIF(allocator);
    self.unloadSpriteSheet(allocator);

    const loaded_gif = try gif.load(allocator, path);
    errdefer loaded_gif.deinit(allocator);

    const sprite_sheet = try SpriteSheet.init(allocator, loaded_gif);
    errdefer sprite_sheet.deinit(allocator);

    self.current_gif = try allocator.create(gif.Format);
    self.current_gif.?.* = loaded_gif;

    self.sprite_sheet = try allocator.create(SpriteSheet);
    self.sprite_sheet.?.* = sprite_sheet;

    std.debug.print("Successfully loaded GIF file '{s}'.\n", .{path});
}

fn unloadGIF(self: *Self, allocator: std.mem.Allocator) void {
    if (self.current_gif) |current_gif| {
        current_gif.deinit(allocator);
        allocator.destroy(current_gif);
        self.current_gif = null;
    }
}

fn unloadSpriteSheet(self: *Self, allocator: std.mem.Allocator) void {
    if (self.sprite_sheet) |sheet| {
        sheet.deinit(allocator);
        allocator.destroy(sheet);
        self.sprite_sheet = null;
    }
}
