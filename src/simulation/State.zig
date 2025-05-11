const std = @import("std");

const utils = @import("utils");

const Model = @import("Model.zig");

active_cursor: CursorTag,
map_cursor: MapCursor,
time_cursor: TimeCursor,
anims: Animations,

const State = @This();
const Animations = utils.Buffer(Animation, Model.constants.PiecesSize, Model.constants.max_pieces);
const Path = utils.Buffer(Model.Direction, constants.PathSize, constants.max_path);

pub const empty = State{
    .active_cursor = .map,
    .map_cursor = MapCursor.empty,
    .time_cursor = TimeCursor.with_root(.{}),
    .anims = .{},
};

pub fn step(state: State, state_input: StateInput, model_config: Model.Config) ?State {
    std.debug.assert(state.check());

    // std.debug.print("{} {}\n", .{state.time_cursor.model_idx, state.active_cursor});
    // std.debug.print("{} {}\n", .{state_input.modifier(), state_input});
    const out_state = switch (state.active_cursor) {
        .map => out_state: {
            var varout_active_cursor = @as(CursorTag, undefined);
            const map_cursor1 = state.map_cursor.move_dirs(
                state_input.modifier(),
                state_input.dirs,
                model_config.map.bounds,
                &varout_active_cursor,
            ) orelse state.map_cursor;
            const out_active_cursor = varout_active_cursor;

            const model = state.get_curr_model();
            var varout_map_cursor = @as(MapCursor, undefined);
            var varout_time_cursor = @as(TimeCursor, undefined);
            const out_anims = if (map_cursor1.handle_button(
                state_input.modifier(),
                state_input.button,
                model.pieces.slice(),
                &varout_map_cursor,
            )) |model_input| out_anims: {
                var varout_model = @as(Model, undefined);
                break :out_anims if (model.step(model_input, model_config, &varout_model)) |anim_input| blk: {
                    // TODO: log/notify out of time traveling memory
                    state.time_cursor.discover_transition(model_input, varout_model, &varout_time_cursor) orelse unreachable;
                    break :blk state.update_animations(anim_input);
                } else blk: {
                    // TODO: log/notify invalid move
                    varout_time_cursor = state.time_cursor;
                    break :blk state.tick_anims();
                };
            } else blk: {
                varout_time_cursor = state.time_cursor;
                break :blk state.tick_anims();
            };
            const out_map_cursor = varout_map_cursor;
            const out_time_cursor = varout_time_cursor;

            break :out_state State{
                .active_cursor = out_active_cursor,
                .map_cursor = out_map_cursor,
                .time_cursor = out_time_cursor,
                .anims = out_anims,
            };
        },
        .time => out_state: {
            var varout_active_cursor = @as(CursorTag, undefined);
            const time_cursor1 = state.time_cursor.move_dirs(
                state_input.modifier(),
                state_input.dirs,
                &varout_active_cursor,
            ) orelse state.time_cursor;

            const out_time_cursor = time_cursor1.handle_button(
                state_input.modifier(),
                state_input.button,
                &varout_active_cursor,
            ) orelse time_cursor1;
            const out_active_cursor = varout_active_cursor;

            break :out_state State{
                .active_cursor = out_active_cursor,
                .map_cursor = state.map_cursor,
                .time_cursor = out_time_cursor,
                .anims = .{},
            };
        },
    };
    std.debug.assert(out_state.check());
    return out_state;
}

pub fn get_curr_model(state: State) Model {
    return state.time_cursor.curr_model();
}

pub fn get_root_model(state: State) Model {
    return state.time_cursor.root_model();
}

pub fn get_root_model_mut(state: *State) *Model {
    return state.time_cursor.root_model_mut();
}

