const std = @import("std");
const regular_search = @import("algorithm/search.zig");
const simd_search = @import("simd/search.zig");
const utils = @import("utils.zig");

fn get_simd_score(needle: []const u8, haystack: []const u8) u16 {
    std.testing.expect(haystack.len <= 16) catch unreachable;
    const res = simd_search.smith_waterman(16, 1, needle, [_][16]u8{utils.pad_str(16, haystack)});
    return res[0];
}

fn test_search(allocator: std.mem.Allocator, needle: []const u8, haystack: []const u8) !void {
    const simd_score = get_simd_score(needle, haystack);
    const regular_score = regular_search.smith_waterman(allocator, needle, haystack);
    try std.testing.expectEqual(simd_score, regular_score);
}

test {
    const allocator = std.testing.allocator;
    try test_search(allocator, "b", "abc");
    try test_search(allocator, "c", "abc");
    try test_search(allocator, "a", "abc");
    try test_search(allocator, "a", "aabc");
    try test_search(allocator, "a", "babc");
    try test_search(allocator, "-", "a--bc");
    try test_search(allocator, "b", "a--bc");
    try test_search(allocator, "a", "a--bc");
    try test_search(allocator, "a", "-a--bc");
    try test_search(allocator, "a_b", "a_bb");
    try test_search(allocator, "a_b", "a__b");
    try test_search(allocator, "hello", "Aheello");
    try test_search(allocator, "hello", "Aheeello");
    try test_search(allocator, "h", "Hello");
    try test_search(allocator, "H", "Hello");
    try test_search(allocator, "H", "aaHello");
    try test_search(allocator, "H", "AHello");
    try test_search(allocator, "H", "A_Hello");
    try test_search(allocator, "hii", "hiii");
    try test_search(allocator, "hii", "hi_i_i");
    try test_search(allocator, "hi", "hii");
    try test_search(allocator, "hi", "hxIi");
}
