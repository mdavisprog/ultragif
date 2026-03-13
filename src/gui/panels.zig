const clay = @import("clay");
const Container = @import("Container.zig");
const controls = @import("controls/root.zig");
const State = @import("State.zig");
const std = @import("std");

pub fn info(gui: *const Container) void {
    const file_name = if (gui.app.loaded_gif) |loaded_gif|
        std.fs.path.basename(loaded_gif.file_path)
    else
        "Drop file";

    title(gui._state, file_name);

    const disabled = gui.app.loaded_gif == null;
    const show_texture_text = if (gui.app.show_sprite_sheet)
        "Show Animation"
    else
        "Show Sprites";
    if (controls.button.label(
        gui._state,
        .fromLabel("ShowSpriteSheet_Button"),
        .init(show_texture_text),
        .{ .disabled = disabled },
    ) == .clicked) {
        gui.app.show_sprite_sheet = !gui.app.show_sprite_sheet;
    }

    const summary = gui._summary orelse return;
    controls.text.label(gui._state, summary.version, .{});
    controls.text.label(gui._state, summary.dimensions, .{});
    controls.text.label(gui._state, summary.frame_count, .{});
    controls.text.label(gui._state, summary.compressed_size, .{});
    controls.text.label(gui._state, summary.uncompressed_size, .{});
}

fn title(state: State, text: []const u8) void {
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
            },
            .child_alignment = .init(.center, .center),
        },
    });
    {
        controls.text.label(state, text, .{ .text_alignment = .center });
    }
    clay.closeElement();
}
