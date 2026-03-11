const raylib = @import("raylib");

pub const mouse = struct {
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
