pub fn initWindow(width: i32, height: i32, title: []const u8) void {
    InitWindow(@intCast(width), @intCast(height), title.ptr);
}

pub fn closeWindow() void {
    CloseWindow();
}

pub fn windowShouldClose() bool {
    return WindowShouldClose();
}

extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
extern fn CloseWindow() void;
extern fn WindowShouldClose() bool;
