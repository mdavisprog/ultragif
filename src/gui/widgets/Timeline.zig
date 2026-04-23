const canvas = @import("../../canvas/root.zig");
const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("../../SpriteSheet.zig");
const State = @import("../State.zig");
const std = @import("std");

const id: clay.ElementId = .fromLabel("Timeline");
const view_id: clay.ElementId = .fromLabel("TimelineView");
const delay_input_id: clay.ElementId = .fromLabel("DelayInput");
const segment_gap: f32 = 2.0;
const segment_time: f32 = 0.01;
const length_per_segment: f32 = 10.0;

/// Editor to manage frames from all loaded GIFs.
const Self = @This();

selected_animation: ?*canvas.Animation = null,
selected_frame: usize = 0,

pub fn draw(self: *Self, container: *Container) void {
    // Main container for timeline widget.
    clay.openElement();
    clay.configureOpenElement(.{
        .id = id,
        .background_color = container.state.theme.colors.background,
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .fixed(200.0),
            },
            .layout_direction = .top_to_bottom,
            .padding = .axes(4, 2),
        },
        .border = .{ .color = .black, .width = .{ .top = 1 } },
    });
    {
        self.drawTitleBar(&container.state);
        self.drawTimelineView(container);
    }
    clay.closeElement();
}

fn drawTitleBar(self: *Self, state: *State) void {
    const font_size: u16 = 20;

    // Horizontal bar for the title and other controls
    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
            },
            .child_alignment = .{
                .y = .center,
            },
            .child_gap = 6,
            .padding = .axes(2, 4),
        },
        .border = .{
            .color = .black,
            .width = .{ .bottom = 1 },
        },
    });
    {
        controls.text.label(state.*, "Timeline", .{ .font_size = font_size });
        controls.separator.vertical(state.*, .{ .padding = 1 });
        controls.text.label(state.*, "Delay", .{ .font_size = font_size });
        const confirmed = controls.input.text(state, delay_input_id, .{
            .width = .fixed(100.0),
            .format = .numbers,
        });

        if (confirmed) {
            if (controls.input.getContents(state.*, delay_input_id)) |contents| {
                if (std.fmt.parseFloat(f32, contents)) |delay| {
                    self.setSelectedDelay(delay);
                } else |_| {}
            }
        }
    }
    clay.closeElement();
}

fn drawTimelineView(self: *Self, container: *Container) void {
    clay.openElement();
    clay.configureOpenElement(.{
        .id = view_id,
        .layout = .{
            .sizing = .{
                .width = .percent(1.0),
                .height = .grow(0.0, 0.0),
            },
            .layout_direction = .top_to_bottom,
            .child_gap = 4,
        },
        .clip = .init(true, true, clay.getScrollOffset()),
    });
    {
        self.drawTimelines(container);

        controls.scroll.bars(&container.state, view_id, .both);
    }
    clay.closeElement();
}

fn drawTimelines(self: *Self, container: *Container) void {
    const canvas_scene = container.app.canvas_scene;
    const arena = container.state.getArenaAllocator();
    const objects = canvas_scene.getObjects(arena, canvas.Animation) catch |err| {
        std.debug.panic("Failed to retrieve animations from canvas: {}", .{err});
    };

    for (objects) |object| {
        // Container for all timeline segments.
        clay.openElement();
        clay.configureOpenElement(.{
            .layout = .{
                .sizing = .{
                    .width = .grow(0.0, 0.0),
                    .height = .fixed(10),
                },
                .child_gap = @intFromFloat(segment_gap),
            },
        });
        {
            const animation = object.as(canvas.Animation);
            self.drawTimeline(container, animation);
        }
        clay.closeElement();
    }
}

fn drawTimeline(self: *Self, container: *Container, animation: *canvas.Animation) void {
    for (animation.texture.sheet.frames, 0..) |frame, i| {
        self.drawFrame(container, frame, i, animation);
    }
}

fn drawFrame(
    self: *Self,
    container: *Container,
    frame: SpriteSheet.Frame,
    index: usize,
    animation: *canvas.Animation,
) void {
    const segments = frame.delay / segment_time;

    clay.openElement();

    const border_color: clay.Color = if (clay.hovered() or self.isFrameSelected(animation, index))
        .initu8(255, 255, 0, 255)
    else
        .black;

    if (clay.hovered()) {
        if (raylib.isMouseButtonPressed(.left)) {
            self.selected_animation = animation;
            self.selected_frame = index;

            const contents = std.fmt.allocPrint(
                container.state.getArenaAllocator(),
                "{}",
                .{frame.delay},
            ) catch |err| {
                std.debug.panic("Failed to convert delay to string: {}", .{err});
            };

            controls.input.setContents(container.state, delay_input_id, contents);
        }
    }

    clay.configureOpenElement(.{
        .background_color = .initu8(190, 10, 10, 255),
        .layout = .{
            .sizing = .{
                .width = .fixed(segments * length_per_segment),
                .height = .percent(1.0),
            },
        },
        .border = .{
            .color = border_color,
            .width = .axes(1, 1),
        },
    });
    clay.closeElement();
}

fn isSelected(self: Self, animation: *const canvas.Animation) bool {
    const selected = self.selected_animation orelse return false;
    return selected == animation;
}

fn isFrameSelected(self: Self, animation: *const canvas.Animation, index: usize) bool {
    return self.isSelected(animation) and self.selected_frame == index;
}

fn setSelectedDelay(self: Self, delay: f32) void {
    const animation = self.selected_animation orelse return;
    animation.texture.sheet.frames[self.selected_frame].delay = delay;
}
