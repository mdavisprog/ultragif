const std = @import("std");

pub const DestroyFunc = *const fn (closure: ?*anyopaque) void;
pub const Surface = anyopaque;

pub const Color = extern struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,

    pub fn init(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }
};

pub fn version() i32 {
    return @intCast(plutovg_version());
}

pub fn versionString() [*c]const u8 {
    const result = plutovg_version_string();
    return std.mem.span(result);
}

pub fn surfaceDestroy(surface: *Surface) void {
    plutovg_surface_destroy(surface);
}

pub fn surfaceGetData(surface: *const Surface) []const u8 {
    const stride = surfaceGetStride(surface);
    const height = surfaceGetHeight(surface);
    const len: usize = @intCast(stride * height);
    const data = plutovg_surface_get_data(surface);
    return data[0..len];
}

pub fn surfaceGetWidth(surface: *const Surface) i32 {
    return @intCast(plutovg_surface_get_width(surface));
}

pub fn surfaceGetHeight(surface: *const Surface) i32 {
    return @intCast(plutovg_surface_get_height(surface));
}

pub fn surfaceGetStride(surface: *const Surface) i32 {
    return @intCast(plutovg_surface_get_stride(surface));
}


extern fn plutovg_version() c_int;
extern fn plutovg_version_string() [*c]const u8;
extern fn plutovg_surface_destroy(surface: *Surface) void;
extern fn plutovg_surface_get_data(surface: *const Surface) [*c]const u8;
extern fn plutovg_surface_get_width(surface: *const Surface) c_int;
extern fn plutovg_surface_get_height(surface: *const Surface) c_int;
extern fn plutovg_surface_get_stride(surface: *const Surface) c_int;
