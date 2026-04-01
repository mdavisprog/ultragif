const compression = @import("compression/root.zig");
const Image = @import("Image.zig");
const std = @import("std");

const lzw = compression.lzw;

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

    pub fn isValid(self: Header) bool {
        if (!std.mem.eql(u8, &self.signature, "GIF")) {
            return false;
        }

        if (!std.mem.eql(u8, &self.version, "87a") and !std.mem.eql(u8, &self.version, "89a")) {
            return false;
        }

        return true;
    }

    fn initDefault() Header {
        var result: Header = undefined;
        @memcpy(&result.signature, "GIF");
        @memcpy(&result.version, "89a");
        return result;
    }

    fn read(reader: *std.Io.Reader) !Header {
        const signature = try reader.take(3);
        const version = try reader.take(3);

        var result: Header = undefined;
        @memcpy(&result.signature, signature);
        @memcpy(&result.version, version);
        return result;
    }

    fn write(self: Header, writer: *std.Io.Writer) !void {
        try writer.writeAll(&self.signature);
        try writer.writeAll(&self.version);
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
        /// 0 -   Not ordered.
        /// 1 -   Ordered by decreasing importance, most important color first.
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

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !LogicalScreenDescriptor {
        var result: LogicalScreenDescriptor = undefined;

        result.width = try reader.takeInt(u16, .little);
        result.height = try reader.takeInt(u16, .little);
        result.packed_fields = try reader.takeStruct(PackedFields, .little);
        result.background_color_index = try reader.takeByte();
        result.pixel_aspect_ratio = try reader.takeByte();

        if (result.packed_fields.global_color_table_flag) {
            const table_size: usize = @intCast(result.packed_fields.global_color_table_size);
            const size = 3 * std.math.pow(usize, 2, table_size + 1);
            result.global_color_table = try reader.readAlloc(allocator, size);
        } else {
            result.global_color_table = null;
        }

        return result;
    }

    fn write(self: LogicalScreenDescriptor, writer: *std.Io.Writer) !void {
        try writer.writeInt(u16, self.width, .little);
        try writer.writeInt(u16, self.height, .little);
        try writer.writeStruct(self.packed_fields, .little);
        try writer.writeByte(self.background_color_index);
        try writer.writeByte(self.pixel_aspect_ratio);

        if (self.global_color_table) |table| {
            try writer.writeAll(table);

            const current = table.len / 3;
            const expected = self.numColors();
            var remaining = expected -| current;
            while (remaining > 0) : (remaining -|= 1) {
                try writer.writeAll(&.{0, 0, 0});
            }
        }
    }

    fn deinit(self: LogicalScreenDescriptor, allocator: std.mem.Allocator) void {
        if (self.global_color_table) |table| {
            allocator.free(table);
        }
    }

    fn numColors(self: LogicalScreenDescriptor) usize {
        const size = @as(usize, @intCast(self.packed_fields.global_color_table_size)) + 1;
        return std.math.pow(usize, 2, size);
    }
};

/// Data Sub-blocks are units containing data. They do not have a label, these blocks are processed
/// in the context of control blocks, wherever data blocks are specified in the format. The first
/// byte of the Data sub-block indicates the number of data bytes to follow. A data sub-block may
/// contain from 0 to 255 data bytes. The size of the block does not account for the size byte
/// itself, therefore, the empty sub-block is one whose size field contains 0x00.
pub const DataSubBlock = struct {
    /// Number of bytes in the Data Sub-block; the size must be within 0 and 255 bytes, inclusive
    block_size: u8,

    /// Any 8-bit value. There must be exactly as many Data Values as specified by the Block Size
    /// field.
    data_values: ?[]const u8,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !?DataSubBlock {
        var result: DataSubBlock = undefined;

        result.block_size = try reader.takeByte();
        if (result.block_size == 0) {
            return null;
        }

        result.data_values = try reader.readAlloc(allocator, @intCast(result.block_size));

        return result;
    }

    fn write(self: DataSubBlock, writer: *std.Io.Writer) !void {
        const data_values = self.data_values orelse return;
        try writer.writeByte(self.block_size);
        try writer.writeAll(data_values);
    }

    fn initData(data: []const u8) DataSubBlock {
        return .{
            .block_size = @intCast(data.len),
            .data_values = data,
        };
    }

    fn deinit(self: DataSubBlock, allocator: std.mem.Allocator) void {
        if (self.data_values) |data_values| {
            allocator.free(data_values);
        }
    }
};

