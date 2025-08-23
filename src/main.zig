const std = @import("std");
const interleave = @import("./simd/interleave.zig");
const search = @import("./search.zig");

pub fn main() !void {
    const words = [16][]const u8{
        "apple", "bravo", "crane", "delta",
        "early", "frost", "grape", "haste",
        "ivory", "jumbo", "karma", "lemon",
        "magic", "noble", "ocean", "prize",
    };

    const interleaved = interleave.interleave(5, 16, words);
    std.debug.print("Result: {any}\n", .{interleaved});
}

pub const simd_interleave = @import("simd/interleave.zig");
pub const simd_search = @import("simd/search.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
