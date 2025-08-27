const std = @import("std");
const utils = @import("../utils.zig");
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

inline fn vector_not(
    comptime L: usize,
    v: @Vector(L, bool),
) @Vector(L, bool) {
    return @select(bool, v, @as(@Vector(L, bool), @splat(false)), @as(@Vector(L, bool), @splat(true)));
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

fn preprocess_haystack_chars(comptime L: usize, chars: @Vector(L, u8)) ProcessedHaystackCharVec(L) {
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
    const matched_case_bonus_vec: @Vector(L, u16) = @splat(scoring.MATCHING_CASE_BONUS);
    const mismatch_penalty_vec: @Vector(L, u16) = @splat(scoring.MISMATCH_PENALTY);
    const gap_open_penalty_vec: @Vector(L, u16) = @splat(scoring.GAP_OPEN_PENALTY);
    const gap_extend_penalty_vec: @Vector(L, u16) = @splat(scoring.GAP_EXTEND_PENALTY);
    const zeroes: @Vector(L, u16) = @splat(0);

    // True if the gap wasn't open wrt to last iteration's best score
    var insert_gap_penalty_mask: @Vector(L, bool) = @splat(true);
    var delete_gap_penalty_mask: @Vector(L, bool) = @splat(true);
    // True if last character in the haystack was a delimiter
    var delimiter_bonus_enabled_mask: @Vector(L, bool) = @splat(false);
    var prev_haystack_is_delimiter: @Vector(L, bool) = @splat(false);
    var curr_score: [W]@Vector(L, u16) = undefined;

    for (0..W) |haystack_idx| {
        const haystack_char = haystack[haystack_idx];
        const up = prev_score[haystack_idx];
        const left: @Vector(L, u16) = if (haystack_idx == 0)
            zeroes
        else
            curr_score[haystack_idx - 1];

        const diag: @Vector(L, u16) = if (haystack_idx == 0)
            // TODO: wtf why can't it detect the type
            zeroes
        else
            prev_score[haystack_idx - 1];

        const match_mask = needle.lowered_chars == haystack_char.lowered_chars;
        const matched_casing_mask = needle.is_upper == haystack_char.is_upper;
        const match_score: @Vector(L, u16) = if (haystack_idx > 0) block: {
            const prev_haystack_char = haystack[haystack_idx - 1];
            // Bonus if we match on an uppercase letter that succeeds a lowercase letter
            const capitalisation_mask = vector_and(L, haystack_char.is_upper, prev_haystack_char.is_lower);
            const capitalisation_bonus = @select(u16, capitalisation_mask, capitalisation_bonus_vec, zeroes);
            const delimiter_bonus_mask = vector_and3(
                L,
                prev_haystack_is_delimiter,
                delimiter_bonus_enabled_mask,
                vector_not(L, haystack_char.is_delimiter),
            );
            const delimiter_bonus = @select(u16, delimiter_bonus_mask, delimiter_bonus_vec, zeroes);

            // TODO: add offset prefix bonus, the way it currently is I don't think
            // it's worth adding.
            break :block capitalisation_bonus + delimiter_bonus + @as(@Vector(L, u16), @splat(scoring.MATCH_SCORE));
        } else
            // TODO: wtf why can't it detect the type
            @as(@Vector(L, u16), @splat(scoring.PREFIX_BONUS + scoring.MATCH_SCORE));

        const diag_matched_score = diag + match_score + @select(
            u16,
            matched_casing_mask,
            matched_case_bonus_vec,
            zeroes,
        );
        const diag_unmatched_score = diag -| mismatch_penalty_vec;
        const diag_score = @select(u16, match_mask, diag_matched_score, diag_unmatched_score);

        // Insert a character not in haystack
        const insert_gap_penalty = @select(u16, insert_gap_penalty_mask, gap_open_penalty_vec, gap_extend_penalty_vec);
        const insert_score = up -| insert_gap_penalty;

        // Delete a character in haystack
        const delete_gap_penalty = @select(u16, delete_gap_penalty_mask, gap_open_penalty_vec, gap_extend_penalty_vec);
        const delete_score = left -| delete_gap_penalty;

        const max_score = @max(diag_score, insert_score, delete_score);

        const diag_mask = max_score == diag_score;
        delete_gap_penalty_mask = vector_or(L, max_score != delete_score, diag_mask);
        insert_gap_penalty_mask = vector_or(L, max_score != insert_score, diag_mask);

        // Delimiter bonus is only enabled after we encounter a non-delimiter
        delimiter_bonus_enabled_mask = vector_or(L, delimiter_bonus_enabled_mask, vector_not(L, haystack_char.is_delimiter));

        curr_score[haystack_idx] = max_score;

        prev_haystack_is_delimiter = haystack_char.is_delimiter;
    }

    return curr_score;
}

pub fn smith_waterman(
    comptime W: usize,
    comptime L: usize,
    needle: []const u8,
    haystack: [L][W]u8,
) [L]u16 {
    const interleaved_haystack = interleave_lib.interleave(W, L, haystack);
    var processed_haystack: [W]ProcessedHaystackCharVec(L) = undefined;

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
        for (0..W) |j| {
            max_scores = @max(max_scores, prev_score_col[j]);
        }
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

fn get_score(needle: []const u8, haystack: []const u8) u16 {
    const res = smith_waterman(16, 1, needle, [_][16]u8{utils.pad_str(16, haystack)});
    return res[0];
}

const matching_char_score = scoring.MATCH_SCORE + scoring.MATCHING_CASE_BONUS;

test "basic match" {
    try std.testing.expectEqual(get_score("b", "abc"), matching_char_score);
    try std.testing.expectEqual(get_score("c", "abc"), matching_char_score);
}

test "prefix bonus" {
    try std.testing.expectEqual(get_score("a", "abc"), matching_char_score + scoring.PREFIX_BONUS);
    try std.testing.expectEqual(get_score("a", "aabc"), matching_char_score + scoring.PREFIX_BONUS);
    try std.testing.expectEqual(get_score("a", "babc"), matching_char_score);
}

test "delimiter bonus" {
    try std.testing.expectEqual(get_score("-", "a--bc"), matching_char_score);
    try std.testing.expectEqual(get_score("b", "a--bc"), matching_char_score + scoring.DELIMITER_BONUS);
    try std.testing.expectEqual(get_score("a", "a--bc"), matching_char_score + scoring.PREFIX_BONUS);
    try std.testing.expectEqual(get_score("a", "-a--bc"), matching_char_score);
    try std.testing.expect(get_score("a_b", "a_bb") > get_score("a_b", "a__b"));
}

test "affine gaps" {
    // one wrong chars
    try std.testing.expectEqual(get_score("hello", "Aheello"), matching_char_score * 5 - scoring.GAP_OPEN_PENALTY);
    // two wrong chars
    try std.testing.expectEqual(get_score("hello", "Aheeello"), matching_char_score * 5 - scoring.GAP_OPEN_PENALTY - scoring.GAP_EXTEND_PENALTY);
}

test "capital bonus" {
    try std.testing.expectEqual(get_score("h", "Hello"), scoring.MATCH_SCORE + scoring.PREFIX_BONUS);
    try std.testing.expectEqual(get_score("H", "Hello"), matching_char_score + scoring.PREFIX_BONUS);
    try std.testing.expectEqual(get_score("H", "aaHello"), matching_char_score + scoring.CAPITALIZATION_BONUS);
    try std.testing.expectEqual(get_score("H", "AHello"), matching_char_score);
    try std.testing.expectEqual(get_score("H", "A_Hello"), matching_char_score + scoring.DELIMITER_BONUS);
}

test "continuous > delimiter" {
    try std.testing.expect(get_score("hii", "hiii") > get_score("hii", "hi_i_i"));
}

test "continuous > capitalisation" {
    // better to not have mismatches than to match on a capital letter after incurring
    // one mismatch
    try std.testing.expect(get_score("hi", "hii") > get_score("hi", "hxIi"));
}
