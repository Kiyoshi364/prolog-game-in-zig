const std = @import("std");

const Model = @This();

pieces_buffer: [constants.max_pieces]Piece = .{undefined} ** constants.max_pieces,
pieces_size: usize = 0,

pub fn step(model: Model, model_input: ModelInput, config: Config, out_model: *Model) ?AnimationInput {
    return switch (model_input) {
        .move => |move| blk: {
            const piece_idx = for (model.pieces(), 0..) |p, i| {
                if (std.meta.eql(move.piece, p)) {
                    break i;
                }
            } else break :blk null;

            const new_pos = move.piece.pos.move_many(
                move.path,
                config.map.bounds,
            ) orelse break :blk null;

            out_model.*.pieces_size = model.pieces_size;
            for (model.pieces(), out_model.pieces_mut(), 0..) |p, *out_p, i| {
                out_p.* = if (piece_idx == i)
                    // p.moved_to(new_pos)
                    .{ .pos = new_pos, .kind = p.kind }
                else
                    p;
            }

            break :blk .none;
        },
    };
}

pub fn pieces_mut(model: *Model) []Piece {
    return model.pieces_buffer[0..model.pieces_size];
}
pub fn pieces(model: *const Model) []const Piece {
    return model.pieces_buffer[0..model.pieces_size];
}

pub const Config = struct {
    map: MapConfig = .{},

    pub const MapConfig = struct {
        map_buffer: [constants.max_map_storage]Tile = .{undefined} ** constants.max_map_storage,
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
};

pub const ModelInput = union(enum) {
    move: Move,

    pub const Move = struct {
        piece: Piece,
        path: []const Direction,
    };
};

pub const AnimationInput = union(enum) {
    none: void,
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

    pub fn move(pos: Position, dir: Direction, bounds: Position) ?Position {
        const S = struct { name: PositionTag, x: u1, y: u1, adds: bool };
        const a = @as(S, switch (dir) {
            .up => .{ .name = .y, .x = 0, .y = 1, .adds = false },
            .right => .{ .name = .x, .x = 1, .y = 0, .adds = true },
            .down => .{ .name = .y, .x = 0, .y = 1, .adds = true },
            .left => .{ .name = .x, .x = 1, .y = 0, .adds = false },
        });
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
    pos: Position,
    kind: PieceKind,

    pub const PieceKind = enum {
        capitan,
        minion,
    };

    pub fn moved_to(piece: Piece, pos: Position) Piece {
        var new_piece = piece;
        new_piece.pos = pos;
        return new_piece;
    }
};

pub const constants = struct {
    pub const max_map_storage = 256;
    const max_pieces = 128;
};
