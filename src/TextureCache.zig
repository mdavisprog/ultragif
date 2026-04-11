const gif = @import("gif.zig");
const SpriteSheet = @import("SpriteSheet.zig");
const std = @import("std");

pub const Texture = struct {
    path: []const u8,
    sheet: SpriteSheet,

    pub fn name(self: Texture) []const u8 {
        return std.fs.path.stem(self.path);
    }
};

/// Stores all loaded sprite sheets.
const Self = @This();

textures: std.StringHashMapUnmanaged(*Texture) = .empty,

pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    var it = self.textures.valueIterator();
    while (it.next()) |texture| {
        destroyTexture(allocator, texture.*);
    }
    self.textures.deinit(allocator);
}

pub fn loadGIF(self: *Self, allocator: std.mem.Allocator, path: []const u8) !*Texture {
    if (self.textures.get(path)) |texture| {
        return texture;
    }

    const format = try gif.load(allocator, path);
    defer format.deinit(allocator);

    const sheet: SpriteSheet = try .init(allocator, format);
    errdefer sheet.deinit(allocator);

    const texture = try allocator.create(Texture);
    errdefer allocator.destroy(texture);

    texture.* = .{
        .path = try allocator.dupe(u8, path),
        .sheet = sheet,
    };

    try self.textures.put(allocator, texture.path, texture);
    std.log.info("Successfully loaded GIF '{s}.", .{path});

    return texture;
}

pub fn unload(self: *Self, allocator: std.mem.Allocator, path: []const u8) bool {
    const texture = self.textures.get(path) orelse return false;
    _ = self.textures.remove(path);
    destroyTexture(allocator, texture);
    return true;
}

fn destroyTexture(allocator: std.mem.Allocator, texture: *Texture) void {
    texture.sheet.deinit(allocator);
    allocator.free(texture.path);
    allocator.destroy(texture);
}
