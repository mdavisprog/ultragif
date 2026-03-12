pub const plutovg = @import("plutovg.zig");
const std = @import("std");

pub const PaletteFunc = *const fn (
    closure: ?*anyopaque,
    name: [*c]const u8,
    length: c_int,
    color: *plutovg.Color,
) bool;
pub const Document = anyopaque;

pub fn version() i32 {
    return @intCast(plutosvg_version());
}

pub fn versionString() []const u8 {
    const result = plutosvg_version_string();
    return std.mem.span(result);
}

pub fn documentLoadFromData(
    data: []const u8,
    width: f32,
    height: f32,
    destroy_func: ?plutovg.DestroyFunc,
    closure: ?*anyopaque,
) ?*Document {
    return plutosvg_document_load_from_data(
        data.ptr,
        @intCast(data.len),
        width,
        height,
        destroy_func,
        closure,
    );
}

pub fn documentRenderToSurface(
    document: *Document,
    id: ?[]const u8,
    width: i32,
    height: i32,
    current_color: ?*plutovg.Color,
    palette_func: ?PaletteFunc,
    closure: ?*anyopaque,
) ?*plutovg.Surface {
    return plutosvg_document_render_to_surface(
        document,
        if (id) |_id| _id.ptr else null,
        @intCast(width),
        @intCast(height),
        current_color,
        palette_func,
        closure,
    );
}

pub fn documentDestroy(document: *Document) void {
    plutosvg_document_destroy(document);
}

extern fn plutosvg_version() c_int;
extern fn plutosvg_version_string() [*c]const u8;
extern fn plutosvg_document_load_from_data(
    data: [*c]const u8,
    length: c_int,
    width: f32,
    height: f32,
    destroy_func: ?plutovg.DestroyFunc,
    closure: ?*anyopaque,
) ?*Document;
extern fn plutosvg_document_render_to_surface(
    document: *Document,
    id: [*c]const u8,
    width: c_int,
    height: c_int,
    current_color: ?*plutovg.Color,
    palette_func: ?PaletteFunc,
    closure: ?*anyopaque,
) ?*plutovg.Surface;
extern fn plutosvg_document_destroy(document: *Document) void;
