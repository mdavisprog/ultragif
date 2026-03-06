const clay = @import("clay");

/// Mirrors clay.TextElementConfig with optional values.
pub const TextConfig = struct {
    text_color: ?clay.Color = null,
    font_size: ?u16 = null,
    wrap_mode: ?clay.TextElementConfigWrapMode = null,
    text_alignment: ?clay.TextAlignment = null,
};

/// Text control
pub fn label(text: []const u8, config: TextConfig) void {
    const element_config = clay.storeTextElementConfig(.{
        .text_color = config.text_color orelse .white,
        .font_size = config.font_size orelse 24,
        .wrap_mode = config.wrap_mode orelse .words,
        .text_alignment = config.text_alignment orelse .left,
    });
    clay.openTextElement(text, element_config);
}
