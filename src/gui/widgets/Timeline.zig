const canvas = @import("../../canvas/root.zig");
const clay = @import("clay");
const Container = @import("../Container.zig");
const controls = @import("../controls/root.zig");
const input = @import("../../input.zig");
const raylib = @import("raylib");
const SpriteSheet = @import("../../SpriteSheet.zig");
const State = @import("../State.zig");
const std = @import("std");

const Interaction = enum {
    none,
    scrubber,
    frames,
};

const timeline_id: clay.ElementId = .fromLabel("Timeline");
const view_id: clay.ElementId = .fromLabel("TimelineView");
const delay_input_id: clay.ElementId = .fromLabel("DelayInput");
const segment_gap: f32 = 2.0;
const segment_time: f32 = 0.01;
const length_per_segment: f32 = 10.0;

/// Editor to manage frames from all loaded GIFs.
const Self = @This();

selected_animation: ?*canvas.Animation = null,
selected_frame: usize = 0,
interaction: Interaction = .none,

pub fn draw(self: *Self, container: *Container) void {
    if (raylib.isMouseButtonReleased(.left)) {
        self.interaction = .none;
    }

    // Main container for timeline widget.
    clay.openElement();
    clay.configureOpenElement(.{
        .id = timeline_id,
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
        self.drawTitleBar(container);
        self.drawTimelineView(container);
    }
    clay.closeElement();
}

fn drawTitleBar(self: *Self, container: *Container) void {
    const state = &container.state;
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
            .child_gap = 12,
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

        drawControls(container);
        controls.separator.vertical(state.*, .{ .padding = 1 });

        controls.text.label(state.*, "Delay", .{ .font_size = font_size });
        const confirmed = controls.input.text(state, delay_input_id, .{
            .width = .fixed(100.0),
            .format = .numbers,
        });

        if (confirmed) {
            if (controls.input.getContents(state.*, delay_input_id)) |contents| {
                const trimmed = std.mem.trim(u8, contents, " ");
                if (std.fmt.parseFloat(f32, trimmed)) |delay| {
                    const clamped = @max(0.01, delay);
                    self.setSelectedDelay(clamped);
                    setDelayContents(container, clamped);
                } else |_| {}
            }
        }
    }
    clay.closeElement();
}

