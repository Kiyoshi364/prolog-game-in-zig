const std = @import("std");

const Buffer = @import("buffer.zig").Buffer;

pub fn Uptree(
    comptime state_cap: comptime_int,
    comptime input_cap: comptime_int,
) type {
    return struct {
        inner: InnerUptree,

        const Self = @This();

        pub const InnerUptree = UptreeWithBuffer(void, void, state_cap, input_cap);
        pub const StateIdx = InnerUptree.StateIdx;
        pub const InputIdx = InnerUptree.InputIdx;

        pub const Parent = struct { input: InputIdx, state: StateIdx };

        pub const empty = Self{ .inner = InnerUptree.empty };

        pub const RegisteredInput = struct { idx: InputIdx, self: Self };
        pub fn register_input(self: Self) ?RegisteredInput {
            return if (self.inner.register_input({})) |reg_input|
                .{ .idx = reg_input.idx, .self = .{ .inner = reg_input.self } }
            else
                null;
        }

        pub const RegisteredState = struct { idx: StateIdx, self: Self };
        pub fn register_state(self: Self, opt_parent: ?Parent) ?RegisteredState {
            return if (self.inner.register_state({}, opt_parent)) |reg_state|
                .{ .idx = reg_state.idx, .self = .{ .inner = reg_state.self } }
            else
                null;
        }
        pub fn parent_states_slice(self: *const Self) []const StateIdx {
            return self.inner.parent_states_slice();
        }

        pub fn get_parent_state(self: Self, idx: StateIdx) StateIdx {
            return self.inner.get_parent_state(idx);
        }

        pub fn parent_inputs_slice(self: *const Self) []const ?InputIdx {
            return self.inner.parent_inputs_slice();
        }

        pub fn get_parent_input(self: Self, idx: InputIdx) ?InputIdx {
            return self.inner.get_parent_input(idx);
        }
    };
}

