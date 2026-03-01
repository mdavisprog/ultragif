pub const Vector2 = extern struct {
    pub const zero: Vector2 = .init(0.0, 0.0);

    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn init(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
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

pub fn drawRectangleV(position: Vector2, size: Vector2, color: Color) void {
    DrawRectangleV(position, size, color);
}

pub fn loadTextureFromImage(image: Image) Texture2D {
    return LoadTextureFromImage(image);
}

pub fn unloadTexture(texture: Texture2D) void {
    UnloadTexture(texture);
}

pub fn drawTextureV(texture: Texture2D, position: Vector2, tint: Color) void {
    DrawTextureV(texture, position, tint);
}

extern fn InitWindow(width: c_int, height: c_int, title: [*c]const u8) void;
extern fn CloseWindow() void;
extern fn WindowShouldClose() bool;

extern fn ClearBackground(color: Color) void;
extern fn BeginDrawing() void;
extern fn EndDrawing() void;
extern fn BeginMode2D(camera: Camera2D) void;
extern fn EndMode2D() void;

extern fn SetTargetFPS(fps: c_int) void;
extern fn GetFrameTime() f32;
extern fn GetTime() f64;
extern fn GetFPS() c_int;

extern fn DrawRectangleV(position: Vector2, size: Vector2, color: Color) void;

extern fn LoadTextureFromImage(image: Image) Texture2D;
extern fn UnloadTexture(texture: Texture2D) void;

extern fn DrawTextureV(texture: Texture2D, position: Vector2, tint: Color) void;
