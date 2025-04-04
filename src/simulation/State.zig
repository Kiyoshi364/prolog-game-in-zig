const std = @import("std");

const Model = @import("Model.zig");

model: Model = .{},
cursor: Cursor = .{},

const State = @This();

pub fn step(state: State, state_input: StateInput, model_config: Model.Config) ?State {
    var out_state = @as(State, undefined);

    const cursor1 = state.cursor.move_dirs(
        state_input.dirs,
        model_config.map.bounds,
    ) orelse state.cursor;

    const animation_input = if (cursor1.handle_button(
        state_input.button,
        state.model.pieces(),
        &out_state.cursor,
    )) |model_input|
        state.model.step(model_input, model_config, &out_state.model) orelse return null
    else blk: {
        out_state.model = state.model;
        break :blk .none;
    };

    // TODO: animation
    _ = animation_input;

    return out_state;
}

pub const StateInput = struct {
    dirs: [Model.Direction.count]bool,
    button: ?Button,

    pub const Direction = Model.Direction;
    pub const Button = enum {
        ok,
        back,

        pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
    };
};

const constants = struct {
    const max_path = 16;
    const PathSize = u4;
};

pub const Cursor = struct {
    pos: Model.Position = .{},
    selection: Selection = .none,

    const Selection = union(enum) {
        none: void,
        piece: PieceSelection,
        // menu: MenuSelection,

        const PieceSelection = struct {
            old_pos: Model.Position,
            piece: Model.Piece,
            path_buffer: [constants.max_path]Model.Direction = .{undefined} ** constants.max_path,
            path_size: constants.PathSize = 0,

            pub fn path(selection: *const PieceSelection) []const Model.Direction {
                const p = selection.path_buffer[0..selection.path_size];
                return p;
            }
        };

        // const MenuSelection = struct {};

        fn moved(selection: Selection, dir: Model.Direction) Selection {
            return switch (selection) {
                .none => .none,
                .piece => |piece| blk: {
                    var new_piece = piece;
                    new_piece.path_buffer[new_piece.path_size] = dir;
                    new_piece.path_size += 1;
                    { // shrink_path
                        var x = @as(isize, 0);
                        var y = @as(isize, 0);
                        const old_path_size = new_piece.path_size;
                        for (0..old_path_size) |pre_i| {
                            const i = old_path_size - pre_i - 1;
                            const dir_ = new_piece.path_buffer[i];
                            switch (dir_) {
                                .up => y += 1,
                                .right => x += -1,
                                .down => y += -1,
                                .left => x += 1,
                            }
                            if (x == 0 and y == 0) {
                                new_piece.path_size = @intCast(i);
                            }
                        }
                    }
                    break :blk .{ .piece = new_piece };
                },
            };
        }

        fn handle_ok(selection: *const Selection, pos: Model.Position, pieces: []const Model.Piece, out_cursor: *Cursor) ?Model.ModelInput {
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
                        .path = piece.path(),
                    } };
                },
            };
        }

        fn handle_back(selection: Selection, pos: Model.Position, out_cursor: *Cursor) ?Model.ModelInput {
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

    fn move(cursor: Cursor, dir: Model.Direction, bounds: Model.Position) ?Cursor {
        return if (cursor.pos.move(dir, bounds)) |pos|
            .{ .pos = pos, .selection = cursor.selection.moved(dir) }
        else
            null;
    }

    fn move_dirs(cursor: Cursor, dirs: [Model.Direction.count]bool, bounds: Model.Position) ?Cursor {
        var cursor0 = cursor;
        var moved = false;
        for (dirs, 0..) |should_move, i| {
            if (should_move) {
                const dir = @as(Model.Direction, @enumFromInt(i));
                if (cursor0.move(dir, bounds)) |cursor1| {
                    cursor0 = cursor1;
                    moved = true;
                }
            }
        }
        return if (moved) cursor0 else null;
    }

    fn handle_button(cursor: *const Cursor, button: ?StateInput.Button, pieces: []const Model.Piece, out_cursor: *Cursor) ?Model.ModelInput {
        return if (button) |b|
            switch (b) {
                .ok => cursor.selection.handle_ok(cursor.pos, pieces, out_cursor),
                .back => cursor.selection.handle_back(cursor.pos, out_cursor),
            }
        else blk: {
            out_cursor.* = cursor.*;
            break :blk null;
        };
    }
};
