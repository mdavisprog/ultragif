const raylib = @import("raylib");
const std = @import("std");

pub fn init() void {
    raylib.setTraceLogCallback(onTraceLog);
}

fn onTraceLog(log_level: raylib.TraceLogLevel, text: []const u8) void {
    std.debug.print("{s}: {s}\n", .{ @tagName(log_level), text });
}
