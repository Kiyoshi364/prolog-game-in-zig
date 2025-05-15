const std = @import("std");

const utils = @import("utils");

const Model = @This();

pieces: utils.Buffer(Piece, constants.PiecesSize, constants.max_pieces),
piece_genid: constants.PieceID,

pub const empty = Model{
    .pieces = .{},
    .piece_genid = 0,
};

pub fn step(model: Model, model_input: Input, config: Config, out_model: *Model) ?AnimationInput {
    std.debug.assert(model.check());
    return switch (model_input) {
        .move => |move| blk: {
            const piece_idx = move.piece.find_insorted(model.pieces.slice()) orelse break :blk null;
            const p = model.pieces.get(piece_idx);

            if (0 < p.energy) {
                // Ok
            } else {
                return null;
            }

            const new_pos = move.piece.pos.move_many(
                move.path.slice(),
                config.map.bounds,
            ) orelse break :blk null;

            out_model.*.pieces = model.pieces.replace(
                piece_idx,
                .{
                    .pos = new_pos,
                    .kind = p.kind,
                    .id = p.id,
                    .energy = p.energy - 1,
                },
            );
            out_model.piece_genid = model.piece_genid;
            std.debug.assert(out_model.check());
            break :blk .{ .move = .{ .piece = move.piece, .path = move.path } };
        },
    };
}

pub fn genid_mut(model: *Model) constants.PieceID {
    model.*.piece_genid += 1;
    return model.piece_genid;
}

pub fn check(model: Model) bool {
    const pieces_slice = model.pieces.slice();
    for (pieces_slice, 0..) |p, i| {
        const id_zero = p.id <= 0;
        const id_higher_than_gen = model.piece_genid < p.id;
        if (id_zero or id_higher_than_gen) {
            return false;
        }
        for (pieces_slice[i + 1 ..]) |p1| {
            const ids_out_of_order = p1.id <= p.id;
            if (ids_out_of_order) {
                return false;
            }
        }
    }
    return true;
}

pub fn eql(a: Model, b: Model) bool {
    return a.pieces.eql(b.pieces) and a.piece_genid == b.piece_genid;
}

pub const Config = struct {
    map: MapConfig = .{},
    piece: PieceConfig = .{},

    pub const MapConfig = struct {
        map_buffer: [constants.max_map_storage]Tile = undefined,
        bounds: Position = .{ .y = 0, .x = 0 },

        pub fn check(c: MapConfig) bool {
            return c.map_storage_size() <= constants.max_map_storage;
        }
        pub fn map_mut(c: *MapConfig) []Tile {
            return c.map_buffer[0..c.map_storage_size()];
        }
        pub fn map(c: *const MapConfig) []const Tile {
            return c.map_buffer[0..c.map_storage_size()];
        }
        pub fn map_storage_size(c: MapConfig) usize {
            return c.storage_width() * c.storage_height();
        }
        pub fn storage_width(c: MapConfig) usize {
            return c.bounds.x;
        }
        pub fn storage_height(c: MapConfig) usize {
            return (c.bounds.y + 1) / 2;
        }
        pub fn position_to_map(c: MapConfig, pos: Position) usize {
            // TODO
            _ = c;
            _ = pos;
            return undefined;
        }
        pub fn position_to_board(c: MapConfig, pos: Position) usize {
            // TODO
            _ = c;
            _ = pos;
            return undefined;
        }
    };

    pub const Tile = enum {
        empty,
    };

    pub const PieceConfig = struct {
        starting_energies: [Piece.Kind.count]constants.Energy = std.enums.directEnumArray(Piece.Kind, constants.Energy, 0, .{
            .capitan = 2,
            .minion = 1,
        }),
    };
};

pub const Input = union(enum) {
    move: Move,
    // TODO: add EndOfTurn

    pub const Move = struct {
        piece: Piece,
        path: Path,

        pub fn piece_id(move: Move) constants.PieceID {
            return move.piece.id;
        }
    };
};

