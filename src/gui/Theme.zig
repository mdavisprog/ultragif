const clay = @import("clay");
const plutosvg = @import("plutosvg");
const raylib = @import("raylib");
const std = @import("std");

const roboto_regular = @embedFile("../assets/fonts/Roboto-Regular.ttf");
const sdf_fs = @embedFile("../assets/shaders/sdf.fs");

/// Non configurable constants
pub const z_index = struct {
    pub const handle: i16 = 2;
};

pub const Error = error{
    IconLoadFailed,
};

pub const Colors = struct {
    background: clay.Color = .initu8(34, 40, 49, 255),
    button_background: clay.Color = .initu8(148, 137, 121, 255),
    button_hovered: clay.Color = .initu8(160, 150, 134, 255),
    button_active: clay.Color = .initu8(130, 120, 106, 255),
    button_disabled: clay.Color = .initu8(110, 100, 86, 255),
    text: clay.Color = .initu8(235, 235, 235, 255),
    text_disabled: clay.Color = .initu8(180, 180, 180, 255),
    text_input: clay.Color = .initu8(67, 72, 80, 255),
    text_input_focused: clay.Color = .initu8(57, 62, 70, 255),
    separator: clay.Color = .initu8(57, 62, 70, 255),
};

pub const Constants = struct {
    font_size: u16 = 18,
    button_corner_radius: f32 = 0.25,
    separator_horizontal_size: f32 = 4.0,
    separator_vertical_size: f32 = 6.0,
    scroll_bar_size: f32 = 10.0,
    mouse_wheel_scroll_step: f32 = 8.0,
};

pub const Icon = enum(u16) {
    animated_images,
    arrow_down,
    camera,
    circle,
    export_,
    pause,
    play,
    texture,
};
const icon_count = @typeInfo(Icon).@"enum".fields.len;

pub const Icons = struct {
    const SVG = struct {
        icon: Icon,
        data: []const u8,
    };

    const svgs = [_]SVG{
        .{ .icon = .animated_images, .data = @embedFile("../assets/icons/animated_images.svg") },
        .{ .icon = .arrow_down, .data = @embedFile("../assets/icons/arrow_down.svg") },
        .{ .icon = .camera, .data = @embedFile("../assets/icons/camera.svg") },
        .{ .icon = .circle, .data = @embedFile("../assets/icons/circle.svg") },
        .{ .icon = .export_, .data = @embedFile("../assets/icons/export.svg") },
        .{ .icon = .pause, .data = @embedFile("../assets/icons/pause.svg") },
        .{ .icon = .play, .data = @embedFile("../assets/icons/play.svg") },
        .{ .icon = .texture, .data = @embedFile("../assets/icons/texture.svg") },
    };

    pub const width: f32 = 24.0;
    pub const height: f32 = 24.0;

    textures: [icon_count]*raylib.Texture2D,

    fn init(allocator: std.mem.Allocator) !Icons {
        var result: Icons = undefined;
        for (svgs) |svg| {
            result.textures[@intFromEnum(svg.icon)] = try loadSVG(allocator, svg.data, width, height);
        }
        return result;
    }

    fn deinit(self: Icons, allocator: std.mem.Allocator) void {
        for (self.textures) |texture| {
            destroy(allocator, texture);
        }
    }

    fn destroy(allocator: std.mem.Allocator, texture: *raylib.Texture2D) void {
        raylib.unloadTexture(texture.*);
        allocator.destroy(texture);
    }

    fn loadSVG(
        allocator: std.mem.Allocator,
        svg: []const u8,
        _width: f32,
        _height: f32,
    ) !*raylib.Texture2D {
        const document = plutosvg.documentLoadFromData(svg, _width, _height, null, null) orelse {
            return Error.IconLoadFailed;
        };
        defer plutosvg.documentDestroy(document);

        const surface = plutosvg.documentRenderToSurface(
            document,
            null,
            @intFromFloat(_width),
            @intFromFloat(_height),
            null,
            null,
            null,
        ) orelse {
            return Error.IconLoadFailed;
        };
        defer plutosvg.plutovg.surfaceDestroy(surface);

        const data = plutosvg.plutovg.surfaceGetData(surface);
        const result = try allocator.create(raylib.Texture2D);
        result.* = raylib.loadTextureFromImage(.init(
            @ptrCast(@constCast(data)),
            @intFromFloat(_width),
            @intFromFloat(_height),
            .uncompressed_r8g8b8a8,
        ));
        return result;
    }
};

/// Manages colors, constants, and icons used for this theme.
const Self = @This();

colors: Colors = .{},
constants: Constants = .{},
icons: Icons,
font: *raylib.Font,
font_shader: raylib.Shader,

pub fn init(allocator: std.mem.Allocator) !Self {
    const font = try loadFont(allocator);
    const font_shader = raylib.loadShaderFromMemory(null, sdf_fs);
    if (!raylib.isShaderValid(font_shader)) std.debug.panic("Failed to load font shader!", .{});
    return .{
        .icons = try .init(allocator),
        .font = font,
        .font_shader = font_shader,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    self.icons.deinit(allocator);

    raylib.unloadShader(self.font_shader);
    raylib.unloadFont(self.font.*);
    allocator.destroy(self.font);
}

pub fn getIcon(self: Self, icon: Icon) *raylib.Texture2D {
    return self.icons.textures[@intFromEnum(icon)];
}

pub fn measureText(
    self: Self,
    text: []const u8,
    font_size: f32,
    letter_spacing: u16,
) raylib.Vector2 {
    const scale_factor = font_size / @as(f32, @floatFromInt(self.font.base_size));

    var max_text_width: f32 = 0.0;
    var line_text_width: f32 = 0.0;
    var max_line_char_count: i32 = 0;
    var line_char_count: i32 = 0;

    for (0..text.len) |i| {
        defer line_char_count += 1;

        const ch = text[i];
        if (ch == '\n') {
            max_text_width = @max(max_text_width, line_text_width);
            max_line_char_count = @max(max_line_char_count, line_char_count);
            line_text_width = 0.0;
            line_char_count = 0;
            continue;
        }

        if (ch < 32) continue;

        const codepoint: usize = @intCast(ch - 32);
        const glyph = self.font.glyphs[codepoint];

        if (glyph.advance_x != 0) {
            line_text_width += @as(f32, @floatFromInt(glyph.advance_x));
        } else {
            line_text_width += self.font.recs[codepoint].width + @as(f32, @floatFromInt(glyph.offset_x));
        }
    }

    max_text_width = @max(max_text_width, line_text_width);
    max_line_char_count = @max(max_line_char_count, line_char_count);

    const scaled_letter_spacing: f32 = @floatFromInt(line_char_count * letter_spacing);
    return .init( max_text_width * scale_factor + scaled_letter_spacing, font_size);
}

fn loadFont(allocator: std.mem.Allocator) !*raylib.Font {
    const font_size: i32 = 32;
    const glyphs = raylib.loadFontData(
        roboto_regular,
        font_size,
        null,
        95,
        .sdf,
    );

    const font = try allocator.create(raylib.Font);
    font.* = .{
        .base_size = font_size,
        .glyphs = glyphs.ptr,
        .glyph_count = @intCast(glyphs.len),
    };

    const font_image = raylib.genImageFontAtlas(font.getGlyphs(), &font.recs, font_size, 0, 0);
    font.texture = raylib.loadTextureFromImage(font_image);
    raylib.setTextureFilter(font.texture, .bilinear);

    return font;
}
