const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello UltraGIF!\n", .{});

    var heap = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = heap.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print(
            "Argument was not given. The .gif file to load must be given as the first argument.",
            .{},
        );
        return;
    }

    const path = args[1];
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    readGIF(&reader.interface) catch |err| {
        std.debug.print("Given file '{s}' is not a valid GIF. Error: {}", .{ path, err });
        return;
    };

    std.debug.print("Successfully loaded GIF file '{s}'.", .{path});
}

const Error = error{
    InvalidSignature,
};

fn readGIF(reader: *std.Io.Reader) !void {
    const signature = try reader.takeArray(6);
    if (!std.mem.eql(u8, signature, "GIF87a") and !std.mem.eql(u8, signature, "GIF89a")) {
        return Error.InvalidSignature;
    }
}
