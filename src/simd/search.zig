const std = @import("std");

fn ProcessedCharVec(comptime L: usize) type {
    return struct {
        lowered_chars: @Vector(L, u8),
        is_lower: @Vector(L, bool),
        is_upper: @Vector(L, bool),
    };
}

fn preprocess_chars(comptime L: usize, chars: @Vector(L, u8)) ProcessedCharVec(L) {
    const upper_A: @Vector(L, u8) = @splat('A');
    const upper_Z: @Vector(L, u8) = @splat('Z');
    const lower_A: @Vector(L, u8) = @splat('a');
    const lower_Z: @Vector(L, u8) = @splat('z');
    const all_false: @Vector(L, bool) = @splat(false);
    const all_zeroes: @Vector(L, u8) = @splat(0);
    const is_upper = @select(bool, chars >= upper_A, chars <= upper_Z, all_false);
    const is_lower = @select(bool, chars >= lower_A, chars <= lower_Z, all_false);
    const to_lower_offset: @Vector(L, u8) = @splat(32);
    const masked_to_lower_offset = @select(u8, is_upper, to_lower_offset, all_zeroes);
    const lowered_chars = chars + masked_to_lower_offset;

    return ProcessedCharVec(L){ .lowered_chars = lowered_chars, .is_lower = is_lower, .is_upper = is_upper };
}

test "preprocess_chars" {
    const chars: [8]u8 = [8]u8{ 'A', 'B', 'C', 'D', 'e', 'f', 'g', 'h' };
    const char_vec: @Vector(8, u8) = chars;
    const res = preprocess_chars(8, char_vec);

    try std.testing.expectEqual(res.is_upper, [_]bool{ true, true, true, true, false, false, false, false });
    try std.testing.expectEqual(res.is_lower, [_]bool{ false, false, false, false, true, true, true, true });
    try std.testing.expectEqual(res.lowered_chars, [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' });
}
