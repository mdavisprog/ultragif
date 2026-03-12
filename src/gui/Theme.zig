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
    button_disabled: clay.Color = .initu8(133, 122, 106, 255),
    text: clay.Color = .initu8(235, 235, 235, 255),
    text_disabled: clay.Color = .initu8(180, 180, 180, 255),
};

pub const Icons = struct {
    const svgs = struct {
        const camera = @embedFile("../assets/icons/camera.svg");
    };

    camera: raylib.Texture2D = .{},

    fn init() !Icons {
        return .{
            .camera = try loadSVG(svgs.camera, 24.0, 24.0),
        };
    }

    fn deinit(self: Icons) void {
        raylib.unloadTexture(self.camera);
    }

    fn loadSVG(svg: []const u8, width: f32, height: f32) !raylib.Texture2D {
        const document = plutosvg.documentLoadFromData(svg, width, height, null, null) orelse {
            return Error.IconLoadFailed;
        };
        defer plutosvg.documentDestroy(document);

        const surface = plutosvg.documentRenderToSurface(
            document,
            null,
            @intFromFloat(width),
            @intFromFloat(height),
            null,
            null,
            null,
        ) orelse {
            return Error.IconLoadFailed;
        };
        defer plutosvg.plutovg.surfaceDestroy(surface);

        const data = plutosvg.plutovg.surfaceGetData(surface);
        return raylib.loadTextureFromImage(.init(
            @ptrCast(@constCast(data)),
            @intFromFloat(width),
            @intFromFloat(height),
            .uncompressed_r8g8b8a8,
        ));
    }
};

/// Manages colors, constants, and icons used for this theme.
const Self = @This();

colors: Colors = .{},
icons: Icons = .{},

pub fn init() !Self {
    return .{
        .icons = try .init(),
    };
}

pub fn deinit(self: Self) void {
    self.icons.deinit();
}
