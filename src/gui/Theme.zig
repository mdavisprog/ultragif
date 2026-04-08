const clay = @import("clay");
const plutosvg = @import("plutosvg");
const raylib = @import("raylib");
const std = @import("std");

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
    separator: clay.Color = .initu8(57, 62, 70, 255),
};

pub const Constants = struct {
    button_corner_radius: f32 = 0.25,
    separator_horizontal_size: f32 = 4.0,
    separator_vertical_size: f32 = 6.0,
};

pub const Icon = enum(u16) {
    animated_images,
    camera,
    circle,
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
        .{ .icon = .camera, .data = @embedFile("../assets/icons/camera.svg") },
        .{ .icon = .circle, .data = @embedFile("../assets/icons/circle.svg") },
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

    fn loadSVG(allocator: std.mem.Allocator, svg: []const u8, _width: f32, _height: f32,) !*raylib.Texture2D {
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

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .icons = try .init(allocator),
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    self.icons.deinit(allocator);
}

pub fn getIcon(self: Self, icon: Icon) *raylib.Texture2D {
    return self.icons.textures[@intFromEnum(icon)];
}
