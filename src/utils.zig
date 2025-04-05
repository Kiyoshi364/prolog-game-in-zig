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
        pub fn slice_mut(self: *Self) []T {
            return self.buffer[0..self.size];
        }
        pub fn slice(self: *const Self) []const T {
            return self.buffer[0..self.size];
        }

        pub fn get(self: *const Self, i: Idx) T {
            return self.slice()[i];
        }

        pub fn push(self: *const Self, item: T) Self {
            std.debug.assert(self.size < capacity);
            return self.push_slice(&.{item});
        }

        pub fn push_slice(self: *const Self, items: []const T) Self {
            std.debug.assert(self.size + items.len < capacity);
            var buffer = @as([capacity]T, undefined);
            for (buffer[0..self.size], self.slice()) |*d, s| {
                d.* = s;
            }
            for (buffer[self.size .. self.size + items.len], items) |*d, s| {
                d.* = s;
            }
            return .{
                .buffer = buffer,
                .size = self.size + @as(Idx, @intCast(items.len)),
            };
        }

        pub fn replace(self: *const Self, target: Idx, item: T) Self {
            var buffer = @as([capacity]T, undefined);
            for (self.slice(), buffer[0..self.size], 0..) |s, *d, i| {
                d.* = if (target == i)
                    item
                else
                    s;
            }
            return .{
                .buffer = buffer,
                .size = self.size,
            };
        }
    };
}
