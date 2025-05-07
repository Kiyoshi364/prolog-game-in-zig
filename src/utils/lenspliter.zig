const std = @import("std");

pub fn LenSpliter(comptime Int: type) type {
    const info = @typeInfo(Int);
    std.debug.assert(info == .int);
    const InnerInt = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = info.int.bits - switch (info.int.signedness) {
            .signed => 1,
            .unsigned => 0,
        },
    } });
    return struct {
        len: InnerInt,

        pub fn init(len: Int) @This() {
            return .{ .len = toInner(len) };
        }

        pub fn init_iterator(len: Int, splits: Int) Iterator {
            return @This().init(len).iterator(splits);
        }

        pub fn iterator(self: @This(), splits: Int) Iterator {
            return Iterator.init(toInner(splits), self.len);
        }

        fn toInner(i: Int) InnerInt {
            std.debug.assert(0 < i);
            return @intCast(i);
        }

        pub const Iterator = struct {
            base: InnerInt,
            rem: InnerInt,
            splits: InnerInt,
            i: InnerInt = 0,

            pub fn init(splits: InnerInt, len: InnerInt) Iterator {
                std.debug.assert(splits <= len);
                std.debug.assert(0 < splits);
                return .{
                    .base = len / splits,
                    .rem = len % splits,
                    .splits = splits,
                };
            }

            pub fn next(it: *Iterator) ?InnerInt {
                const State = enum { start, mid, last };
                const state: State = if (it.splits <= it.i)
                    return null
                else if (it.i < it.splits / 2)
                    .start
                else if (it.i < it.splits - it.splits / 2)
                    .mid
                else
                    .last;
                const off = @as(InnerInt, switch (state) {
                    .start => if (it.i < it.rem / 2) 1 else 0,
                    .mid => it.rem & 1,
                    .last => if (it.splits - it.rem / 2 <= it.i) 1 else 0,
                });
                it.*.i += 1;
                return it.base + off;
            }
        };
    };
}

test "LenSpliter preserves sum" {
    const len = 64;
    const spliter = LenSpliter(u8){ .len = len };
    for (1..(len + 1)) |splits| {
        const avg = len / splits;
        var sum = @as(usize, 0);
        var it = spliter.iterator(@intCast(splits));
        while (it.next()) |split| {
            try std.testing.expect(split == avg or split == avg + 1);
            sum += split;
        }
        try std.testing.expectEqual(len, sum);
    }
}
