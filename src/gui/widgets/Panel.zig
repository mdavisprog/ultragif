const canvas = @import("../../canvas/root.zig");
const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");
const units = @import("../../units.zig");

/// The right side panel containing information and tools for organizing/manipulating GIFs.
const Self = @This();

const id: clay.ElementId = .fromLabel("Panel");

texture_count: [24]u8 = @splat(0),
memory_text: [24]u8 = @splat(0),

pub fn draw(self: *Self, container: *const Container) void {
    // Main background panel
    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .layout = .{
            .sizing = .{
                .width = .grow(0.0, 0.0),
                .height = .percent(1.0),
            },
            .layout_direction = .top_to_bottom,
            .padding = .axes(4, 4),
            .child_gap = 4,
        },
        .background_color = container._state.theme.colors.background,
    });
    {
        self.drawTexturesInfo(container);
    }
    clay.closeElement();
}

pub fn bounds(_: Self) raylib.Rectangle {
    const element = clay.getElementData(id);
    if (!element.found) {
        return .zero;
    }

    return .init(
        element.bounding_box.x,
        element.bounding_box.y,
        element.bounding_box.width,
        element.bounding_box.height,
    );
}

fn drawInfo(container: *const Container) void {
    const file_name = if (container.app.loaded_gif) |loaded_gif|
        std.fs.path.basename(loaded_gif.file_path)
    else
        "Drop file";

    drawInfoTitle(container._state, file_name);

    const disabled = container.app.loaded_gif == null;
    const show_texture_text = if (container.app.show_sprite_sheet)
        "Show Animation"
    else
        "Show Sprites";
    if (controls.button.label(
        container._state,
        .fromLabel("ShowSpriteSheet_Button"),
        .init(show_texture_text),
        .{ .disabled = disabled },
    ) == .clicked) {
        container.app.show_sprite_sheet = !container.app.show_sprite_sheet;
    }

    const summary = container._summary orelse return;
    controls.text.label(container._state, summary.version, .{});
    controls.text.label(container._state, summary.dimensions, .{});
    controls.text.label(container._state, summary.frame_count, .{});
    controls.text.label(container._state, summary.compressed_size, .{});
    controls.text.label(container._state, summary.uncompressed_size, .{});
}

fn drawInfoTitle(state: State, text: []const u8) void {
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

fn drawTexturesInfo(self: *Self, container: *const Container) void {
    var bytes: usize = 0;
    var count: usize = 0;
    var textures = container.app.texture_cache.textures.valueIterator();
    while (textures.next()) |texture| {
        bytes += texture.*.sheet.memorySize();
        count += 1;
    }

    const memory: units.Memory = .fromBytes(bytes);
    copyText(&self.texture_count, "Count: {}", .{count});
    copyText(&self.memory_text, "Memory: {} {s}", .{ memory.amount, memory.symbolString() });

    controls.text.label(container._state, &self.texture_count, .{});
    controls.text.label(container._state, &self.memory_text, .{});
}

fn copyText(buffer: []u8, comptime format: []const u8, args: anytype) void {
    @memset(buffer, 0);
    _ = std.fmt.bufPrint(buffer, format, args) catch {
        std.debug.panic("Buffer too small.", .{});
    };
}
