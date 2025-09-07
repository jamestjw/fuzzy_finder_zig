const std = @import("std");
const interleave = @import("./simd/interleave.zig");
const search = @import("./search.zig");
const utils = @import("./utils.zig");

const DEFAULT_DIR = "./";

fn parse_args(allocator: std.mem.Allocator) struct { query: []const u8, directory: []const u8, use_simd: bool } {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var query_arg: ?[]const u8 = null;
    var directory: []const u8 = DEFAULT_DIR;
    var use_simd: bool = true;

    const prog_name = args.next().?;

    // --- Parsing Loop ---
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--simd")) {
            if (args.next()) |value_str| {
                if (std.mem.eql(u8, value_str, "false")) {
                    use_simd = false;
                } else if (std.mem.eql(u8, value_str, "true")) {
                    use_simd = true;
                } else {
                    std.debug.print("Error: Invalid value for --simd: '{s}'. Expected 'true' or 'false'.\n", .{value_str});
                    std.process.exit(1);
                }
            } else {
                std.debug.print("Error: --simd option requires a value ('true' or 'false').\n", .{});
                std.process.exit(1);
            }
        }
        // Then, handle positional arguments by order
        else if (query_arg == null) {
            // This is the first positional argument we've seen, so it must be the 'tool'
            query_arg = arg;
        } else if (std.mem.eql(u8, directory, DEFAULT_DIR)) {
            // 'query' is already set, so this must be the optional 'directory'
            directory = arg;
        } else {
            // We already have a tool and a directory, so this is an unknown argument
            std.debug.print("Error: Unexpected positional argument: '{s}'\n", .{arg});
            std.process.exit(1);
        }
    }

    // --- Validation ---
    const query = query_arg orelse {
        std.debug.print("Usage: {s} <query> [directory] [--simd <true|false>]\n", .{prog_name});
        std.debug.print("Error: Missing required <query> argument.\n", .{});
        std.process.exit(1);
    };

    return .{ .query = query, .directory = directory, .use_simd = use_simd };
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = parse_args(allocator);

    const files = try utils.get_files_in_dir(allocator, args.directory);
    const matches =
        if (args.use_simd)
            search.run(allocator, args.query, files.items)
        else
            search.run_no_simd(allocator, args.query, files.items);
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

test {
    std.testing.refAllDecls(@This());
}
