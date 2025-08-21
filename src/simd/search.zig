const std = @import("std");
const interleave_lib = @import("interleave.zig");
const scoring = @import("../scoring.zig");

fn ProcessedCharVec(comptime L: usize) type {
    return struct {
        lowered_chars: @Vector(L, u8),
        is_lower: @Vector(L, bool),
        is_upper: @Vector(L, bool),
    };
}

fn ProcessedHaystackCharVec(comptime L: usize) type {
    return struct {
        lowered_chars: @Vector(L, u8),
        is_lower: @Vector(L, bool),
        is_upper: @Vector(L, bool),
        is_delimiter: @Vector(L, bool),
    };
}

inline fn vector_and(
    comptime L: usize,
    v1: @Vector(L, bool),
    v2: @Vector(L, bool),
) @Vector(L, bool) {
    return @select(bool, v1, v2, v1);
}

inline fn vector_and3(
    comptime L: usize,
    v1: @Vector(L, bool),
    v2: @Vector(L, bool),
    v3: @Vector(L, bool),
) @Vector(L, bool) {
    return vector_and(L, vector_and(L, v1, v2), v3);
}

inline fn vector_or(
    comptime L: usize,
    v1: @Vector(L, bool),
    v2: @Vector(L, bool),
) @Vector(L, bool) {
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

fn preprocess_haystack_chars(comptime L: usize, chars: @Vector(L, u8)) ProcessedCharVec(L) {
    const processed = preprocess_chars(L, chars);

    return ProcessedHaystackCharVec(L){ .lowered_chars = processed.lowered_chars, .is_lower = processed.is_lower, .is_upper = processed.is_upper, .is_delimiter = build_is_delimiter_mask(L, chars) };
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

inline fn smith_waterman_inner(
    comptime W: usize,
    comptime L: usize,
    needle: ProcessedCharVec(L),
    haystack: [W]ProcessedHaystackCharVec(L),
    prev_score: [W]@Vector(L, u16),
) [W]@Vector(L, u16) {
    const capitalisation_bonus_vec: @Vector(L, u16) = @splat(scoring.CAPITALIZATION_BONUS);
    const delimiter_bonus_vec: @Vector(L, u16) = @splat(scoring.DELIMITER_BONUS);
    const zeroes: @Vector(L, u16) = @splat(0);

    // True if the gap wasn't open wrt to last iteration's best score
    var insert_gap_penalty_mask: @Vector(L, bool) = @splat(true);
    var delete_gap_penalty_mask: @Vector(L, bool) = @splat(true);
    // True if last character in the haystack was a delimiter
    var delimiter_bonus_enabled_mask: @Vector(L, bool) = @splat(false);
    var prev_haystack_is_delimiter: @Vector(L, bool) = @splat(false);

    for (0..W) |haystack_idx| {
        const haystack_char = haystack[haystack_idx];
        const up = prev_score[haystack_idx];
        const diag: @Vector(L, u16) = if (haystack_idx == 0) {
            // TODO: wtf why can't it detect the type
            zeroes;
        } else {
            prev_score[haystack_idx];
        };
        const match_mask = needle.lowered_chars == haystack_char.lowered_chars;
        const matched_casing_mask = needle.is_upper == haystack_char.is_upper;
        const match_score: @Vector(L, u16) = if (haystack_idx > 0) {
            const prev_haystack_char = haystack_idx[haystack_idx - 1];
            // Bonus if we match on an uppercase letter that succeeds a lowercase letter
            const capitalisation_mask = vector_and(L, haystack_char.is_upper, prev_haystack_char.is_lower);
            const capitalisation_bonus = @select(u16, capitalisation_mask, capitalisation_bonus_vec, zeroes);
            const delimiter_bonus_mask = vector_and3(
                L,
                prev_haystack_is_delimiter,
                delimiter_bonus_enabled_mask,
                !haystack_char.is_delimiter,
            );
            const delimiter_bonus = @select(u16, delimiter_bonus_mask, delimiter_bonus_vec, zeroes);

            // TODO: add offset prefix bonus, the way it currently is I don't think
            // it's worth adding.
            capitalisation_bonus + delimiter_bonus + @as(@Vector(L, u16), @splat(scoring.MATCH_SCORE));
        } else {
            // TODO: wtf why can't it detect the type
            @as(@Vector(L, u16), @splat(scoring.PREFIX_BONUS + scoring.MATCH_SCORE));
        };
    }
}

fn smith_waterman(
    comptime W: usize,
    comptime L: usize,
    needle: []u8,
    haystack: [L][]const u8,
) void {
    const interleaved_haystack = interleave_lib.interleave(W, L, haystack);
    const processed_haystack: [W]ProcessedHaystackCharVec(L) = undefined;

    for (interleaved_haystack, 0..) |h, i| {
        processed_haystack[i] = preprocess_haystack_chars(L, h);
    }

    var prev_score_col = [_]@Vector(L, u16){@splat(0)} ** W;
    var max_scores: @Vector(L, u16) = @splat(0);

    for (0..needle.len) |needle_idx| {
        const needle_char = preprocess_chars(L, @splat(needle[needle_idx]));
        prev_score_col = smith_waterman_inner(
            W,
            L,
            needle_char,
            processed_haystack,
            prev_score_col,
        );
        max_scores = @max(max_scores, prev_score_col);
    }
    // TODO: add bonus score for exact match

    return max_scores;
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
