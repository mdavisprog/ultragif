pub const Vector2 = extern struct {
    pub const zero: Vector2 = .init(0.0, 0.0);

    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn init(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: Vector2, value: Vector2) Vector2 {
        return .{ .x = self.x + value.x, .y = self.y + value.y };
    }

    pub fn addMut(self: *Vector2, value: Vector2) void {
        self.x += value.x;
        self.y += value.y;
    }

    pub fn sub(self: Vector2, value: Vector2) Vector2 {
        return .{ .x = self.x - value.x, .y = self.y - value.y };
    }

    pub fn subMut(self: *Vector2, value: Vector2) void {
        self.x -= value.x;
        self.y -= value.y;
    }

    pub fn scale(self: Vector2, value: f32) Vector2 {
        return .{ .x = self.x * value, .y = self.y * value };
    }
};

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

pub const Rectangle = extern struct {
    pub const zero: Rectangle = .init(0.0, 0.0, 0.0, 0.0);

    x: f32 = 0.0,
    y: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }
};

pub const Image = extern struct {
    data: *anyopaque,
    width: i32 = 0,
    height: i32 = 0,
    mipmaps: i32 = 1,
    format: i32 = 0,

    pub fn init(data: *anyopaque, width: i32, height: i32, format: PixelFormat) Image {
        return .{
            .data = data,
            .width = width,
            .height = height,
            .format = @intFromEnum(format),
        };
    }
};

pub const Texture = extern struct {
    id: u32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    mipmaps: i32 = 1,
    format: i32 = 0,
};
pub const Texture2D = Texture;

pub const Camera2D = extern struct {
    offset: Vector2 = .zero,
    target: Vector2 = .zero,
    rotation: f32 = 0.0,
    zoom: f32 = 1.0,
};

pub const KeyboardKey = enum(u16) {
    null = 0,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    zero = 48,
    one = 49,
    two = 50,
    three = 51,
    four = 52,
    five = 53,
    six = 54,
    seven = 55,
    eight = 56,
    nine = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    left_bracket = 91,
    backslash = 92,
    right_bracket = 93,
    grave = 96,
    space = 32,
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    kb_menu = 348,
    kp_0 = 320,
    kp_1 = 321,
    kp_2 = 322,
    kp_3 = 323,
    kp_4 = 324,
    kp_5 = 325,
    kp_6 = 326,
    kp_7 = 327,
    kp_8 = 328,
    kp_9 = 329,
    kp_decimal = 330,
    kp_divide = 331,
    kp_multiply = 332,
    kp_subtract = 333,
    kp_add = 334,
    kp_enter = 335,
    kp_equal = 336,
    back = 4,
    menu = 5,
    volume_up = 24,
    volume_down = 25,
};

pub const MouseButton = enum(u8) {
    left = 0,
    right = 1,
    middle = 2,
    side = 3,
    extra = 4,
    forward = 5,
    back = 6,
};

pub const MouseCursor = enum(u8) {
    default = 0,
    arrow = 1,
    ibeam = 2,
    crosshair = 3,
    pointing_hand = 4,
    resize_ew = 5,
    resize_ns = 6,
    resize_nwse = 7,
    resize_nesw = 8,
    resize_all = 9,
    not_allowed = 10,
};