pub fn UptreeWithBuffer(
    comptime State: type,
    comptime Input: type,
    comptime state_cap: comptime_int,
    comptime input_cap: comptime_int,
) type {
    std.debug.assert(0 < state_cap);
    std.debug.assert(0 < input_cap);
    return struct {
        state_buffer: StateBuffer,
        input_buffer: InputBuffer,
        parent_states: StateIdxArray,
        parent_inputs: InputIdxArray,

        const Self = @This();

        pub const state_capacity = state_cap;
        pub const StateIdx = std.math.IntFittingRange(0, state_cap);
        pub const StateBuffer = Buffer(State, StateIdx, state_cap);

        pub const StateIdxArray = [state_cap]StateIdx;

        pub const input_capacity = input_cap;
        pub const InputIdx = std.math.IntFittingRange(0, input_cap);
        pub const InputBuffer = Buffer(Input, InputIdx, input_cap);

        pub const InputIdxArray = [state_cap]?InputIdx;

        pub const Parent = struct { input: InputIdx, state: StateIdx };

        pub const empty = Self{
            .state_buffer = .{},
            .input_buffer = .{},
            .parent_states = undefined,
            .parent_inputs = undefined,
        };

        pub fn with_root(state: State) Self {
            const self = Self.empty;
            return self.register_state(state, null).?.self;
        }

        pub fn input_slice(self: *const Self) []const Input {
            return self.input_buffer.slice();
        }

        pub fn get_input(self: Self, idx: InputIdx) Input {
            return self.input_slice()[idx];
        }

        pub const RegisteredInput = struct { idx: InputIdx, self: Self };
        pub fn register_input(self: Self, input: Input) ?RegisteredInput {
            const idx = self.input_buffer.size;
            return if (self.input_buffer.opt_push(input)) |ibuf|
                .{
                    .idx = idx,
                    .self = .{
                        .state_buffer = self.state_buffer,
                        .input_buffer = ibuf,
                        .parent_states = self.parent_states,
                        .parent_inputs = self.parent_inputs,
                    },
                }
            else
                null;
        }

        const CompareInputFn = fn (Input, Input) bool;
        fn input_eql(a: Input, b: Input) bool {
            return std.meta.eql(a, b);
        }
        pub fn find_input(self: Self, input: Input) ?InputIdx {
            return self.find_input_compare(input, input_eql);
        }

        pub fn find_input_compare(self: Self, input: Input, comptime eql: CompareInputFn) ?InputIdx {
            return for (self.input_slice(), 0..) |s, i| {
                if (eql(input, s)) {
                    break @intCast(i);
                }
            } else null;
        }

        pub fn find_input_or_register(self: Self, input: Input) ?RegisteredInput {
            return self.find_input_or_register_compare(input, input_eql);
        }

        pub fn find_input_or_register_compare(self: Self, input: Input, comptime eql: CompareInputFn) ?RegisteredInput {
            return if (self.find_input_compare(input, eql)) |idx|
                .{ .idx = idx, .self = self }
            else
                self.register_input(input);
        }

        pub fn state_slice(self: *const Self) []const State {
            return self.state_buffer.slice();
        }

        pub fn get_state(self: Self, idx: StateIdx) State {
            return self.state_buffer.slice()[idx];
        }

        pub const RegisteredState = struct { idx: StateIdx, self: Self };
        pub fn register_state(self: Self, state: State, opt_parent: ?Parent) ?RegisteredState {
            const idx = self.state_buffer.size;
            const InnerParent = struct { input: ?InputIdx, state: StateIdx };
            const parent = @as(InnerParent, if (opt_parent) |parent| blk: {
                std.debug.assert(parent.input < self.input_buffer.size);
                break :blk .{ .input = parent.input, .state = parent.state };
            } else .{ .input = null, .state = idx });

            return if (self.state_buffer.opt_push(state)) |sbuf|
                .{
                    .idx = idx,
                    .self = .{
                        .state_buffer = sbuf,
                        .input_buffer = self.input_buffer,
                        .parent_states = Buffer(StateIdx, StateIdx, state_cap).to_buffer(self.parent_states, idx).opt_push(parent.state).?.buffer,
                        .parent_inputs = Buffer(?InputIdx, InputIdx, state_cap).to_buffer(self.parent_inputs, idx).opt_push(parent.input).?.buffer,
                    },
                }
            else
                null;
        }

        pub fn find_state(self: Self, state: State) ?StateIdx {
            return self.find_state_compare(state, state_eql);
        }

        const CompareStateFn = fn (State, State) bool;
        fn state_eql(a: State, b: State) bool {
            return std.meta.eql(a, b);
        }
        pub fn find_state_compare(self: Self, state: State, comptime eql: CompareStateFn) ?StateIdx {
            return for (self.state_slice(), 0..) |s, i| {
                if (eql(state, s)) {
                    break @intCast(i);
                }
            } else null;
        }

        pub fn parent_states_slice(self: *const Self) []const StateIdx {
            return self.parent_states[0..self.state_buffer.size];
        }

        pub fn get_parent_state(self: Self, idx: StateIdx) StateIdx {
            return self.parent_states_slice()[idx];
        }

        pub fn parent_inputs_slice(self: *const Self) []const ?InputIdx {
            return self.parent_inputs[0..self.state_buffer.size];
        }

        pub fn get_parent_input(self: Self, idx: InputIdx) ?InputIdx {
            return self.parent_inputs_slice()[idx];
        }

        pub fn nosort_stateidx_buffer(self: Self) StateIdxArray {
            _ = self;
            return nosort_idx_buffer(StateIdx, state_capacity);
        }

        pub fn calc_state_id(parents: []const StateIdx, idx: StateIdx, buf: *StateIdxArray) []StateIdx {
            return parents_state_id(StateIdx, state_capacity, parents, idx, buf);
        }

        pub fn get_state_id(self: Self, idx: StateIdx, buf: *StateIdxArray) []StateIdx {
            return calc_state_id(self.parent_states_slice(), idx, buf);
        }

        pub fn sorted_state_indices_by_leftchild(self: Self, buf: *StateIdxArray) []StateIdx {
            const p = self.parent_states_slice();
            return sorted_indices_by_compare(StateIdx, state_capacity, p, leftchild_less_than(StateIdx, state_capacity), buf);
        }

        pub fn sorted_with(self: Self, idxs: []const StateIdx) Self {
            const len = idxs.len;
            const self_states = self.state_slice();
            const self_parent_states = self.parent_states_slice();
            const self_parent_inputs = self.parent_inputs_slice();

            var state_buffer = StateBuffer{
                .size = @intCast(self_states.len),
            };
            var parent_states = @as(StateIdxArray, undefined);
            var parent_inputs = @as(InputIdxArray, undefined);
            for (idxs, state_buffer.buffer[0..len], parent_states[0..len], parent_inputs[0..len]) |idx, *s, *ps, *pi| {
                s.* = self_states[idx];
                ps.* = for (idxs, 0..) |jdx, j| {
                    if (self_parent_states[idx] == jdx) {
                        break @intCast(j);
                    }
                } else unreachable;
                pi.* = self_parent_inputs[idx];
            }
            return .{
                .state_buffer = state_buffer,
                .input_buffer = self.input_buffer,
                .parent_states = parent_states,
                .parent_inputs = parent_inputs,
            };
        }

        // TODO: try SIMD/@Vector
        pub fn state_left_siblings(self: Self, buf: *StateIdxArray) []StateIdx {
            const p = self.parent_states_slice();
            const len = p.len;
            const lefts = buf[0..len];
            for (lefts, p, 0..) |*out, pi, i| {
                out.* = if (pi == i)
                    for (0..i) |pre_j| {
                        const j = i - pre_j - 1;
                        const pj = p[j];
                        if (pj == j) {
                            break @intCast(j);
                        }
                    } else @intCast(i)
                else for (0..i) |pre_j| {
                    const j = i - pre_j - 1;
                    const pj = p[j];
                    if (pi == pj and pj != j) {
                        break @intCast(j);
                    }
                } else @intCast(i);
            }
            return lefts;
        }

        // TODO: try SIMD/@Vector
        pub fn state_right_siblings(self: Self, buf: *StateIdxArray) []StateIdx {
            const p = self.parent_states_slice();
            const len = p.len;
            const rights = buf[0..len];
            for (rights, p, 0..) |*out, pi, i| {
                out.* = if (pi == i)
                    for (p[i + 1 ..], i + 1..) |pj, j| {
                        if (pj == j) {
                            break @intCast(j);
                        }
                    } else @intCast(i)
                else for (p[i + 1 ..], i + 1..) |pj, j| {
                    if (pi == pj and pj != j) {
                        break @intCast(j);
                    }
                } else @intCast(i);
            }
            return rights;
        }

        // TODO: try SIMD/@Vector
        pub fn state_depths(self: Self, buf: *StateIdxArray) []StateIdx {
            const p = self.parent_states_slice();
            const len = p.len;
            const depths = buf[0..len];
            for (depths, 0..) |*out, i| {
                var it = @as(StateIdx, @intCast(i));
                var d = @as(StateIdx, 0);
                out.* = while (it != p[it]) : (it = p[it]) {
                    d += 1;
                } else d;
            }
            return depths;
        }
    };
}

