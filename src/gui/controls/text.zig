const clay = @import("clay");
const State = @import("../State.zig");

/// Mirrors clay.TextElementConfig with optional values.
pub const Config = struct {
    text_color: ?clay.Color = null,
    font_size: ?u16 = null,
    wrap_mode: ?clay.TextElementConfigWrapMode = null,
    text_alignment: ?clay.TextAlignment = null,
    disabled: bool = false,
};

/// Text control
pub fn label(state: State, text: []const u8, config: Config) void {
    const text_color = config.text_color orelse if (config.disabled)
        state.theme.colors.text_disabled
    else
        state.theme.colors.text;

    const element_config = clay.storeTextElementConfig(.{
        .text_color = text_color,
        .font_size = config.font_size orelse 24,
        .wrap_mode = config.wrap_mode orelse .words,
        .text_alignment = config.text_alignment orelse .left,
    });
    clay.openTextElement(text, element_config);
}
