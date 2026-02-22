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

    /// This block contains a color table, which is a sequence of bytes representing red-green-blue
    /// color triplets. The Global Color Table is used by images without a Local Color Table and by
    /// Plain Text Extensions. Its presence is marked by the Global Color Table Flag being set to 1
    /// in the Logical Screen Descriptor; if present, it immediately follows the Logical Screen
    /// Descriptor and contains a number of bytes equal to:
    ///             3 x 2^(Size of Global Color Table+1).
    /// This block is OPTIONAL; at most one Global Color Table may be present per Data Stream.
    global_color_table: ?[]const u8 = null,

    pub fn init(reader: *std.Io.Reader, allocator: std.mem.Allocator) !LogicalScreenDescriptor {
        var result: LogicalScreenDescriptor = undefined;

        result.width = try reader.takeInt(u16, .little);
        result.height = try reader.takeInt(u16, .little);
        result.packed_fields = try reader.takeStruct(PackedFields, .little);
        result.background_color_index = try reader.takeByte();
        result.pixel_aspect_ratio = try reader.takeByte();

        if (result.packed_fields.global_color_table_flag) {
            const table_size: usize = @intCast(result.packed_fields.global_color_table_size);
            const size = 3 * std.math.pow(usize, 2, table_size + 1);

            const table = try reader.take(size);
            const global_color_table = try allocator.alloc(u8, size);
            @memcpy(global_color_table, table);
            result.global_color_table = global_color_table;
        }

        return result;
    }

    pub fn deinit(self: LogicalScreenDescriptor, allocator: std.mem.Allocator) void {
        if (self.global_color_table) |table| {
            allocator.free(table);
        }
    }
};

/// Each image in the Data Stream is composed of an Image Descriptor, an optional Local Color
/// Table, and the image data.  Each image must fit within the boundaries of the Logical Screen,
/// as defined in the Logical Screen Descriptor.
///
/// The Image Descriptor contains the parameters necessary to process a table based image. The
/// coordinates given in this block refer to coordinates within the Logical Screen, and are given
/// in pixels. This block is a Graphic-Rendering Block, optionally preceded by one or more Control
/// blocks such as the Graphic Control Extension, and may be optionally followed by a Local Color
/// Table; the Image Descriptor is always followed by the image data.
///
/// This block is REQUIRED for an image.  Exactly one Image Descriptor must be present per image in
/// the Data Stream.  An unlimited number of images may be present per Data Stream.
pub const ImageDescriptor = struct {
    pub const PackedFields = packed struct {
        /// If the Local Color Table Flag is set to 1, the value in this field is used to calculate
        /// the number of bytes contained in the Local Color Table. To determine that actual size
        /// of the color table, raise 2 to the value of the field + 1. This value should be 0 if
        /// there is no Local Color Table specified.
        local_color_table_size: u3,

        /// TBD
        reserved: u2,

        /// Indicates whether the Local Color Table is sorted.  If the flag is set, the Local Color
        /// Table is sorted, in order of decreasing importance. Typically, the order would be
        /// decreasing frequency, with most frequent color first. This assists a decoder, with
        /// fewer available colors, in choosing the best subset of colors; the decoder may use an
        /// initial segment of the table to render the graphic.
        ///
        /// Values :    0 -   Not ordered.
        ///             1 -   Ordered by decreasing importance, most
        ///                   important color first.
        sort_flag: bool,

        /// Indicates if the image is interlaced. An image is interlaced in a four-pass interlace
        /// pattern; see Appendix E for details.
        ///
        /// Values :    0 - Image is not interlaced.
        ///             1 - Image is interlaced.
        interlace_flag: bool,

        /// Indicates the presence of a Local Color Table immediately following this Image
        /// Descriptor.
        ///
        ///
        /// Values :    0 -   Local Color Table is not present. Use
        ///                   Global Color Table if available.
        ///             1 -   Local Color Table present, and to follow
        ///                   immediately after this Image Descriptor.
        local_color_table_flag: bool,
    };

    /// Identifies the beginning of an Image Descriptor. This field contains the fixed value 0x2C.
    image_separator: u8,

    /// Column number, in pixels, of the left edge of the image, with respect to the left edge of
    /// the Logical Screen. Leftmost column of the Logical Screen is 0.
    image_left_position: u16,

    /// Row number, in pixels, of the top edge of the image with respect to the top edge of the
    /// Logical Screen. Top row of the Logical Screen is 0.
    image_top_position: u16,

    /// Width of the image in pixels.
    image_width: u16,

    /// Height of the image in pixels.
    image_height: u16,

    /// See documentation for PackedFields.
    packed_fields: PackedFields,

    /// This block contains a color table, which is a sequence of bytes representing red-green-blue
    /// color triplets. The Local Color Table is used by the image that immediately follows. Its
    /// presence is marked by the Local Color Table Flag being set to 1 in the Image Descriptor; if
    /// present, the Local Color Table immediately follows the Image Descriptor and contains a
    /// number of bytes equal to
    ///                       3x2^(Size of Local Color Table+1).
    /// If present, this color table temporarily becomes the active color table and the following
    /// image should be processed using it. This block is OPTIONAL; at most one Local Color Table
    /// may be present per Image Descriptor and its scope is the single image associated with the
    /// Image Descriptor that precedes it.
    local_color_table: ?[]const u8 = null,

    pub fn init(reader: *std.Io.Reader, allocator: std.mem.Allocator) !ImageDescriptor {
        var result: ImageDescriptor = undefined;

        result.image_separator = try reader.takeByte();
        result.image_left_position = try reader.takeInt(u16, .little);
        result.image_top_position = try reader.takeInt(u16, .little);
        result.image_width = try reader.takeInt(u16, .little);
        result.image_height = try reader.takeInt(u16, .little);
        result.packed_fields = try reader.takeStruct(PackedFields, .little);

        if (result.packed_fields.local_color_table_flag) {
            const table_size: usize = @intCast(result.packed_fields.local_color_table_size);
            const size = 3 * std.math.pow(usize, 2, table_size + 1);
            const table = try reader.take(size);
            const local_color_table = try allocator.alloc(u8, size);
            @memcpy(local_color_table, table);
            result.local_color_table = local_color_table;
        }

        return result;
    }

    pub fn deinit(self: *ImageDescriptor, allocator: std.mem.Allocator) void {
        if (self.local_color_table) |table| {
            allocator.free(table);
        }
    }
};

/// Loads the GIF file at the given path. 'path' should be absolute.
pub fn load(allocator: std.mem.Allocator, path: []const u8) !bool {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    const header: Header = try .init(&reader.interface);
    if (!header.isValid()) {
        std.debug.print("Given file '{s}' is not a valid GIF.", .{path});
        return false;
    }

    const descriptor: LogicalScreenDescriptor = try .init(&reader.interface, allocator);
    defer descriptor.deinit(allocator);


    return true;
}