pub fn check(state: State) bool {
    if (state.time_cursor.model_idx < state.time_cursor.model_tree.state_slice().len) {
        // Nothing
    } else {
        return false;
    }

    if (0 < state.anims.size) {
        const anims_slice = state.anims.slice();
        for (anims_slice[1..], 0..) |curr_anim, i| {
            const prev_anim = anims_slice[i];
            if (curr_anim.piece_id < prev_anim.piece_id) {
                return false;
            } else {
                std.debug.assert(prev_anim.piece_id != curr_anim.piece_id);
            }
        }
    } else {
        // Nothing
    }
    return true;
}

fn moved_control(ret: anytype, dir: Model.Direction, out_activecursor: *CursorTag) ?@TypeOf(ret) {
    return switch (dir) {
        .up => null,
        .left => blk: {
            out_activecursor.* = .map;
            break :blk ret;
        },
        .down => null,
        .right => blk: {
            out_activecursor.* = .time;
            break :blk ret;
        },
    };
}

pub const StateInput = struct {
    dirs: [Model.Direction.count]bool,
    mods: [ModifierFlags.count]bool,
    button: ?Button,

    pub const Direction = Model.Direction;
    pub const ModifierFlags = enum(u1) {
        control = 0,

        pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
    };
    pub const Modifier = enum(u1) {
        none = 0,
        control = 1,

        pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
        const TagType = @typeInfo(@This()).@"enum".tag_type;

        pub fn from_flags(mods: [ModifierFlags.count]bool) Modifier {
            var imod = @as(TagType, 0);
            for (mods, 0..) |mod_on, i| {
                imod |= @as(TagType, @intFromBool(mod_on)) << @intCast(i);
            }
            return @enumFromInt(imod);
        }
    };
    pub const Button = enum {
        ok,
        back,

        pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
    };

    pub fn modifier(state_input: StateInput) Modifier {
        return Modifier.from_flags(state_input.mods);
    }
};

pub const constants = struct {
    const max_path = 15;
    const PathSize = u4;

    pub const animation_start_timer = 20;

    const max_model_depth = 4;
    const ModelDepth = u4;
    const max_model_storage = 31;
    const ModelIdx = u5;
};

pub const CursorTag = enum {
    map,
    time,
};

