const std = @import("std");
const ArrayList = std.ArrayList;

const Match = struct { score: u16 };

fn BucketItem(comptime W: u8) type {
    return struct { idx: usize, str: [W]u8 };
}

fn Bucket(comptime W: u8) type {
    return struct {
        // W: usize,
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
};

inline fn pad_str(comptime W: usize, str: []const u8) [W]u8 {
    var array: [W]u8 = std.mem.zeroes([W]u8);
    std.mem.copy(u8, &array, str);

    return array;
}

fn new_matcher(haystacks: [][]const u8) Matcher {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var matcher = Matcher{
        .bucket_8 = Bucket(8){ .items = ArrayList([8]u8).init(allocator) },
        .bucket_16 = Bucket(16){ .items = ArrayList([16]u8).init(allocator) },
        .bucket_32 = Bucket(32){ .items = ArrayList([32]u8).init(allocator) },
        .bucket_64 = Bucket(64){ .items = ArrayList([64]u8).init(allocator) },
        .bucket_128 = Bucket(128){ .items = ArrayList([128]u8).init(allocator) },
        .bucket_256 = Bucket(256){ .items = ArrayList([256]u8).init(allocator) },
        .bucket_512 = Bucket(512){ .items = ArrayList([512]u8).init(allocator) },
    };

    for (0..haystacks.len) |idx| {
        const haystack = haystacks[idx];

        switch (haystack.len) {
            1...8 => {
                matcher.bucket_8.append(BucketItem(8){ .idx = idx, .str = pad_str(8, haystack) }) catch unreachable;
            },
            9...16 => {
                matcher.bucket_16.append(BucketItem(16){ .idx = idx, .str = pad_str(16, haystack) }) catch unreachable;
            },
            17...32 => {
                matcher.bucket_32.append(BucketItem(32){ .idx = idx, .str = pad_str(32, haystack) }) catch unreachable;
            },
            33...64 => {
                matcher.bucket_64.append(BucketItem(64){ .idx = idx, .str = pad_str(64, haystack) }) catch unreachable;
            },
            65...128 => {
                matcher.bucket_128.append(BucketItem(128){ .idx = idx, .str = pad_str(128, haystack) }) catch unreachable;
            },
            129...256 => {
                matcher.bucket_256.append(BucketItem(256){ .idx = idx, .str = pad_str(256, haystack) }) catch unreachable;
            },
            257...512 => {
                matcher.bucket_512.append(BucketItem(512){ .idx = idx, .str = pad_str(512, haystack) }) catch unreachable;
            },
            else => {},
        }
    }
}
