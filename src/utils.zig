const std = @import("std");

pub const Buffer = @import("utils/buffer.zig").Buffer;
pub const LenSpliter = @import("utils/lenspliter.zig").LenSpliter;

test "utils.refAllDeclsRecursive" {
    std.testing.refAllDeclsRecursive(Buffer(u8, u4, 10));
    std.testing.refAllDeclsRecursive(LenSpliter(u8));
}
