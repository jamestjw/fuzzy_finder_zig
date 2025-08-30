const std = @import("std");
const interleave = @import("./simd/interleave.zig");
const search = @import("./search.zig");
const utils = @import("./utils.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    if (argv.len < 2) {
        std.debug.print("Usage: {s} <query> [search-dir]\n", .{argv[0]});
        return; // Exit if no query is provided
    }

    const query = argv[1];
    var search_dir: []const u8 = "./";

    if (argv.len >= 3) {
        search_dir = argv[2];
    }

    const files = try utils.get_files_in_dir(allocator, search_dir);
    const matches = search.run(allocator, query, files.items);
    defer matches.deinit();

    std.mem.sort(search.Match, matches.items, {}, struct {
        fn cmp(_: void, a: search.Match, b: search.Match) bool {
            return a.score < b.score;
        }
    }.cmp);

    for (matches.items) |match| {
        std.debug.print("Score: {d}, Path: {s}\n", .{
            match.score,
            files.items[match.idx],
        });
    }
}