test "UptreeWithBuffer: tree building" {
    const state_cap = 10;
    const input_cap = 20;
    const State = u8;
    const Input = i8;
    const Tree = UptreeWithBuffer(State, Input, state_cap, input_cap);
    var tree = Tree.empty;

    { // Registering Inputs
        const s = struct {
            fn input_true(a: Input, b: Input) bool {
                _ = a;
                _ = b;
                return true;
            }
            fn input_false(a: Input, b: Input) bool {
                _ = a;
                _ = b;
                return false;
            }
        };
        const input_factor = @as(i8, -3);

        for (0..input_cap - 1) |i| {
            const input = input_factor * @as(i8, @intCast(i));
            const reg_input = tree.register_input(input).?;
            try std.testing.expectEqual(i, reg_input.idx);
            try std.testing.expectEqual(input, reg_input.self.get_input(reg_input.idx));
            tree = reg_input.self;
        }
        try std.testing.expectEqualSlices(
            i8,
            &.{ 0, -3, -6, -9, -12, -15, -18, -21, -24, -27, -30, -33, -36, -39, -42, -45, -48, -51, -54 },
            tree.input_slice(),
        );

        try std.testing.expectEqual(null, tree.find_input(3));
        const input_idx = 3;
        try std.testing.expectEqual(input_idx, tree.find_input(input_factor * input_idx));
        try std.testing.expectEqual(
            Tree.RegisteredInput{ .idx = input_idx, .self = tree },
            tree.find_input_or_register(input_factor * input_idx),
        );

        try std.testing.expectEqual(
            Tree.RegisteredInput{ .idx = 0, .self = tree },
            tree.find_input_or_register_compare(undefined, s.input_true),
        );
        const reg_input = tree.find_input_or_register_compare(1, s.input_false);
        try std.testing.expectEqual(
            Tree.RegisteredInput{ .idx = tree.input_buffer.size, .self = .{
                .state_buffer = tree.state_buffer,
                .input_buffer = tree.input_buffer.opt_push(1).?,
                .parent_states = tree.parent_states,
                .parent_inputs = tree.parent_inputs,
            } },
            reg_input,
        );
        tree = reg_input.?.self;
    }
    { // Registering States
        const s = struct {
            fn state_true(a: State, b: State) bool {
                _ = a;
                _ = b;
                return true;
            }
            fn state_false(a: State, b: State) bool {
                _ = a;
                _ = b;
                return false;
            }
        };
        const state_factor = @as(u8, 5);

        for (0..state_cap) |i| {
            const state = state_factor * @as(u8, @intCast(i));
            const reg_state = tree.register_state(state, if (i == 0)
                null
            else
                .{ .input = @intCast(state % input_cap), .state = @intCast(i / 2) }).?;
            try std.testing.expectEqual(i, reg_state.idx);
            try std.testing.expectEqual(state, reg_state.self.get_state(reg_state.idx));
            tree = reg_state.self;
        }
        try std.testing.expectEqualSlices(
            u8,
            &.{ 0, 5, 10, 15, 20, 25, 30, 35, 40, 45 },
            tree.state_slice(),
        );

        try std.testing.expectEqual(null, tree.find_state(0xFE));
        const state_idx = 3;
        try std.testing.expectEqual(state_idx, tree.find_state(state_factor * state_idx));
        try std.testing.expectEqual(0, tree.find_state_compare(undefined, s.state_true));
        try std.testing.expectEqual(null, tree.find_state_compare(undefined, s.state_false));
    }

    try std.testing.expectEqualSlices(
        Tree.StateIdx,
        &.{ 0, 0, 1, 1, 2, 2, 3, 3, 4, 4 },
        tree.parent_states_slice(),
    );
    try std.testing.expectEqual(0, tree.get_parent_state(0));
    try std.testing.expectEqual(1, tree.get_parent_state(3));
    try std.testing.expectEqual(3, tree.get_parent_state(6));

    try std.testing.expectEqualSlices(
        ?Tree.InputIdx,
        &.{ null, 5, 10, 15, 0, 5, 10, 15, 0, 5 },
        tree.parent_inputs_slice(),
    );
    try std.testing.expectEqual(5, tree.get_parent_input(1));
    try std.testing.expectEqual(0, tree.get_parent_input(4));
    try std.testing.expectEqual(15, tree.get_parent_input(7));

    {
        var buf = @as(Tree.StateIdxArray, undefined);

        try std.testing.expectEqualSlices(
            Tree.StateIdx,
            &.{ 0, 1, 2, 2, 4, 4, 6, 6, 8, 8 },
            tree.state_left_siblings(&buf),
        );

        try std.testing.expectEqualSlices(
            Tree.StateIdx,
            &.{ 0, 1, 3, 3, 5, 5, 7, 7, 9, 9 },
            tree.state_right_siblings(&buf),
        );

        try std.testing.expectEqualSlices(
            Tree.StateIdx,
            &.{ 0, 1, 2, 2, 3, 3, 3, 3, 4, 4 },
            tree.state_depths(&buf),
        );
    }
}

