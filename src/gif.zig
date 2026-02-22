const std = @import("std");

/// The Header identifies the GIF Data Stream in context. The Signature field marks the beginning
/// of the Data Stream, and the Version field identifies the set of capabilities required of a
/// decoder to fully process the Data Stream.  This block is REQUIRED; exactly one Header must
/// be present per Data Stream.
pub const Header = struct {
    /// This field identifies the beginning of the GIF Data Stream; it is not intended to provide
    /// a unique signature for the identification of the data. It is recommended that the GIF Data
    /// Stream be identified externally by the application.
    signature: [3]u8,

    /// ENCODER : An encoder should use the earliest possible version number that defines all the
    /// blocks used in the Data Stream. When two or more Data Streams are combined, the latest of the
    /// individual version numbers should be used for the resulting Data Stream.
    /// DECODER : A decoder should attempt to process the data stream to the best of its ability;
    /// if it encounters a version number which it is not capable of processing fully, it should
    /// nevertheless, attempt to process the data stream to the best of its ability, perhaps after
    /// warning the user that the data may be incomplete.
    version: [3]u8,

    pub fn init(reader: *std.Io.Reader) !Header {
        const signature = try reader.take(3);
        const version = try reader.take(3);

        var result: Header = undefined;
        @memcpy(&result.signature, signature);
        @memcpy(&result.version, version);
        return result;
    }

    pub fn isValid(self: Header) bool {
        if (!std.mem.eql(u8, &self.signature, "GIF")) {
            return false;
        }

        if (!std.mem.eql(u8, &self.version, "87a") and !std.mem.eql(u8, &self.version, "89a")) {
            return false;
        }

        return true;
    }
};

/// The Logical Screen Descriptor contains the parameters necessary to define the area of the
/// display device within which the images will be rendered.  The coordinates in this block are
/// given with respect to the top-left corner of the virtual screen; they do not necessarily refer
/// to absolute coordinates on the display device.  This implies that they could refer to window
/// coordinates in a window-based environment or printer coordinates when a printer is used.
pub const LogicalScreenDescriptor = struct {
    pub const PackedFields = packed struct {
        /// If the Global Color Table Flag is set to 1, the value in this field is used to
        /// calculate the number of bytes contained in the Global Color Table. To determine that
        /// actual size of the color table, raise 2 to [the value of the field + 1].  Even if there
        /// is no Global Color Table specified, set this field according to the above formula so
        /// that decoders can choose the best graphics mode to display the stream in.
        global_color_table_size: u3,

        /// Indicates whether the Global Color Table is sorted. If the flag is set, the Global
        /// Color Table is sorted, in order of decreasing importance. Typically, the order would be
        /// decreasing frequency, with most frequent color first. This assists a decoder, with
        /// fewer available colors, in choosing the best subset of colors; the decoder may use an
        /// initial segment of the table to render the graphic.
        ///
        /// 0 -   No Global Color Table follows, the Background Color Index field is meaningless.
        /// 1 -   A Global Color Table will immediately follow, the Background Color Index field is
        ///       meaningful.
        sort_flag: bool,

        /// Number of bits per primary color available to the original image, minus 1. This value
        /// represents the size of the entire palette from which the colors in the graphic were
        /// selected, not the number of colors actually used in the graphic. For example, if the
        /// value in this field is 3, then the palette of the original image had 4 bits per primary
        /// color available to create the image.  This value should be set to indicate the richness
        /// of the original palette, even if not every color from the whole palette is available on
        /// the source machine.
        color_resolution: u3,

        /// Flag indicating the presence of a Global Color Table; if the flag is set, the Global
        /// Color Table will immediately follow the Logical Screen Descriptor. This flag also
        /// selects the interpretation of the Background Color Index; if the flag is set, the value
        /// of the Background Color Index field should be used as the table index of the background
        /// color.
        ///
        /// 0 -   No Global Color Table follows, the Background Color Index field is meaningless.
        /// 1 -   A Global Color Table will immediately follow, the Background Color Index field is
        ///       meaningful.
        global_color_table_flag: bool,
    };

    /// Width, in pixels, of the Logical Screen where the images will be rendered in the displaying
    /// device.
    width: u16,

    /// Height, in pixels, of the Logical Screen where the images will be rendered in the
    /// displaying device.
    height: u16,

    /// See Documentation in PackedFields.
    packed_fields: PackedFields,

    /// Index into the Global Color Table for the Background Color. The Background Color is the
    /// color used for those pixels on the screen that are not covered by an image. If the Global
    /// Color Table Flag is set to (zero), this field should be zero and should be ignored.
    background_color_index: u8,

    /// Factor used to compute an approximation of the aspect ratio of the pixel in the original
    /// image.  If the value of the field is not 0, this approximation of the aspect ratio is
    /// computed based on the formula:
    ///
    /// Aspect Ratio = (Pixel Aspect Ratio + 15) / 64
    ///
    /// The Pixel Aspect Ratio is defined to be the quotient of the pixel's
    /// width over its height.  The value range in this field allows
    /// specification of the widest pixel of 4:1 to the tallest pixel of
    /// 1:4 in increments of 1/64th.
    ///
    /// 0 -   No aspect ratio information is given.
    /// 1..255 -   Value used in the computation.
    pixel_aspect_ratio: u8,

    pub fn init(reader: *std.Io.Reader) !LogicalScreenDescriptor {
        const width = try reader.takeInt(u16, .little);
        const height = try reader.takeInt(u16, .little);
        const packed_fields = try reader.takeStruct(PackedFields, .little);
        const background_color_index = try reader.takeByte();
        const pixel_aspect_ratio = try reader.takeByte();

        return .{
            .width = width,
            .height = height,
            .packed_fields = packed_fields,
            .background_color_index = background_color_index,
            .pixel_aspect_ratio = pixel_aspect_ratio,
        };
    }
};

/// Loads the GIF file at the given path. 'path' should be absolute.
pub fn load(path: []const u8) !bool {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    const header: Header = try .init(&reader.interface);
    if (!header.isValid()) {
        std.debug.print("Given file '{s}' is not a valid GIF.", .{path});
        return false;
    }

    const descriptor: LogicalScreenDescriptor = try .init(&reader.interface);
    std.debug.print("descriptor: {any}\n", .{ descriptor });

    return true;
}
