pub const Color = extern struct {
    pub const lightgray: Color = .init(200, 200, 200, 255);
    pub const gray: Color = .init(130, 130, 130, 255);
    pub const darkgray: Color = .init(80, 80, 80, 255);
    pub const yellow: Color = .init(253, 249, 0, 255);
    pub const gold: Color = .init(255, 203, 0, 255);
    pub const orange: Color = .init(255, 161, 0, 255);
    pub const pink: Color = .init(255, 109, 194, 255);
    pub const red: Color = .init(230, 41, 55, 255);
    pub const maroon: Color = .init(190, 33, 55, 255);
    pub const green: Color = .init(0, 228, 48, 255);
    pub const lime: Color = .init(0, 158, 47, 255);
    pub const darkgreen: Color = .init(0, 117, 44, 255);
    pub const skyblue: Color = .init(102, 191, 255, 255);
    pub const blue: Color = .init(0, 121, 241, 255);
    pub const darkblue: Color = .init(0, 82, 172, 255);
    pub const purple: Color = .init(200, 122, 255, 255);
    pub const violet: Color = .init(135, 60, 190, 255);
    pub const darkpurple: Color = .init(112, 31, 126, 255);
    pub const beige: Color = .init(211, 176, 131, 255);
    pub const brown: Color = .init(127, 106, 79, 255);
    pub const darkbrown: Color = .init(76, 63, 47, 255);
    pub const white: Color = .init(255, 255, 255, 255);
    pub const black: Color = .init(0, 0, 0, 255);
    pub const blank: Color = .init(0, 0, 0, 0);
    pub const magenta: Color = .init(255, 0, 255, 255);
    pub const raywhite: Color = .init(245, 245, 245, 255);

    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
};

pub fn initWindow(width: i32, height: i32, title: []const u8) void {
    InitWindow(@intCast(width), @intCast(height), title.ptr);
}

pub fn closeWindow() void {
    CloseWindow();
}

pub fn windowShouldClose() bool {
    return WindowShouldClose();
}

pub fn clearBackground(color: Color) void {
    ClearBackground(color);
}

pub fn beginDrawing() void {
    BeginDrawing();
}

pub fn endDrawing() void {
    EndDrawing();
}

extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
extern fn CloseWindow() void;
extern fn WindowShouldClose() bool;

extern fn ClearBackground(color: Color) void;
extern fn BeginDrawing() void;
extern fn EndDrawing() void;
