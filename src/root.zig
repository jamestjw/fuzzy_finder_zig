//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
pub const simd_interleave = @import("simd/interleave.zig");
pub const simd_search = @import("simd/search.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