pub const MapCursor = struct {
    pos: Model.Position,
    selection: Selection,

    pub const empty = MapCursor{
        .pos = .{},
        .selection = .none,
    };

    pub const Selection = union(enum) {
        none: void,
        piece: PieceSelection,
        // menu: MenuSelection,

        pub const @"enum": type = @typeInfo(@This()).@"union".tag_type.?;
        pub const count: comptime_int = @typeInfo(Selection.@"enum").@"enum".fields.len;

        const PieceSelection = struct {
            old_pos: Model.Position,
            piece: Model.Piece,
            path: Path = .{},
        };

        // const MenuSelection = struct {};

        fn moved(selection: Selection, dir: Model.Direction) ?Selection {
            return switch (selection) {
                .none => .none,
                .piece => |piece| blk: {
                    var new_path = piece.path;
                    const shrinked = blk2: { // shrink_path
                        const a = dir.toAddData();
                        var x = @as(isize, a.x * if (a.adds) -1 else @as(isize, 1));
                        var y = @as(isize, a.y * if (a.adds) -1 else @as(isize, 1));
                        var shrinked = false;
                        const old_path_size = new_path.size;
                        break :blk2 for (0..old_path_size) |pre_i| {
                            const i: constants.PathSize = @intCast(old_path_size - pre_i - 1);
                            const dir_ = new_path.get(i);
                            switch (dir_) {
                                .up => y += 1,
                                .right => x += -1,
                                .down => y += -1,
                                .left => x += 1,
                            }
                            if (x == 0 and y == 0) {
                                new_path.size = i;
                                shrinked = true;
                            }
                        } else shrinked;
                    };
                    break :blk if (shrinked)
                        .{ .piece = .{
                            .old_pos = piece.old_pos,
                            .piece = piece.piece,
                            .path = new_path,
                        } }
                    else if (new_path.opt_push(dir)) |new_path1|
                        .{ .piece = .{
                            .old_pos = piece.old_pos,
                            .piece = piece.piece,
                            .path = new_path1,
                        } }
                    else
                        null;
                },
            };
        }

        fn handle_ok(selection: *const Selection, mod: StateInput.Modifier, pos: Model.Position, pieces: []const Model.Piece, out_cursor: *MapCursor) ?Model.Input {
            // TODO: do stuff with mod + ok
            std.debug.assert(mod == .none);
            return switch (selection.*) {
                .none => blk: {
                    const find_piece = for (pieces) |piece| {
                        if (std.meta.eql(piece.pos, pos)) {
                            break piece;
                        }
                    } else null;
                    out_cursor.* = if (find_piece) |piece|
                        .{ .pos = pos, .selection = .{ .piece = .{
                            .old_pos = pos,
                            .piece = piece,
                        } } }
                    else
                        .{ .pos = pos, .selection = .none };
                    break :blk null;
                },
                .piece => |*piece| blk: {
                    out_cursor.* = .{ .pos = pos, .selection = .none };
                    break :blk .{ .move = .{
                        .piece = piece.piece,
                        .path = piece.path.slice(),
                    } };
                },
            };
        }

        fn handle_back(selection: Selection, mod: StateInput.Modifier, pos: Model.Position, out_cursor: *MapCursor) ?Model.Input {
            // TODO: do stuff with mod + back
            std.debug.assert(mod == .none);
            switch (selection) {
                .none => out_cursor.* = .{
                    .pos = pos,
                    .selection = .none,
                },
                .piece => |piece| out_cursor.* = .{
                    .pos = piece.old_pos,
                    .selection = .none,
                },
            }
            return null;
        }
    };

    fn move(cursor: MapCursor, mod: StateInput.Modifier, dir: Model.Direction, bounds: Model.Position, out_activecursor: *CursorTag) ?MapCursor {
        return switch (mod) {
            .none => if (cursor.pos.move(dir, bounds)) |pos|
                if (cursor.selection.moved(dir)) |selection| blk: {
                    out_activecursor.* = .map;
                    break :blk .{ .pos = pos, .selection = selection };
                } else null
            else
                null,
            .control => if (moved_control(cursor.selection, dir, out_activecursor)) |selection|
                .{ .pos = cursor.pos, .selection = selection }
            else
                null,
        };
    }

    fn move_dirs(cursor: MapCursor, mod: StateInput.Modifier, dirs: [Model.Direction.count]bool, bounds: Model.Position, out_activecursor: *CursorTag) ?MapCursor {
        var cursor0 = cursor;
        var moved = false;
        for (dirs, 0..) |should_move, i| {
            if (should_move) {
                const dir = @as(Model.Direction, @enumFromInt(i));
                if (cursor0.move(mod, dir, bounds, out_activecursor)) |cursor1| {
                    cursor0 = cursor1;
                    moved = true;
                }
            }
        }
        return if (moved)
            cursor0
        else blk: {
            out_activecursor.* = .map;
            break :blk null;
        };
    }

    fn handle_button(cursor: *const MapCursor, mod: StateInput.Modifier, button: ?StateInput.Button, pieces: []const Model.Piece, out_cursor: *MapCursor) ?Model.Input {
        return if (button) |b|
            switch (b) {
                .ok => cursor.selection.handle_ok(mod, cursor.pos, pieces, out_cursor),
                .back => cursor.selection.handle_back(mod, cursor.pos, out_cursor),
            }
        else blk: {
            out_cursor.* = cursor.*;
            break :blk null;
        };
    }
};