pub const PixelFormat = enum(u8) {
    uncompressed_grayscale = 1,
    uncompressed_gray_alpha,
    uncompressed_r5g6b5,
    uncompressed_r8g8b8,
    uncompressed_r5g5b5a1,
    uncompressed_r4g4b4a4,
    uncompressed_r8g8b8a8,
    uncompressed_r32,
    uncompressed_r32g32b32,
    uncompressed_r32g32b32a32,
    uncompressed_r16,
    uncompressed_r16g16b16,
    uncompressed_r16g16b16a16,
    compressed_dxt1_rgb,
    compressed_dxt1_rgba,
    compressed_dxt3_rgba,
    compressed_dxt5_rgba,
    compressed_etc1_rgb,
    compressed_etc2_rgb,
    compressed_etc2_eac_rgba,
    compressed_pvrt_rgb,
    compressed_pvrt_rgba,
    compressed_astc_4x4_rgba,
    compressed_astc_8x8_rgba,
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

pub fn showCursor() void {
    ShowCursor();
}

pub fn hideCursor() void {
    HideCursor();
}

pub fn isCursorHidden() bool {
    return IsCursorHidden();
}

pub fn enableCursor() void {
    EnableCursor();
}

pub fn disableCursor() void {
    DisableCursor();
}

pub fn isCursorOnScreen() bool {
    return IsCursorOnScreen();
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

pub fn beginMode2D(camera: Camera2D) void {
    BeginMode2D(camera);
}

pub fn endMode2D() void {
    EndMode2D();
}

pub fn getWorldToScreen2D(position: Vector2, camera: Camera2D) Vector2 {
    return GetWorldToScreen2D(position, camera);
}

pub fn getScreenToWorld2D(position: Vector2, camera: Camera2D) Vector2 {
    return GetScreenToWorld2D(position, camera);
}

pub fn setTargetFPS(fps: c_int) void {
    SetTargetFPS(@intCast(fps));
}

pub fn getFrameTime() f32 {
    return GetFrameTime();
}

pub fn getTime() f64 {
    return GetTime();
}

pub fn getFPS() c_int {
    return GetFPS();
}

pub fn isKeyPressed(key: KeyboardKey) bool {
    return IsKeyPressed(@intFromEnum(key));
}

pub fn isKeyPressedRepeat(key: KeyboardKey) bool {
    return IsKeyPressedRepeat(@intFromEnum(key));
}

pub fn isKeyDown(key: KeyboardKey) bool {
    return IsKeyDown(@intFromEnum(key));
}

pub fn isKeyReleased(key: KeyboardKey) bool {
    return IsKeyReleased(@intFromEnum(key));
}

pub fn isKeyUp(key: KeyboardKey) bool {
    return IsKeyUp(@intFromEnum(key));
}

pub fn getKeyPressed() KeyboardKey {
    return @enumFromInt(GetKeyPressed());
}

pub fn getCharPressed() i32 {
    return @intCast(GetCharPressed());
}

pub fn setExitKey(key: KeyboardKey) void {
    SetExitKey(@intFromEnum(key));
}

pub fn isMouseButtonPressed(button: MouseButton) bool {
    return IsMouseButtonPressed(@intFromEnum(button));
}

pub fn isMouseButtonDown(button: MouseButton) bool {
    return IsMouseButtonDown(@intFromEnum(button));
}

pub fn isMouseButtonReleased(button: MouseButton) bool {
    return IsMouseButtonReleased(@intFromEnum(button));
}

pub fn isMouseButtonUp(button: MouseButton) bool {
    return IsMouseButtonUp(@intFromEnum(button));
}

pub fn getMouseX() i32 {
    return @intCast(GetMouseX());
}
pub fn getMouseY() i32 {
    return @intCast(GetMouseY());
}

pub fn getMousePosition() Vector2 {
    return GetMousePosition();
}
pub fn getMouseDelta() Vector2 {
    return GetMouseDelta();
}

pub fn setMousePosition(x: i32, y: i32) void {
    SetMousePosition(@intCast(x), @intCast(y));
}

pub fn setMouseOffset(offset_x: i32, offset_y: i32) void {
    SetMouseOffset(@intCast(offset_x), @intCast(offset_y));
}

pub fn setMouseScale(scale_x: f32, scale_y: f32) void {
    SetMouseScale(scale_x, scale_y);
}

pub fn getMouseWheelMove() f32 {
    return GetMouseWheelMove();
}

pub fn getMouseWheelMoveV() Vector2 {
    return GetMouseWheelMoveV();
}

pub fn setMouseCursor(cursor: MouseCursor) void {
    SetMouseCursor(@intFromEnum(cursor));
}

pub fn drawRectangleV(position: Vector2, size: Vector2, color: Color) void {
    DrawRectangleV(position, size, color);
}

pub fn loadTextureFromImage(image: Image) Texture2D {
    return LoadTextureFromImage(image);
}

pub fn isTextureValid(texture: Texture2D) bool {
    return IsTextureValid(texture);
}

pub fn unloadTexture(texture: Texture2D) void {
    UnloadTexture(texture);
}

pub fn drawTextureV(texture: Texture2D, position: Vector2, tint: Color) void {
    DrawTextureV(texture, position, tint);
}

pub fn drawTexturePro(texture: Texture2D, source: Rectangle, dest: Rectangle, origin: Vector2, rotation: f32, tint: Color) void {
    DrawTexturePro(texture, source, dest, origin, rotation, tint);
}

extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
extern fn CloseWindow() void;
extern fn WindowShouldClose() bool;

extern fn ShowCursor() void;
extern fn HideCursor() void;
extern fn IsCursorHidden() bool;
extern fn EnableCursor() void;
extern fn DisableCursor() void;
extern fn IsCursorOnScreen() bool;

extern fn ClearBackground(color: Color) void;
extern fn BeginDrawing() void;
extern fn EndDrawing() void;
extern fn BeginMode2D(camera: Camera2D) void;
extern fn EndMode2D() void;

extern fn GetWorldToScreen2D(position: Vector2, camera: Camera2D) Vector2;
extern fn GetScreenToWorld2D(position: Vector2, camera: Camera2D) Vector2;

extern fn SetTargetFPS(fps: c_int) void;
extern fn GetFrameTime() f32;
extern fn GetTime() f64;
extern fn GetFPS() c_int;

extern fn IsKeyPressed(key: c_int) bool;
extern fn IsKeyPressedRepeat(key: c_int) bool;
extern fn IsKeyDown(key: c_int) bool;
extern fn IsKeyReleased(key: c_int) bool;
extern fn IsKeyUp(key: c_int) bool;
extern fn GetKeyPressed() c_int;
extern fn GetCharPressed() c_int;
extern fn SetExitKey(key: c_int) void;

extern fn IsMouseButtonPressed(button: c_int) bool;
extern fn IsMouseButtonDown(button: c_int) bool;
extern fn IsMouseButtonReleased(button: c_int) bool;
extern fn IsMouseButtonUp(button: c_int) bool;
extern fn GetMouseX() c_int;
extern fn GetMouseY() c_int;
extern fn GetMousePosition() Vector2;
extern fn GetMouseDelta() Vector2;
extern fn SetMousePosition(x: c_int, y: c_int) void;
extern fn SetMouseOffset(offset_x: c_int, offset_y: c_int) void;
extern fn SetMouseScale(scale_x: f32, scale_y: f32) void;
extern fn GetMouseWheelMove() f32;
extern fn GetMouseWheelMoveV() Vector2;
extern fn SetMouseCursor(cursor: c_int) void;

extern fn DrawRectangleV(position: Vector2, size: Vector2, color: Color) void;

extern fn LoadTextureFromImage(image: Image) Texture2D;
extern fn IsTextureValid(texture: Texture2D) bool;
extern fn UnloadTexture(texture: Texture2D) void;

extern fn DrawTextureV(texture: Texture2D, position: Vector2, tint: Color) void;
extern fn DrawTexturePro(texture: Texture2D, source: Rectangle, dest: Rectangle, origin: Vector2, rotation: f32, tint: Color) void;
