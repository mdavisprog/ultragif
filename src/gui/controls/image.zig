const clay = @import("clay");
const raylib = @import("raylib");
const State = @import("../State.zig");

pub fn tint(
    state: State,
    texture: *raylib.Texture2D,
    color: clay.Color,
) void {
    _ = state;

    const width: f32 = @floatFromInt(texture.width);
    const height: f32 = @floatFromInt(texture.height);

    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .fixed(width, height),
        },
        .image = .{
            .image_data = texture,
        },
        .background_color = color,
    });
    clay.closeElement();
}
