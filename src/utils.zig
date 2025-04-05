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
