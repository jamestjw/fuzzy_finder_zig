const std = @import("std");

pub inline fn pad_str(comptime W: usize, str: []const u8) [W]u8 {
    var arr: [W]u8 = std.mem.zeroes([W]u8);
    @memcpy(arr[0..str.len], str);

    return arr;
}

pub fn get_files_in_dir(
    allocator: std.mem.Allocator,
    path: []const u8,
) !std.ArrayList([]const u8) {
    var files = std.ArrayList([]const u8).init(allocator);

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const full_path = try allocator.dupe(u8, entry.path);
            try files.append(full_path);
        }
    }

    return files;
}