pub const AnimationInput = union(enum) {
    move: Input.Move,
};

pub const Direction = enum(u2) {
    up = 0,
    right = 1,
    down = 2,
    left = 3,

    pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
    pub fn opposite(dir: Direction) Direction {
        return switch (dir) {
            .up => .down,
            .right => .left,
            .down => .up,
            .left => .right,
        };
    }

    const AddData = struct { name: Position.PositionTag, x: u1, y: u1, adds: bool };
    pub fn toAddData(dir: Direction) AddData {
        return switch (dir) {
            .up => .{ .name = .y, .x = 0, .y = 1, .adds = false },
            .right => .{ .name = .x, .x = 1, .y = 0, .adds = true },
            .down => .{ .name = .y, .x = 0, .y = 1, .adds = true },
            .left => .{ .name = .x, .x = 1, .y = 0, .adds = false },
        };
    }
};

pub const Position = struct {
    y: u8 = 0,
    x: u8 = 0,

    pub const PositionTag = enum { x, y };
    pub fn by_tag(pos: Position, tag: PositionTag) u8 {
        return switch (tag) {
            inline .x, .y => |t| @field(pos, @tagName(t)),
        };
    }

    pub fn move_unbounded(pos: Position, dir: Direction) Position {
        const a = dir.toAddData();
        return if (a.adds)
            .{ .x = pos.x + a.x, .y = pos.y + a.y }
        else
            .{ .x = pos.x - a.x, .y = pos.y - a.y };
    }

    pub fn move(pos: Position, dir: Direction, bounds: Position) ?Position {
        const a = dir.toAddData();
        return if (a.adds)
            if (pos.by_tag(a.name) < bounds.by_tag(a.name) -| 1)
                .{ .x = pos.x + a.x, .y = pos.y + a.y }
            else
                null
        else if (0 < pos.by_tag(a.name))
            .{ .x = pos.x - a.x, .y = pos.y - a.y }
        else
            null;
    }

    pub fn move_many(pos: Position, dirs: []const Direction, bounds: Position) ?Position {
        var pos0 = pos;
        return for (dirs) |dir| {
            pos0 = pos0.move(dir, bounds) orelse break null;
        } else pos0;
    }
};

pub const Piece = struct {
    id: constants.PieceID = 0,
    pos: Position,
    kind: Kind,
    energy: constants.Energy = 0,

    pub const Kind = enum {
        capitan,
        minion,

        pub const count: comptime_int = @typeInfo(@This()).@"enum".fields.len;
    };

    pub fn refresh(piece: Piece, pconfig: Model.Config.PieceConfig) Piece {
        var new_piece = piece;
        new_piece.energy = pconfig.starting_energies[@intFromEnum(piece.kind)];
        return new_piece;
    }

    pub fn find_insorted(piece: Piece, pieces: []const Piece) ?constants.PiecesSize {
        var min = @as(constants.PiecesSize, 0);
        var max = @as(constants.PiecesSize, @intCast(pieces.len));
        return while (min < max) {
            const i = min + (max - min) / 2;
            const p = pieces[i];
            if (p.id < piece.id) {
                min = i + 1;
            } else if (piece.id < p.id) {
                max = i;
            } else {
                std.debug.assert(piece.id == p.id);
                break if (std.meta.eql(piece, p))
                    i
                else
                    null;
            }
        } else null;
    }

    pub fn moved_to(piece: Piece, pos: Position) Piece {
        var new_piece = piece;
        new_piece.pos = pos;
        return new_piece;
    }
};

pub const Path = utils.Buffer(Model.Direction, constants.PathSize, constants.max_path);

pub const constants = struct {
    pub const max_map_storage = 256;
    pub const max_pieces = 128;
    pub const PiecesSize = u8;

    pub const PieceID = u32;

    pub const Energy = u3;

    pub const max_path = 15;
    pub const PathSize = u4;
};

test "Model.refAllDeclsRecursive" {
    std.testing.refAllDeclsRecursive(@This());
}
