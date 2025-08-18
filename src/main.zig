const std = @import("std");
const interleave = @import("./simd/interleave.zig");

pub fn main() !void {
    const words = [16][]const u8{
        "apple", "bravo", "crane", "delta",
        "early", "frost", "grape", "haste",
        "ivory", "jumbo", "karma", "lemon",
        "magic", "noble", "ocean", "prize",
    };

    const interleaved = try interleave.interleave(5, 16, words);
    std.debug.print("Result: {any}\n", .{interleaved});
}