/// The image data for a table based image consists of a sequence of sub-blocks, of size at most
/// 255 bytes each, containing an index into the active color table, for each pixel in the image.
/// Pixel indices are in order of left to right and from top to bottom.  Each index must be within
/// the range of the size of the active color table, starting at 0. The sequence of indices is
/// encoded using the LZW Algorithm with variable-length code, as described in Appendix F.
pub const ImageData = struct {
    /// This byte determines the initial number of bits used for LZW codes in the image data, as
    /// described in Appendix F.
    lzw_minimum_code_size: u8,

    /// Compressed data blocks that represents this image.
    image_data: []const DataSubBlock,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !ImageData {
        var result: ImageData = undefined;
        result.lzw_minimum_code_size = try reader.takeByte();

        var image_data: std.ArrayListUnmanaged(DataSubBlock) = .empty;
        while (try DataSubBlock.read(reader, allocator)) |data| {
            try image_data.append(allocator, data);
        }
        result.image_data = try image_data.toOwnedSlice(allocator);

        return result;
    }

    fn write(self: ImageData, writer: *std.Io.Writer) !void {
        try writer.writeByte(self.lzw_minimum_code_size);

        for (self.image_data) |image_data| {
            try image_data.write(writer);
        }

        // Terminating byte
        try writer.writeByte(0);
    }

    fn deinit(self: ImageData, allocator: std.mem.Allocator) void {
        for (self.image_data) |block| {
            block.deinit(allocator);
        }
        allocator.free(self.image_data);
    }

    fn format(self: ImageData, writer: *std.Io.Writer) !void {
        try writer.print("\nlzw_minimum_code_size: {}\n", .{self.lzw_minimum_code_size});

        var total_size: usize = 0;
        for (self.image_data) |data| {
            total_size += @as(usize, @intCast(data.block_size));
        }
        try writer.print("image_data blocks: {} total size: {}", .{
            self.image_data.len,
            total_size,
        });
    }

    fn totalSize(self: ImageData) usize {
        var result: usize = 0;

        for (self.image_data) |data| {
            result += @as(usize, @intCast(data.block_size));
        }

        return result;
    }

    fn decode(self: ImageData, allocator: std.mem.Allocator, writer: *std.Io.Writer) !void {
        var decoder: lzw.Decoder(.little) = try .init(allocator, self.lzw_minimum_code_size, 0);
        defer decoder.deinit();

        for (self.image_data) |data| {
            if (data.data_values) |block| {
                var reader: std.Io.Reader = .fixed(block);
                try decoder.decode(&reader, writer);
            }
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

    /// Raw compressed image data.
    image_data: ImageData,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !ImageDescriptor {
        var result: ImageDescriptor = undefined;

        result.image_left_position = try reader.takeInt(u16, .little);
        result.image_top_position = try reader.takeInt(u16, .little);
        result.image_width = try reader.takeInt(u16, .little);
        result.image_height = try reader.takeInt(u16, .little);
        result.packed_fields = try reader.takeStruct(PackedFields, .little);

        if (result.packed_fields.local_color_table_flag) {
            const table_size: usize = @intCast(result.packed_fields.local_color_table_size);
            const size = 3 * std.math.pow(usize, 2, table_size + 1);
            result.local_color_table = try reader.readAlloc(allocator, size);
        } else {
            result.local_color_table = null;
        }

        result.image_data = try .read(reader, allocator);

        return result;
    }

    fn write(self: ImageDescriptor, writer: *std.Io.Writer) !void {
        try writer.writeByte(@intFromEnum(Label.image_descriptor));
        try writer.writeInt(u16, self.image_left_position, .little);
        try writer.writeInt(u16, self.image_top_position, .little);
        try writer.writeInt(u16, self.image_width, .little);
        try writer.writeInt(u16, self.image_height, .little);
        try writer.writeStruct(self.packed_fields, .little);
        try self.image_data.write(writer);
    }

    fn deinit(self: ImageDescriptor, allocator: std.mem.Allocator) void {
        if (self.local_color_table) |table| {
            allocator.free(table);
        }

        self.image_data.deinit(allocator);
    }

    fn decode(self: ImageDescriptor, allocator: std.mem.Allocator) ![]const u8 {
        const width: usize = @intCast(self.image_width);
        const height: usize = @intCast(self.image_height);
        const size: usize = width * height;
        const pixels = try allocator.alloc(u8, size);
        var writer: std.Io.Writer = .fixed(pixels);

        try self.image_data.decode(allocator, &writer);

        return pixels;
    }

    pub fn format(self: ImageDescriptor, writer: *std.Io.Writer) !void {
        try writer.print("\nimage_left_position: {}\n", .{self.image_left_position});
        try writer.print("image_top_position: {}\n", .{self.image_top_position});
        try writer.print("image_width: {}\n", .{self.image_width});
        try writer.print("image_height: {}\n", .{self.image_height});
        try writer.print("local_color_table_size: {}\n", .{self.packed_fields.local_color_table_size});
        try writer.print("sort_flag: {}\n", .{self.packed_fields.sort_flag});
        try writer.print("interlace_flag: {}\n", .{self.packed_fields.interlace_flag});
        try writer.print("local_color_table_flag: {}\n", .{self.packed_fields.local_color_table_flag});
        const len = if (self.local_color_table) |table| table.len else 0;
        try writer.print("local_color_table: {} bytes\n", .{len});
        try writer.print("image_data: {f}\n", .{self.image_data});
    }
};

/// The Graphic Control Extension contains parameters used when processing a graphic rendering
/// block. The scope of this extension is the first graphic rendering block to follow. The
/// extension contains only one data sub-block.
///
/// This block is OPTIONAL; at most one Graphic Control Extension may precede a graphic rendering
/// block. This is the only limit to the number of Graphic Control Extensions that may be contained
/// in a Data Stream.
pub const GraphicControlExtension = struct {
    pub const PackedFields = packed struct {
        /// Indicates whether a transparency index is given in the Transparent Index field.
        ///
        /// Values :    0 -   Transparent Index is not given.
        ///             1 -   Transparent Index is given.
        transparency_color_flag: bool,

        /// Indicates whether or not user input is expected before continuing. If the flag is set,
        /// processing will continue when user input is entered. The nature of the User input is
        /// determined by the application (Carriage Return, Mouse Button Click, etc.).
        ///
        /// Values :    0 -   User input is not expected.
        ///             1 -   User input is expected.
        ///
        /// When a Delay Time is used and the User Input Flag is set,processing will continue when
        /// user input is received or when the delay time expires, whichever occurs first.
        user_input_flag: bool,

        /// Indicates the way in which the graphic is to be treated after being displayed.
        ///
        /// Values :    0 -   No disposal specified. The decoder is not required to take any action.
        ///             1 -   Do not dispose. The graphic is to be left in place.
        ///             2 -   Restore to background color. The area used by the graphic must be
        ///                   restored to the background color.
        ///             3 -   Restore to previous. The decoder is required to restore the area
        ///                   overwritten by the graphic with what was there prior to rendering
        ///                   the graphic.
        ///           4-7 -   To be defined.
        disposal_method: u3,

        /// TBD
        reserved: u3,
    };

    /// The way in which the graphic is to be treated after being displayed.
    pub const DisposalMethod = enum(u8) {
        none,
        leave_in_place,
        restore_to_background,
        restore_to_previous,
    };

    /// Fixed value representing the size of this block
    const block_size_constant = 4;

    /// Number of bytes in the block, after the Block Size field and up to but not including the
    /// Block Terminator.  This field contains the fixed value 4.
    block_size: u8,

    /// See documentation for PackedFields.
    packed_fields: PackedFields,

    /// If not 0, this field specifies the number of hundredths (1/100) of a second to wait before
    /// continuing with the processing of the Data Stream. The clock starts ticking immediately
    /// after the graphic is rendered. This field may be used in conjunction with the User Input
    /// Flag field.
    delay_time: u16,

    /// The Transparency Index is such that when encountered, the corresponding pixel of the
    /// display device is not modified and processing goes on to the next pixel. The index is
    /// present if and only if the Transparency Flag is set to 1.
    transparency_color_index: u8,

    fn read(reader: *std.Io.Reader) !GraphicControlExtension {
        var result: GraphicControlExtension = undefined;

        result.block_size = try reader.takeByte();
        std.debug.assert(result.block_size == 4);

        result.packed_fields = try reader.takeStruct(PackedFields, .little);
        result.delay_time = try reader.takeInt(u16, .little);
        result.transparency_color_index = try reader.takeByte();

        const block_terminator = try reader.takeByte();
        std.debug.assert(block_terminator == 0);

        return result;
    }

    fn write(self: GraphicControlExtension, writer: *std.Io.Writer) !void {
        try writer.writeByte(@intFromEnum(Label.extension));
        try writer.writeByte(@intFromEnum(ExtensionType.graphic_control));
        try writer.writeByte(block_size_constant);
        try writer.writeStruct(self.packed_fields, .little);
        try writer.writeInt(u16, self.delay_time, .little);
        try writer.writeByte(self.transparency_color_index);

        // Terminator
        try writer.writeByte(0);
    }

    fn getTransparentIndex(self: GraphicControlExtension) ?u8 {
        if (self.packed_fields.transparency_color_flag) {
            return self.transparency_color_index;
        }

        return null;
    }

    fn setDisposalMethod(self: *GraphicControlExtension, method: DisposalMethod) void {
        self.packed_fields.disposal_method = switch (method) {
            .leave_in_place => 1,
            .restore_to_background => 2,
            .restore_to_previous => 3,
            else => 0,
        };
    }

    fn getDisposalMethod(self: GraphicControlExtension) DisposalMethod {
        return switch (self.packed_fields.disposal_method) {
            1 => .leave_in_place,
            2 => .restore_to_background,
            3 => .restore_to_previous,
            else => .none,
        };
    }

    pub fn format(self: GraphicControlExtension, writer: *std.Io.Writer) !void {
        try writer.print(
            "\ntransparency_color_flag: {}\n",
            .{self.packed_fields.transparency_color_flag},
        );
        try writer.print("user_input_flag: {}\n", .{self.packed_fields.user_input_flag});
        try writer.print("disposal_method: {}\n", .{self.packed_fields.disposal_method});
        try writer.print("delay_time: {}\n", .{self.delay_time});
        try writer.print("transparency_color_index: {}", .{self.transparency_color_index});
    }
};

/// The Comment Extension contains textual information which is not part of the actual graphics in
/// the GIF Data Stream. It is suitable for including comments about the graphics, credits,
/// descriptions or any other type of non-control and non-graphic data.  The Comment Extension may
/// be ignored by the decoder, or it may be saved for later processing; under no circumstances
/// should a Comment Extension disrupt or interfere with the processing of the Data Stream.
///
/// This block is OPTIONAL; any number of them may appear in the Data Stream.
pub const CommentExtension = struct {
    /// This block is intended for humans.  It should contain text using the 7-bit ASCII character
    /// set. This block should not be used to store control information for custom processing.
    comment_data: []const DataSubBlock,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !CommentExtension {
        std.debug.print("Found CommandExtension\n", .{});

        var data: std.ArrayListUnmanaged(DataSubBlock) = .empty;
        while (try DataSubBlock.read(reader, allocator)) |block| {
            if (block.data_values) |comment| {
                std.debug.print("   comment: {s}\n", .{comment});
            }
            try data.append(allocator, block);
        }

        return .{
            .comment_data = try data.toOwnedSlice(allocator),
        };
    }

    fn deinit(self: CommentExtension, allocator: std.mem.Allocator) void {
        for (self.comment_data) |data| {
            data.deinit(allocator);
        }
        allocator.free(self.comment_data);
    }
};

/// The Plain Text Extension contains textual data and the parameters necessary to render that data
/// as a graphic, in a simple form. The textual data will be encoded with the 7-bit printable ASCII
/// characters.  Text data are rendered using a grid of character cells defined by the parameters in
/// the block fields. Each character is rendered in an individual cell. The textual data in this
/// block is to be rendered as mono-spaced characters, one character per cell, with a best fitting
/// font and size. For further information, see the section on Recommendations below. The data
/// characters are taken sequentially from the data portion of the block and rendered within a cell,
/// starting with the upper left cell in the grid and proceeding from left to right and from top to
/// bottom. Text data is rendered until the end of data is reached or the character grid is filled.
/// The Character Grid contains an integral number of cells; in the case that the cell dimensions do
/// not allow for an integral number, fractional cells must be discarded; an encoder must be careful
/// to specify the grid dimensions accurately so that this does not happen. This block requires a
/// Global Color Table to be available; the colors used by this block reference the Global Color Table
/// in the Stream if there is one, or the Global Color Table from a previous Stream, if one was saved.
/// This block is a graphic rendering block, therefore it may be modified by a Graphic Control
/// Extension.  This block is OPTIONAL; any number of them may appear in the Data Stream.
pub const PlainTextExtension = struct {
    /// Number of bytes in the extension, after the Block Size field and up to but not including the
    /// beginning of the data portion. This field contains the fixed value 12.
    block_size: u8,

    /// Column number, in pixels, of the left edge of the text grid, with respect to the left edge
    /// of the Logical Screen.
    text_grid_left_position: u16,

    /// Row number, in pixels, of the top edge of the text grid, with respect to the top edge of
    /// the Logical Screen.
    text_grid_top_position: u16,

    /// Width of the text grid in pixels.
    text_grid_width: u16,

    /// Height of the text grid in pixels.
    text_grid_height: u16,

    /// Width, in pixels, of each cell in the grid.
    character_cell_width: u8,

    /// Height, in pixels, of each cell in the grid.
    character_cell_height: u8,

    /// Index into the Global Color Table to be used to render the text foreground.
    text_foreground_color_index: u8,

    /// Index into the Global Color Table to be used to render the text background.
    text_background_color_index: u8,

    /// Sequence of sub-blocks, each of size at most 255 bytes and at least 1 byte, with the size
    /// in a byte preceding the data.  The end of the sequence is marked by the Block Terminator.
    plain_text_data: []const DataSubBlock,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !PlainTextExtension {
        var result: PlainTextExtension = undefined;

        result.block_size = try reader.takeByte();
        std.debug.assert(result.block_size == 12);

        result.text_grid_left_position = try reader.takeInt(u16, .little);
        result.text_grid_top_position = try reader.takeInt(u16, .little);
        result.text_grid_width = try reader.takeInt(u16, .little);
        result.text_grid_height = try reader.takeInt(u16, .little);

        result.character_cell_width = try reader.takeByte();
        result.character_cell_height = try reader.takeByte();

        result.text_foreground_color_index = try reader.takeByte();
        result.text_background_color_index = try reader.takeByte();

        var plain_text_data: std.ArrayListUnmanaged(DataSubBlock) = .empty;
        while (try DataSubBlock.read(reader, allocator)) |block| {
            try plain_text_data.append(allocator, block);
        }
        result.plain_text_data = try plain_text_data.toOwnedSlice(allocator);

        return result;
    }

    fn deinit(self: PlainTextExtension, allocator: std.mem.Allocator) void {
        for (self.plain_text_data) |block| {
            block.deinit(allocator);
        }
        allocator.free(self.plain_text_data);
    }
};

/// The Application Extension contains application-specific information; it conforms with the
/// extension block syntax, as described below, and its block label is 0xFF.
pub const ApplicationExtension = struct {
    const block_size_constant: u8 = 11;

    /// Number of bytes in this extension block, following the Block Size field, up to but not
    /// including the beginning of the Application Data. This field contains the fixed value 11.
    block_size: u8,

    /// Sequence of eight printable ASCII characters used to identify the application owning the
    /// Application Extension.
    application_identifier: [8]u8,

    /// Sequence of three bytes used to authenticate the Application Identifier. An Application
    /// program may use an algorithm to compute a binary code that uniquely identifies it as the
    /// application owning the Application Extension.
    application_authentication_code: [3]u8,

    /// May contain 0 or more data blocks.
    application_data: ?[]const DataSubBlock,

    fn read(reader: *std.Io.Reader, allocator: std.mem.Allocator) !ApplicationExtension {
        var result: ApplicationExtension = undefined;

        result.block_size = try reader.takeByte();
        std.debug.assert(result.block_size == block_size_constant);

        @memcpy(
            &result.application_identifier,
            try reader.take(result.application_identifier.len),
        );

        @memcpy(
            &result.application_authentication_code,
            try reader.take(result.application_authentication_code.len),
        );

        var application_data: std.ArrayListUnmanaged(DataSubBlock) = .empty;
        while (try DataSubBlock.read(reader, allocator)) |data| {
            try application_data.append(allocator, data);
        }

        if (application_data.items.len > 0) {
            result.application_data = try application_data.toOwnedSlice(allocator);
        }

        return result;
    }

    fn write(self: ApplicationExtension, writer: *std.Io.Writer) !void {
        try writer.writeByte(@intFromEnum(Label.extension));
        try writer.writeByte(@intFromEnum(ExtensionType.application));
        try writer.writeByte(self.block_size);
        try writer.writeAll(&self.application_identifier);
        try writer.writeAll(&self.application_authentication_code);

        if (self.application_data) |application_data| {
            for (application_data) |data| {
                try data.write(writer);
            }
        }

        try writer.writeByte(0);
    }

    fn deinit(self: ApplicationExtension, allocator: std.mem.Allocator) void {
        if (self.application_data) |application_data| {
            for (application_data) |data| {
                data.deinit(allocator);
            }

            allocator.free(application_data);
        }
    }

    pub fn format(self: ApplicationExtension, writer: *std.io.Writer) !void {
        try writer.print("\nblock_size: {d}\n", .{self.block_size});
        try writer.print("application_identifier: {s}\n", .{self.application_identifier});
        try writer.print(
            "application_authentication_code: {s}",
            .{self.application_authentication_code},
        );
        if (self.application_data) |application_data| {
            try writer.print("\napplication_data: {}", .{application_data.len});
            for (application_data) |data| {
                try writer.print("\nblock_size: {}", .{data.block_size});
            }
        }
    }

    fn netscape(allocator: std.mem.Allocator, loop_count: u16) !ApplicationExtension {
        var result: ApplicationExtension = undefined;

        result.block_size = block_size_constant;
        @memcpy(&result.application_identifier, "NETSCAPE");
        @memcpy(&result.application_authentication_code, "2.0");

        const data = try allocator.alloc(u8, 3);
        var writer: std.Io.Writer = .fixed(data);
        try writer.writeByte(1);
        try writer.writeInt(u16, loop_count, .little);

        var application_data = try allocator.alloc(DataSubBlock, 1);
        application_data[0] = .initData(data);
        result.application_data = application_data;

        return result;
    }
};

///
pub const ControlBlockType = enum {
    graphic_control_extension,
};

///
pub const ControlBlock = union(ControlBlockType) {
    graphic_control_extension: GraphicControlExtension,
};

///
pub const GraphicRenderingBlockType = enum {
    plain_text_extension,
    image_descriptor,
};

///
pub const GraphicRenderingBlock = union(GraphicRenderingBlockType) {
    plain_text_extension: PlainTextExtension,
    image_descriptor: ImageDescriptor,

    fn deinit(self: GraphicRenderingBlock, allocator: std.mem.Allocator) void {
        switch (self) {
            .plain_text_extension => |text| {
                text.deinit(allocator);
            },
            .image_descriptor => |descriptor| {
                descriptor.deinit(allocator);
            },
        }
    }
};

///
pub const SpecialPurposeBlockType = enum {
    trailer,
    comment_extension,
    application_extension,
};

///
pub const SpecialPurposeBlock = union(SpecialPurposeBlockType) {
    trailer: void,
    comment_extension: CommentExtension,
    application_extension: ApplicationExtension,

    fn deinit(self: SpecialPurposeBlock, allocator: std.mem.Allocator) void {
        switch (self) {
            .trailer => {},
            .comment_extension => |comment| {
                comment.deinit(allocator);
            },
            .application_extension => |app| {
                app.deinit(allocator);
            },
        }
    }
};

/// Blocks can be classified into three groups : Control, Graphic-Rendering and Special Purpose.
pub const BlockType = enum {
    /// Control blocks, such as the Header, the Logical Screen Descriptor, the Graphic Control
    /// Extension and the Trailer, contain information used to control the process of the Data
    /// Stream or information  used in setting hardware parameters.
    ///
    /// The appendix for the GIF file specification lists the Trailer as being under the special
    /// purpose block. This is where Trailers will be placed for this implementation.
    control,

    /// Graphic-Rendering blocks such as the Image Descriptor and the Plain Text Extension contain
    /// information and data used to render a graphic on the display device.
    graphic_rendering,

    /// Special Purpose blocks such as the Comment Extension and the Application Extension are
    /// neither used to control the process of the Data Stream nor do they contain information or
    /// data used to render a graphic on the display device.
    special_purpose,
};

pub const Block = union(BlockType) {
    control: ControlBlock,
    graphic_rendering: GraphicRenderingBlock,
    special_purpose: SpecialPurposeBlock,

    fn deinit(self: Block, allocator: std.mem.Allocator) void {
        switch (self) {
            .control => {},
            .graphic_rendering => |block| {
                block.deinit(allocator);
            },
            .special_purpose => |block| {
                block.deinit(allocator);
            },
        }
    }
};

/// Represents a single frame of image data in RGBA format.
pub const Frame = struct {
    /// The image sized to the logical screen size and the painted pixels for this specific frame.
    image: Image,

    /// Time in seconds in which this frame should be displayed.
    delay_time: f32,

    pub fn deinit(self: Frame, allocator: std.mem.Allocator) void {
        self.image.deinit(allocator);
    }
};

/// Represents all of the frames within the GIF.
pub const Frames = struct {
    data: []const Frame,

    pub fn deinit(self: Frames, allocator: std.mem.Allocator) void {
        for (self.data) |data| {
            data.deinit(allocator);
        }
        allocator.free(self.data);
    }
};

/// Represents the collection of objects that form the GIF file.
pub const Format = struct {
    header: Header,
    logical_screen_descriptor: LogicalScreenDescriptor,
    blocks: []const Block,

    pub fn deinit(self: Format, allocator: std.mem.Allocator) void {
        self.logical_screen_descriptor.deinit(allocator);

        for (self.blocks) |block| {
            block.deinit(allocator);
        }
        allocator.free(self.blocks);
    }

    pub fn getFrameCount(self: Format) usize {
        var result: usize = 0;

        for (self.blocks) |block| {
            switch (block) {
                .graphic_rendering => |graphic| {
                    switch (graphic) {
                        .image_descriptor => |_| {
                            result += 1;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        return result;
    }

    pub fn getCompressedImageSize(self: Format) usize {
        var result: usize = 0;

        for (self.blocks) |block| {
            switch (block) {
                .graphic_rendering => |graphic| {
                    switch (graphic) {
                        .image_descriptor => |image| {
                            result += image.image_data.totalSize();
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        return result;
    }

    pub fn getFrames(self: Format, allocator: std.mem.Allocator) !Frames {
        var frames: std.ArrayListUnmanaged(Frame) = .empty;

        // A single gif frame where each gif image is painted on to. The results of the painted gif
        // image will be added to the sprite sheet.
        var canvas: Image = try .init(
            allocator,
            @intCast(self.logical_screen_descriptor.width),
            @intCast(self.logical_screen_descriptor.height),
            .RGBA,
        );
        defer canvas.deinit(allocator);

        var graphic_control: ?GraphicControlExtension = null;
        for (self.blocks) |block| {
            switch (block) {
                .control => |control| {
                    graphic_control = control.graphic_control_extension;
                },
                .graphic_rendering => |graphic| {
                    switch (graphic) {
                        .image_descriptor => |image_desc| {
                            // Retrieve the optional transparent index for this image and the delay
                            // time.
                            var transparent_index: ?u8 = null;
                            var delay_time: u16 = 0;
                            var disposal_method: GraphicControlExtension.DisposalMethod = .none;

                            if (graphic_control) |control| {
                                transparent_index = control.getTransparentIndex();
                                delay_time = control.delay_time;
                                disposal_method = control.getDisposalMethod();
                            }

                            // Paint this image to the current canvas.
                            try self.paint(allocator, &canvas, image_desc, transparent_index);

                            // The graphic control block is no longer valid since it applies to this
                            // image descriptor.
                            graphic_control = null;

                            try frames.append(allocator, .{
                                .image = try canvas.duplicate(allocator),
                                .delay_time = @as(f32, @floatFromInt(delay_time)) * 0.01,
                            });

                            switch (disposal_method) {
                                .restore_to_background => {
                                    self.dispose(&canvas, image_desc, transparent_index);
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        return .{ .data = try frames.toOwnedSlice(allocator) };
    }

    fn getBackgoundColor(self: Format, color_table: []const u8) ?[4]u8 {
        const index = self.logical_screen_descriptor.background_color_index;
        if (index == 0) {
            return null;
        }

        return .{
            color_table[index + 0],
            color_table[index + 1],
            color_table[index + 2],
            255,
        };
    }

    fn paint(
        self: Format,
        allocator: std.mem.Allocator,
        canvas: *Image,
        image_desc: ImageDescriptor,
        transparent_index: ?u8,
    ) !void {
        const indices = try image_desc.decode(allocator);
        defer allocator.free(indices);

        const color_table = image_desc.local_color_table orelse
            self.logical_screen_descriptor.global_color_table.?;

        const dst_min_x: u32 = @intCast(image_desc.image_left_position);
        const dst_min_y: u32 = @intCast(image_desc.image_top_position);
        const dst_max_x = dst_min_x + @as(u32, @intCast(image_desc.image_width));
        const dst_max_y = dst_min_y + @as(u32, @intCast(image_desc.image_height));

        for (0..image_desc.image_height, dst_min_y..dst_max_y) |src_y, dst_y| {
            for (0..image_desc.image_width, dst_min_x..dst_max_x) |src_x, dst_x| {
                const src_index = src_y * @as(usize, @intCast(image_desc.image_width)) + src_x;
                const index = indices[src_index];
                if (transparent_index) |t_index| {
                    if (t_index == index) {
                        continue;
                    }
                }

                const i = @as(usize, @intCast(index)) * 3;
                const color = [4]u8{
                    color_table[i + 0],
                    color_table[i + 1],
                    color_table[i + 2],
                    255,
                };

                canvas.put(.fromArray(color), @intCast(dst_x), @intCast(dst_y));
            }
        }
    }

    fn dispose(
        self: Format,
        canvas: *Image,
        image_desc: ImageDescriptor,
        transparent_index: ?u8,
    ) void {
        const color_table = image_desc.local_color_table orelse
            self.logical_screen_descriptor.global_color_table.?;

        // After some research, it seems the 'restore_to_background' disposal method is not properly
        // handled by all major web browsers. The method they use is to clear the affected background
        // to be transparent, instead of the background color. For this implementation, if a
        // transparent color is specified, then just clear the background. If not, then use the
        // defined background color.
        const color = if (transparent_index == null)
            self.getBackgoundColor(color_table) orelse .{ 0, 0, 0, 0 }
        else
            .{ 0, 0, 0, 0 };

        const min_x = image_desc.image_left_position;
        const max_x = min_x + image_desc.image_width;
        const min_y = image_desc.image_top_position;
        const max_y = min_y + image_desc.image_height;
        for (min_y..max_y) |y| {
            for (min_x..max_x) |x| {
                canvas.put(.fromArray(color), @intCast(x), @intCast(y));
            }
        }
    }
};

pub const Error = error{
    InvalidHeader,
    InvalidFormat,
};

pub const Writer = struct {
    const ImageIndexed = struct {
        descriptor: ImageDescriptor,
        uncompressed_data: []const u8,
        delay: f32,
        transparent_index: ?u8,
    };

    logical_screen_desc: LogicalScreenDescriptor,
    images: std.ArrayListUnmanaged(ImageIndexed) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Writer {
        return .{
            .logical_screen_desc = std.mem.zeroes(LogicalScreenDescriptor),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Writer) void {
        const allocator = self.allocator;

        for (self.images.items) |image| {
            image.descriptor.deinit(self.allocator);
            self.allocator.free(image.uncompressed_data);
        }
        self.images.deinit(allocator);

        self.logical_screen_desc.deinit(allocator);
    }

    /// The color table must contain a list of 24-bit colors in RGB format. The table can only have
    /// a max of 255. This function will take ownership over the memory.
    pub fn setGlobalColorTable(self: *Writer, table: []const u8) void {
        // Ensure the data is aligned to 3 bytes per entry.
        const remainder = @mod(table.len, 3);
        std.debug.assert(remainder == 0);

        const count = table.len / 3;
        std.debug.assert(count <= 256);

        self.logical_screen_desc.global_color_table = table;
        self.logical_screen_desc.packed_fields.global_color_table_flag = true;
        self.logical_screen_desc.packed_fields.global_color_table_size = colorTableSize(count);
    }

    /// Adds an image where the data must be an indexed image.
    pub fn addImage(
        self: *Writer,
        left: u16,
        top: u16,
        width: u16,
        height: u16,
        data: []const u8,
        delay: f32,
        transparent_index: ?u8,
    ) !void {
        var descriptor: ImageDescriptor = std.mem.zeroes(ImageDescriptor);
        descriptor.image_left_position = left;
        descriptor.image_top_position = top;
        descriptor.image_width = width;
        descriptor.image_height = height;

        try self.images.append(self.allocator, .{
            .uncompressed_data = data,
            .descriptor = descriptor,
            .delay = delay,
            .transparent_index = transparent_index,
        });
    }

    pub fn save(self: *Writer, path: []const u8) !void {
        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var writer = file.writer(&buffer);

        try self.write(&writer.interface);
    }

    fn write(self: *Writer, writer: *std.Io.Writer) !void {
        const allocator = self.allocator;

        // Header
        const header: Header = .initDefault();
        try header.write(writer);

        // Logical Screen Descriptor
        try self.logical_screen_desc.write(writer);

        // Application Extension using NETSCAPE for loop count.
        // Only write this if multiple frames exist.
        if (self.images.items.len > 1) {
            const app_extension: ApplicationExtension = try .netscape(allocator, 0);
            defer app_extension.deinit(allocator);
            try app_extension.write(writer);
        }

        // Images
        const table_size = self.logical_screen_desc.packed_fields.global_color_table_size;
        var literal_width = @as(u4, @intCast(table_size)) + 1;
        literal_width = if (literal_width < 2) 2 else literal_width;

        var blocks: std.ArrayListUnmanaged(DataSubBlock) = .empty;
        defer blocks.deinit(allocator);

        var image_writer: std.Io.Writer.Allocating = .init(allocator);
        defer image_writer.deinit();

        for (self.images.items) |*image| {
            var encoder: lzw.Encoder(.little) = try .init(literal_width);
            try encoder.encode(&image_writer.writer, image.uncompressed_data);
            try encoder.finish(&image_writer.writer);

            const written = image_writer.written();
            var offset: usize = 0;
            while (offset < written.len) {
                const remaining = written.len - offset;
                const size = @min(remaining, 255);
                const data = try allocator.dupe(u8, written[offset..(offset + size)]);

                try blocks.append(allocator, .initData(data));

                offset += size;
            }

            var graphic_control = std.mem.zeroes(GraphicControlExtension);
            graphic_control.delay_time = @intFromFloat(image.delay * 100.0);
            graphic_control.setDisposalMethod(.restore_to_background);

            if (image.transparent_index) |index| {
                graphic_control.packed_fields.transparency_color_flag = true;
                graphic_control.transparency_color_index = index;
            }

            try graphic_control.write(writer);

            image.descriptor.image_data.lzw_minimum_code_size = literal_width;
            image.descriptor.image_data.image_data = try blocks.toOwnedSlice(allocator);
            try image.descriptor.write(writer);

            image_writer.clearRetainingCapacity();
            blocks.clearRetainingCapacity();
        }

        // Trailer and final data.
        try writer.writeByte(@intFromEnum(Label.trailer));
        try writer.flush();
    }
};

/// Loads the GIF file at the given path. 'path' should be absolute.
pub fn load(allocator: std.mem.Allocator, path: []const u8) !Format {
    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    var reader = file.reader(&buffer);

    var result: Format = undefined;

    result.header = try .read(&reader.interface);
    if (!result.header.isValid()) {
        std.log.warn("Given file '{s}' is not a valid GIF.", .{path});
        return Error.InvalidHeader;
    }

    result.logical_screen_descriptor = try .read(&reader.interface, allocator);
    errdefer result.logical_screen_descriptor.deinit(allocator);

    var blocks: std.ArrayListUnmanaged(Block) = .empty;
    defer blocks.deinit(allocator);

    var label = try getNextLabel(&reader.interface) orelse {
        std.log.warn("Failed to read GIF file after logical screen descriptor!", .{});
        return Error.InvalidFormat;
    };

    sw: switch (label) {
        .extension => {
            const extension = try getNextExtension(&reader.interface) orelse break :sw;
            switch (extension) {
                .application => {
                    const application_extension: ApplicationExtension = try .read(
                        &reader.interface,
                        allocator,
                    );

                    try blocks.append(allocator, .{
                        .special_purpose = .{
                            .application_extension = application_extension,
                        },
                    });
                },
                .plain_text => {
                    const plain_text_extension: PlainTextExtension = try .read(
                        &reader.interface,
                        allocator,
                    );

                    try blocks.append(allocator, .{
                        .graphic_rendering = .{
                            .plain_text_extension = plain_text_extension,
                        },
                    });
                },
                .comment => {
                    const comment: CommentExtension = try .read(&reader.interface, allocator);

                    try blocks.append(allocator, .{
                        .special_purpose = .{
                            .comment_extension = comment,
                        },
                    });
                },
                .graphic_control => {
                    const graphic_control: GraphicControlExtension = try .read(&reader.interface);

                    try blocks.append(allocator, .{
                        .control = .{
                            .graphic_control_extension = graphic_control,
                        },
                    });
                },
            }

            // If the next byte is not an extension type, resume processing.
            label = try getNextLabel(&reader.interface) orelse break :sw;
            continue :sw label;
        },
        .image_descriptor => {
            const image_descriptor: ImageDescriptor = try .read(
                &reader.interface,
                allocator,
            );

            try blocks.append(allocator, .{
                .graphic_rendering = .{
                    .image_descriptor = image_descriptor,
                },
            });

            // If the next byte is not an extension type, resume processing.
            label = try getNextLabel(&reader.interface) orelse break :sw;
            continue :sw label;
        },
        .trailer => {
            break :sw;
        },
    }

    result.blocks = try blocks.toOwnedSlice(allocator);

    return result;
}

fn getNextLabel(reader: *std.Io.Reader) !?Label {
    const byte = try reader.takeByte();
    return Label.init(byte) orelse {
        std.debug.print("Invalid label type: 0x{x}\n", .{byte});
        return null;
    };
}

fn getNextExtension(reader: *std.Io.Reader) !?ExtensionType {
    const byte = try reader.takeByte();
    return ExtensionType.init(byte) orelse {
        std.debug.print("Invalid extension type: 0x{x}\n", .{byte});
        return null;
    };
}

fn colorTableSize(len: usize) u3 {
    if (len <= 2) return 0;

    for (0..7) |i| {
        const power_of_two = std.math.pow(usize, 2, i);
        if (len <= power_of_two) {
            return @intCast(i);
        }
    }

    return 7;
}

const Label = enum(u8) {
    /// Extension - A protocol block labeled by the Extension Introducer 0x21.
    extension = 0x21,

    /// The Image Descriptor contains the parameters necessary to process a table based image.
    image_descriptor = 0x2C,

    /// This block is a single-field block indicating the end of the GIF Data Stream.  It contains
    /// the fixed value 0x3B.
    trailer = 0x3B,

    fn init(byte: u8) ?Label {
        return std.enums.fromInt(Label, byte);
    }
};

const ExtensionType = enum(u8) {
    graphic_control = 0xF9,
    comment = 0xFE,
    plain_text = 0x01,
    application = 0xFF,

    fn init(byte: u8) ?ExtensionType {
        return std.enums.fromInt(ExtensionType, byte);
    }
};
