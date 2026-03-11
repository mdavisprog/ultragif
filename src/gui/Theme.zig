const clay = @import("clay");

pub const Colors = struct {
    background: clay.Color = .initu8(34, 40, 49, 255),
    button_background: clay.Color = .initu8(148, 137, 121, 255),
    button_hovered: clay.Color = .initu8(160, 150, 134, 255),
    button_active: clay.Color = .initu8(130, 120, 106, 255),
    button_disabled: clay.Color = .initu8(133, 122, 106, 255),
    text: clay.Color = .initu8(235, 235, 235, 255),
    text_disabled: clay.Color = .initu8(180, 180, 180, 255),
};

colors: Colors = .{},