pub const TimeCursor = struct {
    model_tree: ModelTree,
    model_idx: constants.ModelIdx,
    old_model_idx: constants.ModelIdx,

    const ModelTree = utils.UptreeWithBuffer(Model, Model.Input, constants.max_model_storage, constants.max_model_storage);

    pub fn with_root(the_root_model: Model) TimeCursor {
        return .{
            .model_tree = ModelTree.with_root(the_root_model),
            .model_idx = 0,
            .old_model_idx = 0,
        };
    }

    pub fn curr_model(cursor: TimeCursor) Model {
        return cursor.model_tree.state_slice()[cursor.model_idx];
    }

    pub fn root_model(cursor: TimeCursor) Model {
        return cursor.model_tree.state_slice()[0];
    }

    pub fn root_model_mut(cursor: *TimeCursor) *Model {
        std.debug.assert(0 < cursor.model_tree.state_buffer.size);
        return &cursor.model_tree.state_buffer.buffer[0];
    }

    fn discover_transition(cursor: TimeCursor, input: Model.Input, next_model: Model, out_cursor: *TimeCursor) ?void {
        const reg_input = cursor.model_tree.find_input_or_register(input) orelse return null;
        const reg_state = reg_input.self.register_state(
            next_model,
            .{ .input = reg_input.idx, .state = cursor.model_idx },
        ) orelse return null;
        out_cursor.* = .{
            .model_tree = reg_state.self,
            .model_idx = reg_state.idx,
            .old_model_idx = reg_state.idx,
        };
    }

    // TODO: Use SIMD (@Vector)
    // TODO: sort model_tree to search less
    fn moved(cursor: TimeCursor, dir: Model.Direction) ?constants.ModelIdx {
        const parents = cursor.model_tree.parent_states_slice();
        const curr = cursor.model_idx;
        return switch (dir) {
            .up => parents[curr],
            .left => for (0..curr) |pre_i| {
                const i = curr - pre_i - 1;
                const p = parents[i];
                std.debug.assert(curr != i);
                if (parents[cursor.model_idx] == p and p != i and i != cursor.model_idx) {
                    break @intCast(i);
                }
            } else null,
            .down => for (parents, 0..) |p, i| {
                if (cursor.model_idx == p and i != p) {
                    break @intCast(i);
                }
            } else null,
            .right => for (parents[curr + 1..], (curr + 1)..) |p, i| {
                std.debug.assert(curr != i);
                if (parents[curr] == p and p != i) {
                    break @intCast(i);
                }
            } else null,
        };
    }

    fn move(cursor: TimeCursor, mod: StateInput.Modifier, dir: Model.Direction, out_activecursor: *CursorTag) ?TimeCursor {
        return switch (mod) {
            .none => if (cursor.moved(dir)) |model_idx| blk: {
                out_activecursor.* = .time;
                break :blk TimeCursor{
                    .model_tree = cursor.model_tree,
                    .model_idx = model_idx,
                    .old_model_idx = cursor.old_model_idx,
                };
            } else null,
            .control => moved_control(cursor, dir, out_activecursor),
        };
    }

    fn move_dirs(cursor: TimeCursor, mod: StateInput.Modifier, dirs: [Model.Direction.count]bool, out_activecursor: *CursorTag) ?TimeCursor {
        var cursor0 = cursor;
        var has_moved = false;
        for (dirs, 0..) |should_move, i| {
            if (should_move) {
                const dir = @as(Model.Direction, @enumFromInt(i));
                if (cursor0.move(mod, dir, out_activecursor)) |cursor1| {
                    cursor0 = cursor1;
                    has_moved = true;
                }
            }
        }
        return if (has_moved)
            cursor0
        else blk: {
            out_activecursor.* = .time;
            break :blk null;
        };
    }

    fn handle_button(cursor: *const TimeCursor, mod: StateInput.Modifier, button: ?StateInput.Button, out_activecursor: *CursorTag) ?TimeCursor {
        return if (button) |b|
            switch (b) {
                .ok => blk: {
                    // TODO: do stuff with mod + ok
                    std.debug.assert(mod == .none);
                    out_activecursor.* = .map;
                    break :blk TimeCursor{
                        .model_tree = cursor.model_tree,
                        .model_idx = cursor.model_idx,
                        .old_model_idx = cursor.model_idx,
                    };
                },
                .back => blk: {
                    // TODO: do stuff with mod + back
                    std.debug.assert(mod == .none);
                    out_activecursor.* = .map;
                    break :blk TimeCursor{
                        .model_tree = cursor.model_tree,
                        .model_idx = cursor.old_model_idx,
                        .old_model_idx = cursor.old_model_idx,
                    };
                },
            }
        else null;
    }
};

