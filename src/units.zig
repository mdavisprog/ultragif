pub const Memory = struct {
    pub const Symbol = enum {
        bytes,
        kilo,
        mega,
        giga,
    };

    amount: usize,
    symbol: Symbol,

    pub fn fromBytes(bytes: usize) Memory {
        // Bytes
        if (bytes < 1024) {
            return .{
                .amount = bytes,
                .symbol = .bytes,
            };
        }

        // Kilobytes
        if (bytes < 1024 * 1024) {
            return .{
                .amount = bytes / 1024,
                .symbol = .kilo,
            };
        }

        if (bytes < 1024 * 1024 * 1024) {
            return .{
                .amount = bytes / 1024 / 1024,
                .symbol = .mega,
            };
        }

        return .{
            .amount = bytes / 1024 / 1024 / 1024,
            .symbol = .giga,
        };
    }

    pub fn symbolString(self: Memory) []const u8 {
        return switch (self.symbol) {
            .bytes => "B",
            .kilo => "KB",
            .mega => "MB",
            .giga => "GB",
        };
    }
};
