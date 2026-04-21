const clay = @import("clay");
const controls = @import("root.zig");
const raylib = @import("raylib");
const State = @import("../State.zig");
const std = @import("std");

pub const Options = struct {
    default_text: ?[]const u8 = null,
};

pub const Data = struct {
    contents: std.ArrayListUnmanaged(u8) = .empty,
    cursor_pos: usize = 0,

    pub fn deinit(self: *Data, allocator: std.mem.Allocator) void {
        self.contents.deinit(allocator);
    }

    pub fn str(self: Data) []const u8 {
        return self.contents.items;
    }

    pub fn len(self: Data) usize {
        return self.contents.items.len;
    }

    pub fn setContents(self: *Data, allocator: std.mem.Allocator, contents: []const u8) void {
        self.contents.clearRetainingCapacity();
        self.contents.appendSlice(allocator, contents) catch |err| {
            std.debug.panic("Failed to set contents: {}", .{err});
        };
    }

    fn init(allocator: std.mem.Allocator, contents: []const u8) Data {
        var contents_: std.ArrayListUnmanaged(u8) = .empty;
        contents_.appendSlice(allocator, contents) catch |err| {
            std.debug.panic("Failed to create input data: {}", .{err});
        };
        return .{ .contents = contents_ };
    }

    fn moveCursorBack(self: *Data) void {
        self.cursor_pos -|= 1;
    }

    fn moveCursorForward(self: *Data) void {
        self.cursor_pos = std.math.clamp(self.cursor_pos + 1, 0, self.len());
    }

    fn moveCursorToStart(self: *Data) void {
        self.cursor_pos = 0;
    }

    fn moveCursorToEnd(self: *Data) void {
        self.cursor_pos = self.len();
    }

    fn deletePrevious(self: *Data) void {
        if (self.cursor_pos == 0) return;
        _ = self.contents.orderedRemove(self.cursor_pos - 1);
        self.cursor_pos -|= 1;
    }

    fn insert(self: *Data, allocator: std.mem.Allocator, contents: []const u8) void {
        self.contents.insertSlice(allocator, self.cursor_pos, contents) catch |err| {
            std.debug.panic("Failed to append contents: {}", .{err});
        };
        self.cursor_pos = std.math.clamp(self.cursor_pos + contents.len, 0, self.len());
    }

    fn cursorStr(self: Data) []const u8 {
        return self.contents.items[0..self.cursor_pos];
    }
};

pub fn text(state: *State, id: clay.ElementId, options: Options) void {
    const font_size = state.theme.constants.font_size;
    const height: f32 = @floatFromInt(font_size + 6);

    clay.openElement();

    const is_focused = state.isFocused(id);
    const background_color = if (clay.hovered() or is_focused)
        state.theme.colors.text_input_focused
    else
        state.theme.colors.text_input;

    clay.configureOpenElement(.{
        .id = id,
        .background_color = background_color,
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .fixed(height),
            },
            .child_alignment = .{
                .y = .center,
            },
        },
        .clip = .{
            .horizontal = true,
            .vertical = true,
        },
    });

    const data = state.getData(id) orelse state.addData(id, .{
        .input = .init(state.getAllocator(), options.default_text orelse ""),
    });

    if (is_focused) {
        const cursor_pos = data.input.cursor_pos;

        if (isKeyPressed(.left)) {
            data.input.moveCursorBack();
        }

        if (isKeyPressed(.right)) {
            data.input.moveCursorForward();
        }

        if (isKeyPressed(.backspace)) {
            data.input.deletePrevious();
        }

        if (raylib.isKeyPressed(.home)) {
            data.input.moveCursorToStart();
        }

        if (raylib.isKeyPressed(.end)) {
            data.input.moveCursorToEnd();
        }

        while (true) {
            const codepoint = raylib.getCharPressed();
            if (codepoint == 0) break;
            const utf8 = raylib.codepointToUTF8(codepoint);
            data.input.insert(state.getAllocator(), utf8);
        }

        if (cursor_pos != data.input.cursor_pos) {
            state.blinking_cursor.reset();
        }
    }

    const size = state.theme.measureText(data.input.cursorStr(), @floatFromInt(font_size), 0);
    controls.text.label(state.*, data.input.str(), .{ .font_size = font_size });

    if (is_focused) {
        const cursor_color: clay.Color = if (state.blinking_cursor.on)
            state.theme.colors.text
        else
            .blank;

        clay.openElement();
        clay.configureOpenElement(.{
            .background_color = cursor_color,
            .layout = .{
                .sizing = .fixed(2.0, height - 6.0),
            },
            .floating = .{
                .attach_to = .parent,
                .offset = .init(size.x, 3.0),
            },
        });
        clay.closeElement();
    }

    clay.closeElement();
}

fn isKeyPressed(key: raylib.KeyboardKey) bool {
    return raylib.isKeyPressed(key) or raylib.isKeyPressedRepeat(key);
}
