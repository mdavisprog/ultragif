const raylib = @import("raylib");
const std = @import("std");

pub const options: std.Options = .{
    .logFn = onLog,
};

pub fn init(_write_to_stdout: bool) void {
    raylib.setTraceLogCallback(onTraceLog);
    write_to_stdout = _write_to_stdout;
}

fn onLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;

    if (!write_to_stdout) {
        return;
    }

    var buffer: [1024]u8 = undefined;
    var std_out = std.fs.File.stdout().writer(&buffer);

    write(&std_out.interface, format, args);
    write(&std_out.interface, "\n", .{});

    std_out.interface.flush() catch |err| {
        std.debug.panic("Failed to flush stdout. Error: {}", .{err});
    };
}

fn write(writer: *std.Io.Writer, comptime format: []const u8, args: anytype) void {
    writer.print(format, args) catch |err| {
        std.debug.panic("Failed to write to stdout. Error: {}", .{err});
    };
}

fn onTraceLog(log_level: raylib.TraceLogLevel, text: []const u8) void {
    std.log.info("{s}: {s}", .{ logLevel(log_level), text });
}

fn logLevel(log_level: raylib.TraceLogLevel) []const u8 {
    return switch (log_level) {
        .trace => "TRACE",
        .debug => "DEBUG",
        .info => "INFO",
        .warning => "WARN",
        .error_ => "ERROR",
        .fatal => "FATAL",
        else => "",
    };
}

var write_to_stdout: bool = true;
