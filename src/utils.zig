const std = @import("std");

pub fn Buffer(comptime T: type, comptime Idx: type, comptime capacity: Idx) type {
    std.debug.assert(@typeInfo(Idx) == .int);
    std.debug.assert(0 <= capacity);
    return struct {
        buffer: [capacity]T = undefined,
        size: Idx = 0,

        const Self = @This();

        pub fn len(self: Self) Idx {
            _ = self;
            return capacity;
        }

        pub fn slice(self: *const Self) []const T {
            return self.buffer[0..self.size];
        }

        pub fn get(self: *const Self, i: Idx) T {
            return self.slice()[i];
        }

        pub fn opt_push(self: *const Self, item: T) ?Self {
            return self.opt_push_slice(&.{item});
        }

        pub fn opt_push_slice(self: *const Self, items: []const T) ?Self {
            var b = self.as_builder();
            return if (b.opt_push_slice_mut(items)) |v| blk: {
                std.debug.assert(v == {});
                break :blk b.frozen();
            } else null;
        }

        pub fn push(self: *const Self, item: T) Self {
            return self.push_slice(&.{item});
        }

        pub fn push_slice(self: *const Self, items: []const T) Self {
            var b = self.as_builder();
            b.push_slice_mut(items);
            return b.frozen();
        }

        pub fn replace(self: *const Self, target: Idx, item: T) Self {
            var b = self.as_builder();
            b.replace(target, item);
            return b.frozen();
        }

        pub fn as_builder(self: Self) Builder {
            var b = Builder{};
            b.push_slice_mut(self.slice());
            return b;
        }

        pub const Builder = struct {
            b: Self = .{},

            pub fn frozen(builder: Builder) Self {
                return builder.b;
            }

            pub fn slice_mut(builder: *Builder) []T {
                return builder.b.buffer[0..builder.b.size];
            }

            pub fn opt_push_mut(builder: *Builder, item: T) ?void {
                return builder.opt_push_slice_mut(&.{item});
            }

            pub fn opt_push_slice_mut(builder: *Builder, items: []const T) ?void {
                return if (builder.b.size + items.len < capacity)
                    builder.push_slice_mut(items)
                else
                    null;
            }

            pub fn push_mut(builder: *Builder, item: T) void {
                return builder.push_slice_mut(&.{item});
            }

            pub fn push_slice_mut(builder: *Builder, items: []const T) void {
                std.debug.assert(builder.b.size + items.len < capacity);
                const buffer = builder.b.buffer[builder.b.size..];
                for (buffer[0..items.len], items) |*d, s| {
                    d.* = s;
                }
                builder.b.size += @intCast(items.len);
            }

            pub fn replace(builder: *Builder, target: Idx, item: T) void {
                std.debug.assert(target < builder.b.size);
                builder.b.buffer[target] = item;
            }
        };
    };
}

pub fn LenSpliter(comptime Int: type) type {
    std.debug.assert(@typeInfo(Int) == .int);
    return struct {
        len: Int,

        pub fn iterator(self: @This(), splits: Int) Iterator {
            return Iterator.init(splits, self.len);
        }

        pub const Iterator = struct {
            base: Int,
            rem: Int,
            splits: Int,
            i: Int = 0,

            pub fn init(splits: Int, len: Int) Iterator {
                std.debug.assert(splits <= len);
                std.debug.assert(0 < splits);
                return .{
                    .base = len / splits,
                    .rem = len % splits,
                    .splits = splits,
                };
            }

            pub fn next(it: *Iterator) ?Int {
                const State = enum { start, mid, last };
                const state: State = if (it.splits <= it.i)
                    return null
                else if (it.i < it.splits/2)
                    .start
                else if (it.i < it.splits - it.splits/2)
                    .mid
                else
                    .last;
                const off = @as(Int, switch (state) {
                    .start => if (it.i < it.rem/2) 1 else 0,
                    .mid => it.rem & 1,
                    .last => if (it.splits - it.rem/2 <= it.i) 1 else 0,
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
    for (1..(len+1)) |splits| {
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