pub fn parents_state_id(comptime Int: type, comptime len: comptime_int, parents: []const Int, idx: Int, buf: *[len]Int) []Int {
    std.debug.assert(@typeInfo(Int) == .int);

    var it = idx;
    var i = @as(Int, buf.*.len);
    while (it != parents[it]) : (it = parents[it]) {
        i -= 1;
        buf[i] = it;
    }
    i -= 1;
    buf[i] = it;
    return buf[i..];
}

pub fn nosort_idx_buffer(comptime Int: type, comptime len: comptime_int) [len]Int {
    var buf = @as([len]Int, undefined);
    for (&buf, 0..) |*it, i| {
        it.* = @intCast(i);
    }
    return buf;
}

pub fn sorted_indices_by_compare(comptime Int: type, comptime len: comptime_int, keys: []const Int, comptime compare: fn ([]const Int, Int, Int) bool, buf: *[len]Int) []Int {
    const idxs = buf[0..keys.len];
    std.mem.sort(Int, idxs, keys, compare);
    return idxs;
}

pub fn leftchild_less_than(comptime Int: type, comptime len: comptime_int) fn ([]const Int, Int, Int) bool {
    const s = struct {
        fn func(parents: []const Int, a: Int, b: Int) bool {
            var a_buf = @as([len]Int, undefined);
            var b_buf = @as([len]Int, undefined);

            const a_path = parents_state_id(Int, len, parents, a, &a_buf);
            const b_path = parents_state_id(Int, len, parents, b, &b_buf);
            const min_len = @min(a_path.len, b_path.len);

            return for (a_path[0..min_len], b_path[0..min_len]) |a_it, b_it| {
                if (a_it == b_it) {
                    continue;
                } else {
                    break a_it < b_it;
                }
            } else a_path.len < b_path.len;
        }
    };
    return s.func;
}

