const std = @import("std");

/// The Header identifies the GIF Data Stream in context. The
/// Signature field marks the beginning of the Data Stream, and the Version
/// field identifies the set of capabilities required of a decoder to fully
/// process the Data Stream.  This block is REQUIRED; exactly one Header must
/// be present per Data Stream.
pub const Header = struct {
    signature: [3]u8,
    version: [3]u8,

    pub fn init(reader: *std.Io.Reader) !Header {
        const signature = try reader.take(3);
        const version = try reader.take(3);

        var result: Header = undefined;
        @memcpy(&result.signature, signature);
        @memcpy(&result.version, version);
        return result;
    }

    pub fn isValid(self: Header) bool {
        if (!std.mem.eql(u8, &self.signature, "GIF")) {
            return false;
        }

        if (!std.mem.eql(u8, &self.version, "87a") and !std.mem.eql(u8, &self.version, "89a")) {
            return false;
        }

        return true;
    }
};

/// Loads the GIF file at the given path. 'path' should be absolute.
pub fn load(path: []const u8) !bool {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    const header: Header = try .init(&reader.interface);
    if (!header.isValid()) {
        std.debug.print("Given file '{s}' is not a valid GIF.", .{path});
        return false;
    }

    return true;
}