pub const Animation = struct {
    piece_id: Model.constants.PieceID,
    state: AnimState,

    const AnimState = union(enum) {
        move: Move,

        pub const Move = struct {
            curr_pos: Model.Position,
            timer: u8 = constants.animation_start_timer,
            path: Path = undefined,
            path_idx: constants.PathSize = 0,

            fn tick(move: Move) ?Move {
                return if (0 < move.timer)
                    .{
                        .curr_pos = move.curr_pos,
                        .timer = move.timer - 1,
                        .path = move.path,
                        .path_idx = move.path_idx,
                    }
                else if (move.path_idx + 1 < move.path.size)
                    .{
                        .curr_pos = move.curr_pos.move_unbounded(move.path.get(move.path_idx)),
                        .path = move.path,
                        .path_idx = move.path_idx + 1,
                    }
                else
                    null;
            }
        };
    };

    fn tick(anim: Animation) ?Animation {
        return switch (anim.state) {
            .move => |move| if (move.tick()) |new_move|
                .{
                    .piece_id = anim.piece_id,
                    .state = .{ .move = new_move },
                }
            else
                null,
        };
    }

    fn merge(anim: Animation, anim_input: Model.AnimationInput) ?Animation {
        // TODO: find a better merge than dropping old animation
        _ = anim;
        return fromAnimationInput(anim_input);
    }

    fn fromAnimationInput(anim_input: Model.AnimationInput) ?Animation {
        return switch (anim_input) {
            .move => |move| if (0 < move.path.len)
                .{
                    .piece_id = move.piece.id,
                    .state = .{ .move = .{
                        .curr_pos = move.piece.pos,
                        .path = (Path{}).push_slice(move.path),
                    } },
                }
            else
                null,
        };
    }
};

fn update_animations(state: State, anim_input: Model.AnimationInput) Animations {
    const piece_id = switch (anim_input) {
        .move => |move| move.piece_id(),
    };
    const anims_slice = state.anims.slice();

    var buffer = Animations.Builder{};
    const idx_after_inclusion = for (anims_slice, 0..) |anim, i| {
        if (piece_id < anim.piece_id) {
            break i;
        } else if (piece_id == anim.piece_id) {
            break i + 1;
        } else {
            if (anim.tick()) |new_anim| {
                buffer.push_mut(new_anim);
            } else {
                // Nothing
            }
        }
    } else anims_slice.len;

    if (idx_after_inclusion < anims_slice.len) {
        {
            const anim = anims_slice[idx_after_inclusion];
            if (anim.tick()) |new_anim| {
                if (new_anim.merge(anim_input)) |merged_anim| {
                    buffer.push_mut(merged_anim);
                } else {
                    // Nothing
                }
            } else {
                if (Animation.fromAnimationInput(anim_input)) |in_anim| {
                    buffer.push_mut(in_anim);
                } else {
                    // Nothing
                }
            }
        }
        for (anims_slice[idx_after_inclusion..]) |anim| {
            if (anim.tick()) |new_anim| {
                buffer.push_mut(new_anim);
            } else {
                // Nothing
            }
        }
    } else {
        if (Animation.fromAnimationInput(anim_input)) |in_anim| {
            buffer.push_mut(in_anim);
        } else {
            // Nothing
        }
    }

    return buffer.frozen();
}

fn tick_anims(state: State) Animations {
    var buffer = Animations.Builder{};
    for (state.anims.slice()) |anim| {
        if (anim.tick()) |new_anim| {
            buffer.push_mut(new_anim);
        } else {
            // Nothing
        }
    }
    return buffer.frozen();
}

test "State.refAllDeclsRecursive" {
    std.testing.refAllDeclsRecursive(@This());
}