fn drawControls(container: *Container) void {
    const button_id: clay.ElementId = .fromLabel("PausePlayButton");

    clay.openElement();
    clay.configureOpenElement(.{
        .layout = .{
            .child_gap = 4,
        },
    });
    {
        const timeline_state = container.app.canvas_scene.timeline_state;
        const config: controls.button.Config = .{
            .layout = .{
                .sizing = .{ .width = .fit(0.0, 0.0) },
            },
        };

        const texture = switch (timeline_state) {
            .pause => container.state.theme.getIcon(.play),
            .play => container.state.theme.getIcon(.pause),
        };

        const result = controls.button.image(
            container.state,
            button_id,
            .{ .texture = texture },
            config,
        );

        if (result == .clicked) {
            container.app.canvas_scene.timeline_state = switch (timeline_state) {
                .pause => .play,
                .play => .pause,
            };
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
        self.drawScrubber(container);
        self.drawTimelines(container);

        controls.scroll.bars(&container.state, view_id, .both);
    }
    clay.closeElement();
}

fn drawScrubber(self: *Self, container: *Container) void {
    const scrubber_bg_id: clay.ElementId = .fromLabel("ScrubberBackground");
    const scrubber_id: clay.ElementId = .fromLabel("Scrubber");

    clay.openElement();
    clay.configureOpenElement(.{
        .id = scrubber_bg_id,
        .background_color = .initu8(32, 32, 32, 255),
        .layout = .{
            .sizing = .{
                .width = .grow(0.0, 0.0),
                .height = .fixed(20.0),
            },
        },
    });
    {
        const max_time = container.app.canvas_scene.getMaxTime();
        const max_offset = max_time / segment_time * length_per_segment;

        const hovered = clay.pointerOver(scrubber_bg_id) or clay.pointerOver(scrubber_id);
        if (hovered and raylib.isMouseButtonPressed(.left)) {
            self.interaction = .scrubber;
        }

        if (self.interaction == .scrubber) {
            const scroll_data = clay.getScrollContainerData(view_id);

            container.app.canvas_scene.timeline_state = .pause;
            const mouse_position = raylib.getMousePosition();

            const offset = mouse_position.x - scroll_data.scroll_position.*.x;
            const ratio: f32 = @min(offset / max_offset, 1.0);
            const elapsed_time = ratio * max_time;
            container.app.canvas_scene.elapsed_time = elapsed_time;
        }

        const elapsed_time = container.app.canvas_scene.elapsed_time;
        const arrow = container.state.theme.getIcon(.arrow_down);
        const half_width: f32 = @floatFromInt(@divTrunc(arrow.width, 2));
        const offset = (elapsed_time / max_time) * max_offset;

        clay.openElement();
        clay.configureOpenElement(.{
            .id = scrubber_id,
            .layout = .{
                .child_alignment = .{
                    .y = .center,
                },
            },
            .floating = .{
                .attach_to = .parent,
                .offset = .init(offset - half_width, 0.0),
            },
        });
        {
            controls.image.tint(
                container.state,
                container.state.theme.getIcon(.arrow_down),
                .white,
            );
        }
        clay.closeElement();
    }
    clay.closeElement();
}

fn drawTimelines(self: *Self, container: *Container) void {
    const canvas_scene = container.app.canvas_scene;
    const arena = container.state.getArenaAllocator();
    const objects = canvas_scene.getObjects(arena, canvas.Animation) catch |err| {
        std.debug.panic("Failed to retrieve animations from canvas: {}", .{err});
    };

    for (objects, 0..) |object, i| {
        // Container for all timeline segments.
        clay.openElement();
        clay.configureOpenElement(.{
            .layout = .{
                .sizing = .{
                    .width = .grow(0.0, 0.0),
                    .height = .fixed(10),
                },
            },
        });
        {
            const animation = object.as(canvas.Animation);
            self.drawTimeline(container, animation, i);
        }
        clay.closeElement();
    }
}

fn drawTimeline(self: *Self, container: *Container, animation: *canvas.Animation, index: usize) void {
    for (animation.frames, 0..) |frame, i| {
        const string = container.state.formatStringTemp("Animation_{}_Frame", .{index});
        self.drawFrame(container, frame, i, animation, .fromStringOffset(string, @intCast(i)));
    }
}

fn drawFrame(
    self: *Self,
    container: *Container,
    frame: SpriteSheet.Frame,
    index: usize,
    animation: *canvas.Animation,
    id: clay.ElementId,
) void {
    const segments = frame.delay / segment_time;

    clay.openElement();

    const border_color: clay.Color = blk: {
        const highlight_color: clay.Color = .initu8(255, 255, 0, 255);

        if (self.interaction == .frames) {
            input.mouse.setCursor(.resize_ew);
            break :blk if (self.isFrameSelected(animation, index)) highlight_color else .black;
        }

        if (clay.hovered() or self.isFrameSelected(animation, index)) {
            break :blk .initu8(255, 255, 0, 255);
        }

        break :blk .black;
    };

    if (clay.hovered()) {
        if (raylib.isMouseButtonPressed(.left)) {
            self.selected_animation = animation;
            self.selected_frame = index;
            setDelayContents(container, frame.delay);
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
    {
        const result = controls.handle.draggable(container.state, id, .{
            .attach_point = .right_top,
            .sizing = .fixed(length_per_segment, length_per_segment),
            .offset = .init(length_per_segment * -0.5, 0.0),
        });

        switch (result.interaction) {
            .hovering => {
                input.mouse.setCursor(.resize_ew);
            },
            .dragging => {
                self.interaction = .frames;
                self.selected_animation = animation;
                self.selected_frame = index;

                if (result.mouse_delta.x != 0.0) {
                    const delay = animation.frames[index].delay;
                    const delta = result.mouse_delta.x * (segment_time / length_per_segment);
                    animation.frames[index].delay = @max(delay + delta, 0.01);
                    setDelayContents(container, animation.frames[index].delay);
                }
            },
            else => {},
        }
    }
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
    animation.frames[self.selected_frame].delay = delay;
}

fn setDelayContents(container: *Container, delay: f32) void {
    const contents = std.fmt.allocPrint(
        container.state.getArenaAllocator(),
        "{d:6.2}",
        .{delay},
    ) catch |err| {
        std.debug.panic("Failed to convert delay to string: {}", .{err});
    };

    controls.input.setContents(container.state, delay_input_id, contents);
}
