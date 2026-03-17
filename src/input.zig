const raylib = @import("raylib");
const std = @import("std");

pub const mouse = struct {
    pub const State = struct {
        const button_count = @typeInfo(raylib.MouseButton).@"enum".fields.len;
        const ButtonFlags = std.StaticBitSet(button_count);

        position: raylib.Vector2 = .zero,
        pressed: ButtonFlags = .initEmpty(),
        released: ButtonFlags = .initEmpty(),
        down: ButtonFlags = .initEmpty(),
        wheel: raylib.Vector2 = .zero,

        pub fn current() State {
            var result: State = .{};

            for (0..button_count) |i| {
                const pressed = raylib.isMouseButtonPressed(@enumFromInt(i));
                const released = raylib.isMouseButtonReleased(@enumFromInt(i));
                const down = raylib.isMouseButtonDown(@enumFromInt(i));

                if (pressed) result.pressed.set(i);
                if (released) result.released.set(i);
                if (down) result.down.set(i);
            }

            result.wheel = raylib.getMouseWheelMoveV();

            return result;
        }

        pub fn invalid() State {
            const float_max = std.math.floatMax(f32);
            return .{
                .position = .init(float_max, float_max),
            };
        }

        pub fn isPressed(self: State, button: raylib.MouseButton) bool {
            return self.pressed.isSet(@intFromEnum(button));
        }

        pub fn isReleased(self: State, button: raylib.MouseButton) bool {
            return self.released.isSet(@intFromEnum(button));
        }

        pub fn isDown(self: State, button: raylib.MouseButton) bool {
            return self.down.isSet(@intFromEnum(button));
        }
    };

    /// Keep track of the current mouse cursor. Prevent trying to change the cursor to the same one.
    var _cursor: raylib.MouseCursor = .default;

    pub fn setCursor(cursor: raylib.MouseCursor) void {
        if (_cursor == cursor) {
            return;
        }

        _cursor = cursor;
        raylib.setMouseCursor(_cursor);
    }

    pub fn currentCursor() raylib.MouseCursor {
        return _cursor;
    }
};
