const std = @import("std");
const simd_search = @import("simd/search.zig");

const ArrayList = std.ArrayList;

pub const Match = struct { idx: usize, score: u16 };

fn BucketItem(comptime W: usize) type {
    return struct { idx: usize, str: [W]u8 };
}

fn Bucket(comptime W: usize) type {
    return struct {
        items: ArrayList(BucketItem(W)),
    };
}

const Matcher = struct {
    // TODO: see if I need to add more smaller buckets
    bucket_8: Bucket(8),
    bucket_16: Bucket(16),
    bucket_32: Bucket(32),
    bucket_64: Bucket(64),
    bucket_128: Bucket(128),
    bucket_256: Bucket(256),
    bucket_512: Bucket(512),

    fn init(allocator: std.mem.Allocator) Matcher {
        return Matcher{
            .bucket_8 = Bucket(8){ .items = ArrayList(BucketItem(8)).init(allocator) },
            .bucket_16 = Bucket(16){ .items = ArrayList(BucketItem(16)).init(allocator) },
            .bucket_32 = Bucket(32){ .items = ArrayList(BucketItem(32)).init(allocator) },
            .bucket_64 = Bucket(64){ .items = ArrayList(BucketItem(64)).init(allocator) },
            .bucket_128 = Bucket(128){ .items = ArrayList(BucketItem(128)).init(allocator) },
            .bucket_256 = Bucket(256){ .items = ArrayList(BucketItem(256)).init(allocator) },
            .bucket_512 = Bucket(512){ .items = ArrayList(BucketItem(512)).init(allocator) },
        };
    }
    fn deinit(m: Matcher) void {
        m.bucket_8.items.deinit();
        m.bucket_16.items.deinit();
        m.bucket_32.items.deinit();
        m.bucket_64.items.deinit();
        m.bucket_128.items.deinit();
        m.bucket_256.items.deinit();
        m.bucket_512.items.deinit();
    }
};

inline fn pad_str(comptime W: usize, str: []const u8) [W]u8 {
    var arr: [W]u8 = std.mem.zeroes([W]u8);
    @memcpy(arr[0..str.len], str);

    return arr;
}

fn find_needle_in_bucket(comptime W: usize, needle: []const u8, bucket: Bucket(W), scores: *ArrayList(Match)) void {
    const L = std.simd.suggestVectorLength(u16).?;
    var i: usize = 0;
    const arr = bucket.items.items;
    while (i < arr.len) : (i += L) {
        const chunk_end = @min(i + @as(usize, @intCast(L)), arr.len);
        // const haystack: [L][]const u8 = std.mem.zeroes([]const u8);
        var haystack: [L][W]u8 = [_][W]u8{[_]u8{0} ** W} ** L;
        const chunk = arr[i..chunk_end];
        for (0..chunk.len) |j| {
            @memcpy(&haystack[j], &chunk[j].str);
        }
        const res = simd_search.smith_waterman(W, L, needle, haystack);
        for (0..chunk.len) |j| {
            scores.append(Match{ .score = res[j], .idx = chunk[j].idx }) catch unreachable;
        }
    }
}

fn find_needle_in_matcher(needle: []const u8, matcher: Matcher, scores: *ArrayList(Match)) void {
    find_needle_in_bucket(8, needle, matcher.bucket_8, scores);
    find_needle_in_bucket(16, needle, matcher.bucket_16, scores);
    find_needle_in_bucket(32, needle, matcher.bucket_32, scores);
    find_needle_in_bucket(64, needle, matcher.bucket_64, scores);
    find_needle_in_bucket(128, needle, matcher.bucket_128, scores);
    find_needle_in_bucket(256, needle, matcher.bucket_256, scores);
    find_needle_in_bucket(512, needle, matcher.bucket_512, scores);
}

fn new_matcher(allocator: std.mem.Allocator, haystacks: [][]const u8) Matcher {
    var matcher = Matcher.init(allocator);

    // TODO: if we are doing the padding here, don't do it inside, its probably to do it here
    // since we have the length, i.e. we can inject it into the type
    for (0..haystacks.len) |idx| {
        const haystack = haystacks[idx];

        switch (haystack.len) {
            1...8 => {
                matcher.bucket_8.items.append(BucketItem(8){ .idx = idx, .str = pad_str(8, haystack) }) catch unreachable;
            },
            9...16 => {
                matcher.bucket_16.items.append(BucketItem(16){ .idx = idx, .str = pad_str(16, haystack) }) catch unreachable;
            },
            17...32 => {
                matcher.bucket_32.items.append(BucketItem(32){ .idx = idx, .str = pad_str(32, haystack) }) catch unreachable;
            },
            33...64 => {
                matcher.bucket_64.items.append(BucketItem(64){ .idx = idx, .str = pad_str(64, haystack) }) catch unreachable;
            },
            65...128 => {
                matcher.bucket_128.items.append(BucketItem(128){ .idx = idx, .str = pad_str(128, haystack) }) catch unreachable;
            },
            129...256 => {
                matcher.bucket_256.items.append(BucketItem(256){ .idx = idx, .str = pad_str(256, haystack) }) catch unreachable;
            },
            257...512 => {
                matcher.bucket_512.items.append(BucketItem(512){ .idx = idx, .str = pad_str(512, haystack) }) catch unreachable;
            },
            else => {},
        }
    }

    return matcher;
}

pub fn run(allocator: std.mem.Allocator, needle: []const u8, haystacks: [][]const u8) ArrayList(Match) {
    var scores = ArrayList(Match).init(allocator);

    const matcher = new_matcher(allocator, haystacks);
    defer Matcher.deinit(matcher);

    find_needle_in_matcher(needle, matcher, &scores);

    return scores;
}
