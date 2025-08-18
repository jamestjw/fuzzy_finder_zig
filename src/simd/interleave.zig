const std = @import("std");

pub fn interleave(comptime W: usize, comptime L: usize, strs: [L][]const u8) ![W]@Vector(L, u8) {
    var strs_padded: [L][W]u8 = undefined;

    for (0..L) |i| {
        const str = strs[i];
        strs_padded[i] = std.mem.zeroes([W]u8);
        @memcpy(strs_padded[i][0..str.len], str);
    }

    const num_chunks: usize = try std.math.divCeil(usize, W, L);
    var interleaved = std.mem.zeroes([W]@Vector(L, u8));

    for (0..num_chunks) |i| {
        const offset = i * L;
        var vecs: [L]@Vector(L, u8) = to_vec(W, L, strs_padded, offset);
        interleave_chunk(L, &vecs);

        if (offset + L > W) {
            // Final chunk
            @memcpy(interleaved[offset..W], vecs[0..(W - offset)]);
        } else {
            // Rest chunk
            @memcpy(interleaved[offset..(offset + L)], &vecs);
        }
    }

    return interleaved;
}

fn interleave_chunk(comptime L: usize, vecs: *[L]@Vector(L, u8)) void {
    var distance = L / 2;

    while (distance > 0) : (distance /= 2) {
        for (0..L) |base| {
            if ((base & distance) == 0) {
                const pair_idx = base + distance;
                if (pair_idx < L) {
                    const new_base, const new_pair = _interleave(L, u8, vecs[base], vecs[pair_idx]);
                    vecs.*[base] = new_base;
                    vecs.*[pair_idx] = new_pair;
                }
            }
        }
    }
}

fn _interleave(comptime len: usize, comptime T: type, a: @Vector(len, T), b: @Vector(len, T)) [2]@Vector(len, T) {
    const half_len = len / 2;

    // Generate the shuffle masks at compile time.
    const masks = comptime blk: {
        var low_mask: [len]i32 = undefined;
        var high_mask: [len]i32 = undefined;

        for (&low_mask, 0..) |*elem, i| {
            if (i % 2 == 0) {
                elem.* = @as(i32, i / 2); // from a's lower half
            } else {
                elem.* = ~@as(i32, i / 2); // from b's lower half
            }
        }

        for (&high_mask, 0..) |*elem, i| {
            if (i % 2 == 0) {
                elem.* = @as(i32, half_len + (i / 2)); // from a's upper half
            } else {
                elem.* = ~@as(i32, half_len + (i / 2)); // from b's upper half
            }
        }
        break :blk .{ low_mask, high_mask };
    };

    const interleaved_low = @shuffle(T, a, b, masks[0]);
    const interleaved_high = @shuffle(T, a, b, masks[1]);

    return .{ interleaved_low, interleaved_high };
}

inline fn to_vec(comptime W: usize, comptime L: usize, strs: [L][W]u8, offset: usize) [L]@Vector(L, u8) {
    var res: [L]@Vector(L, u8) = undefined;

    for (0..L) |i| {
        var data: [L]u8 = std.mem.zeroes([L]u8);

        if (offset + L < W) {
            @memcpy(&data, strs[i][offset..(offset + L)]);
        } else {
            const bytes = strs[i][offset..W];
            @memcpy(data[0..bytes.len], bytes);
        }

        res[i] = data;
    }

    return res;
}

const testing = std.testing;

test "interleave" {
    const words = [16][]const u8{
        "apple", "bravo", "crane", "delta",
        "early", "frost", "grape", "haste",
        "ivory", "jumbo", "karma", "lemon",
        "magic", "noble", "ocean", "prize",
    };
    var transposed: [5][16]u8 = undefined;

    for (0..5) |col| {
        for (0..16) |row| {
            transposed[col][row] = words[row][col];
        }
    }

    const interleaved = try interleave(5, 16, words);
    var interleaved_array: [5][16]u8 = undefined;

    for (0..5) |i| {
        interleaved_array[i] = interleaved[i];
    }

    try std.testing.expectEqual(interleaved_array, transposed);
}