test "UptreeWithBuffer: parents_state_id" {
    const Test = struct { p: []const u8, expecteds: []const []const u8 };
    const len = 32;
    const tests = [_]Test{
        .{
            .p = &.{ 0, 0, 0, 1, 1, 2, 3, 5 },
            .expecteds = &.{
                &.{0},
                &.{ 0, 1 },
                &.{ 0, 2 },
                &.{ 0, 1, 3 },
                &.{ 0, 1, 4 },
                &.{ 0, 2, 5 },
                &.{ 0, 1, 3, 6 },
                &.{ 0, 2, 5, 7 },
            },
        },
        .{
            .p = &[_]u8{ 0, 0, 1, 2, 3, 2, 5, 5, 2, 7 },
            .expecteds = &.{
                &.{0},
                &.{ 0, 1 },
                &.{ 0, 1, 2 },
                &.{ 0, 1, 2, 3 },
                &.{ 0, 1, 2, 3, 4 },
                &.{ 0, 1, 2, 5 },
                &.{ 0, 1, 2, 5, 6 },
                &.{ 0, 1, 2, 5, 7 },
                &.{ 0, 1, 2, 8 },
                &.{ 0, 1, 2, 5, 7, 9 },
            },
        },
    };

    var buf = @as([len]u8, undefined);
    for (tests) |t| {
        for (t.expecteds, 0..t.p.len) |expected_id, i| {
            const id = parents_state_id(u8, len, t.p, @intCast(i), &buf);
            try std.testing.expectEqualSlices(u8, expected_id, id);
        }
    }
}

test "UptreeWithBuffer: leftchild sorting" {
    const Test = struct { p: []const u8, expected: []const u8 };
    const len = 16;
    const tests = [_]Test{
        .{
            .p = &[_]u8{ 0, 0, 0, 1, 1, 2, 3, 5 },
            .expected = &[_]u8{ 0, 1, 3, 6, 4, 2, 5, 7 },
        },
        .{
            .p = &[_]u8{ 0, 0, 1, 2, 3, 2, 5, 5, 2, 7 },
            .expected = &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 9, 8 },
        },
    };

    var buf = nosort_idx_buffer(u8, len);
    for (tests) |t| {
        const sorted_idxs = sorted_indices_by_compare(u8, len, t.p, leftchild_less_than(u8, len), &buf);
        try std.testing.expectEqualSlices(u8, t.expected, sorted_idxs);
    }
}

test {
    _ = UptreeWithBuffer(u8, u8, 10, 20);
    _ = Uptree(10, 20).empty;
}
