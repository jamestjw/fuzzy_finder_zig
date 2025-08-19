const std = @import("std");

fn ProcessedCharVec(comptime L: usize) type {
    return struct {
        lowered_chars: @Vector(L, u8),
        is_lower: @Vector(L, bool),
        is_upper: @Vector(L, bool),
    };
}

inline fn vector_and(comptime L: usize, v1: @Vector(L, bool), v2: @Vector(L, bool)) @Vector(L, bool) {
    return @select(bool, v1, v2, v1);
}

inline fn vector_or(comptime L: usize, v1: @Vector(L, bool), v2: @Vector(L, bool)) @Vector(L, bool) {
    return @select(bool, v1, v1, v2);
}

fn preprocess_chars(comptime L: usize, chars: @Vector(L, u8)) ProcessedCharVec(L) {
    const upper_A: @Vector(L, u8) = @splat('A');
    const upper_Z: @Vector(L, u8) = @splat('Z');
    const lower_A: @Vector(L, u8) = @splat('a');
    const lower_Z: @Vector(L, u8) = @splat('z');
    const all_zeroes: @Vector(L, u8) = @splat(0);
    const is_upper = vector_and(L, chars >= upper_A, chars <= upper_Z);
    const is_lower = vector_and(L, chars >= lower_A, chars <= lower_Z);
    const to_lower_offset: @Vector(L, u8) = @splat(32);
    const masked_to_lower_offset = @select(u8, is_upper, to_lower_offset, all_zeroes);
    const lowered_chars = chars + masked_to_lower_offset;

    return ProcessedCharVec(L){ .lowered_chars = lowered_chars, .is_lower = is_lower, .is_upper = is_upper };
}

fn build_is_delimiter_mask(comptime L: usize, chars: @Vector(L, u8)) @Vector(L, bool) {
    const is_space = chars == @as(@Vector(L, u8), @splat(' '));
    const is_slash = chars == @as(@Vector(L, u8), @splat('/'));
    const is_period = chars == @as(@Vector(L, u8), @splat('.'));
    const is_comma = chars == @as(@Vector(L, u8), @splat(','));
    const is_underscore = chars == @as(@Vector(L, u8), @splat('_'));
    const is_hyphen = chars == @as(@Vector(L, u8), @splat('-'));

    const res1 = vector_or(L, is_space, is_slash);
    const res2 = vector_or(L, res1, is_period);
    const res3 = vector_or(L, res2, is_comma);
    const res4 = vector_or(L, res3, is_underscore);
    const res5 = vector_or(L, res4, is_hyphen);

    return res5;
}

test "preprocess_chars" {
    const chars: [8]u8 = [8]u8{ 'A', 'B', 'C', 'D', 'e', 'f', 'g', 'h' };
    const char_vec: @Vector(8, u8) = chars;
    const res = preprocess_chars(8, char_vec);

    try std.testing.expectEqual(res.is_upper, [_]bool{ true, true, true, true, false, false, false, false });
    try std.testing.expectEqual(res.is_lower, [_]bool{ false, false, false, false, true, true, true, true });
    try std.testing.expectEqual(res.lowered_chars, [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' });
}

test "delimiter" {
    const chars: [8]u8 = [8]u8{
        ' ',
        '/',
        '.',
        ',',
        '_',
        '-',
        'a',
        '1',
    };
    const res = build_is_delimiter_mask(8, chars);

    try std.testing.expectEqual(res, [_]bool{ true, true, true, true, true, true, false, false });
}
