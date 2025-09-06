const std = @import("std");
const scoring = @import("../scoring.zig");

const PreprocessedHaystackChar = struct {
    lowered: u8,
    is_lower: bool,
    is_upper: bool,
    is_delimiter: bool,
};

inline fn preprocess_char(char: u8) struct { lowered: u8, is_lower: bool, is_upper: bool } {
    const is_lower = char >= @as(u8, 'a') and char <= @as(u8, 'z');
    const is_upper = char >= @as(u8, 'A') and char <= @as(u8, 'Z');
    const lowered = if (is_upper) char + 32 else char;
    return .{ .lowered = lowered, .is_lower = is_lower, .is_upper = is_upper };
}

inline fn preprocess_haystack_char(char: u8) PreprocessedHaystackChar {
    const tmp = preprocess_char(char);
    return .{
        .lowered = tmp.lowered,
        .is_lower = tmp.is_lower,
        .is_upper = tmp.is_upper,
        .is_delimiter = is_delimiter(char),
    };
}

inline fn is_delimiter(char: u8) bool {
    return switch (char) {
        ' ', '/', '.', ',', '_', '-' => true,
        else => false,
    };
}

pub fn smith_waterman(
    allocator: std.mem.Allocator,
    needle: []const u8,
    haystack: []const u8,
) u16 {
    var prev_score = allocator.alloc(u16, haystack.len) catch unreachable;
    @memset(prev_score, 0);
    var max_score: u16 = 0;

    var preprocessed_haystack: []PreprocessedHaystackChar = undefined;
    for (haystack, 0..) |h, i| {
        preprocessed_haystack[i] = preprocess_haystack_char(h);
    }

    for (needle) |needle_char| {
        const preprocessed_needle_char = preprocess_char(needle_char);
        var insert_gap_penalty_mask = true;
        var delete_gap_penalty_mask = true;
        // True if last character in the haystack was a delimiter
        var delimiter_bonus_enabled_mask = false;
        var prev_haystack_is_delimiter = false;

        var curr_score = allocator.alloc(u16, haystack.len) catch unreachable;

        for (preprocessed_haystack, 0..) |haystack_char, haystack_idx| {
            const up = prev_score[haystack_idx];
            const left = if (haystack_idx == 0) 0 else curr_score[haystack_idx - 1];
            const diag = if (haystack_idx == 0) 0 else prev_score[haystack_idx - 1];

            const match_mask = preprocessed_needle_char.lowered == haystack_char.lowered;
            const matched_casing_mask = preprocessed_needle_char.is_upper == haystack_char.is_upper;
            const match_score = if (haystack_idx > 0) block: {
                const prev_haystack_char = preprocessed_haystack[haystack_idx - 1];
                // Bonus if we match on an uppercase letter that succeeds a lowercase letter
                const capitalisation_mask = haystack_char.is_upper and prev_haystack_char.is_upper;
                const capitalisation_bonus = if (capitalisation_mask) scoring.CAPITALIZATION_BONUS else 0;
                const delimiter_bonus_mask =
                    prev_haystack_is_delimiter and
                    delimiter_bonus_enabled_mask and
                    !haystack_char.is_delimiter;
                const delimiter_bonus = if (delimiter_bonus_mask) scoring.DELIMITER_BONUS else 0;

                // TODO: add offset prefix bonus, the way it currently is I don't think
                // it's worth adding.
                break :block capitalisation_bonus + delimiter_bonus + scoring.MATCH_SCORE;
            } else
                // TODO: wtf why can't it detect the type
                scoring.PREFIX_BONUS + scoring.MATCH_SCORE;
            const diag_score = if (match_mask) blk: {
                // TODO: lmao this syntax is so ridiculous
                break :blk diag + match_score + (if (matched_casing_mask) scoring.MATCHING_CASE_BONUS else 0);
            } else diag -| scoring.MISMATCH_PENALTY;

            // Insert a character not in haystack
            const insert_gap_penalty = if (insert_gap_penalty_mask) scoring.GAP_OPEN_PENALTY else scoring.GAP_EXTEND_PENALTY;
            const insert_score = up -| insert_gap_penalty;

            // Delete a character in haystack
            const delete_gap_penalty = if (delete_gap_penalty_mask) scoring.GAP_OPEN_PENALTY else scoring.GAP_EXTEND_PENALTY;
            const delete_score = left -| delete_gap_penalty;

            const diag_mask = max_score == diag_score;
            delete_gap_penalty_mask = max_score != delete_score or diag_mask;
            insert_gap_penalty_mask = max_score != insert_score or diag_mask;

            // Delimiter bonus is only enabled after we encounter a non-delimiter
            delimiter_bonus_enabled_mask = delimiter_bonus_enabled_mask or !haystack_char.is_delimiter;

            curr_score[haystack_idx] = max_score;

            prev_haystack_is_delimiter = haystack_char.is_delimiter;

            max_score = @max(max_score, curr_score[haystack_idx]);
        }
        allocator.free(prev_score);
        prev_score = curr_score;
    }

    allocator.free(prev_score);
    // TODO: add exact match bonus
    return max_score;
}
