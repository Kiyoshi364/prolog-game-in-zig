const std = @import("std");

const utils = @import("utils");

const Model = @import("Model.zig");
const State = @import("State.zig");

const Backend = @import("sim.zig").RenderBackend;
const Color = Backend.Color;
const ScreenPos = Backend.ScreenPos;

const Renderer = @This();

windows: [Window.Tag.count]Window,
tile: Tile,
piece: Piece,
map_cursor: MapCursor,
timestate: TimeState,
path: Path,

pub const default = Renderer{
    .windows = std.enums.directEnumArray(Window.Tag, Window, 0, .{
        .board = .{
            .x = 0,
            .y = 0,
            .width = 592,
            .height = 600,
        },
        .timeline = .{
            .x = 592,
            .y = 0,
            .width = 208,
            .height = 600,
        },
    }),
    .tile = Tile.default,
    .piece = Piece.default,
    .map_cursor = MapCursor.default,
    .timestate = TimeState.default,
    .path = Path.default,
};

pub fn draw(renderer: Renderer, backend: *Backend, state: State, model_config: Model.Config) void {
    backend.clear_background(Backend.lightgray);

    const model = state.get_curr_model();

    renderer.begin_window_mode(backend, .board);

    renderer.draw_map(backend, &model_config.map);
    renderer.draw_pieces_anims(backend, model.pieces.slice(), model_config.piece, state.anims.slice());
    renderer.draw_map_cursor(backend, state.map_cursor, state.active_cursor);

    renderer.end_window_mode(backend, .board);
    renderer.begin_window_mode(backend, .timeline);

    renderer.draw_timeline(backend, state.time_cursor, state.active_cursor);

    renderer.end_window_mode(backend, .timeline);
}

pub const Window = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub const Tag = enum {
        board,
        timeline,

        pub const count = @typeInfo(@This()).@"enum".fields.len;
    };

    inline fn begin_clip(window: Window, backend: *Backend, tag: Tag) void {
        backend.begin_window_mode(@intFromEnum(tag), window.x, window.y, window.width, window.height);
    }

    inline fn end_clip(window: Window, backend: *Backend, tag: Tag) void {
        _ = window;
        backend.end_window_mode(@intFromEnum(tag));
    }
};

pub const Tile = struct {
    size: u8,
    initial_pad: u8,
    pad: u8,
    outline_size: u8,

    color: Color,
    outline_color: Color,

    pub const default = Tile{
        .size = 64,
        .initial_pad = 8,
        .pad = 8,
        .outline_size = 1,

        .color = Backend.black,
        .outline_color = Backend.raywhite,
    };

    fn translate_tile_to_screen(rtile: Renderer.Tile, x: i32, y: i32) ScreenPos {
        const step = rtile.size + rtile.outline_size + rtile.pad;
        return .{
            .x = step * x + rtile.initial_pad,
            .y = step * y + rtile.initial_pad,
        };
    }

    fn draw_tile(rtile: *const Renderer.Tile, backend: *Backend, tile: Model.Config.Tile, x: i32, y: i32) void {
        std.debug.assert(tile == .empty);
        const t = rtile.translate_tile_to_screen(x, y);
        backend.draw_rect_outline(t.x, t.y, rtile.size, rtile.size, rtile.color, rtile.outline_size, rtile.outline_color);
    }
};

pub const Piece = struct {
    outline_size: u8,
    outline_color: Color,
    color: Color,

    kinds_factor_size: [Model.Piece.Kind.count]u8,
    kinds_div_size: [Model.Piece.Kind.count]u8,

    energy: Energy,

    pub const default = Piece{
        .outline_size = 1,
        .outline_color = Backend.gold,
        .color = Backend.red,

        .kinds_factor_size = std.enums.directEnumArray(Model.Piece.Kind, u8, 0, .{
            .capitan = 1,
            .minion = 1,
        }),
        .kinds_div_size = std.enums.directEnumArray(Model.Piece.Kind, u8, 0, .{
            .capitan = 3,
            .minion = 6,
        }),

        .energy = Energy.default,
    };

    pub const Energy = struct {
        size_frac: u8,
        size_div: u8,

        used_frac: u8,
        used_div: u8,

        pub const default = Energy{
            .size_frac = 1,
            .size_div = 16,

            .used_frac = 5,
            .used_div = 8,
        };

        fn draw_energies(renergy: *const Renderer.Piece.Energy, renderer: *const Renderer, backend: *Backend, radius: u8, energy_usable: Model.constants.Energy, energy_count: Model.constants.Energy, t: ScreenPos) void {
            const rtile = renderer.tile;
            const rpiece = renderer.piece;

            var x = t.x;
            const splits = 2 * @as(i32, energy_count) + 1 + 2;

            var it = utils.LenSpliter(i32).init_iterator(rtile.size, splits);
            // Note: start Pad
            x += it.next().?;
            // Note: first inner Pad
            x += it.next().?;
            for (0..energy_count) |i| {
                const is_energy_used = i < energy_usable;
                const color = if (is_energy_used)
                    rpiece.color
                else
                    Color{
                        .r = @intCast(@as(u16, rpiece.color.r) * renergy.used_frac / renergy.used_div),
                        .g = @intCast(@as(u16, rpiece.color.g) * renergy.used_frac / renergy.used_div),
                        .b = @intCast(@as(u16, rpiece.color.b) * renergy.used_frac / renergy.used_div),
                        .a = 0xFF,
                    };
                const outline_color = if (is_energy_used) rpiece.outline_color else Color{ .a = 0 };

                {
                    const step = it.next().?;
                    backend.draw_circ_outline(
                        x + step / 2,
                        t.y + rtile.size - 2 * radius,
                        @floatFromInt(radius),
                        color,
                        1,
                        outline_color,
                    );
                    x += step;
                }
                // Note: inner Pad
                x += it.next().?;
            }
            // Note: end pad
            x += it.next().?;
            std.debug.assert(it.next() == null);
        }
    };

    fn draw_piece(rpiece: *const Renderer.Piece, backend: *Backend, piece: Model.Piece, pconfig: Model.Config.PieceConfig) void {
        const renderer = @as(*const Renderer, @alignCast(@fieldParentPtr("piece", rpiece)));

        const t = renderer.tile.translate_tile_to_screen(piece.pos.x, piece.pos.y);
        rpiece.draw_piece_at(renderer, backend, piece, pconfig, t);
    }

    fn draw_piece_anim(rpiece: *const Renderer.Piece, backend: *Backend, piece: Model.Piece, pconfig: Model.Config.PieceConfig, anim: State.Animation) void {
        const renderer = @as(*const Renderer, @alignCast(@fieldParentPtr("piece", rpiece)));
        const rtile = renderer.tile;

        const t = @as(ScreenPos, switch (anim.state) {
            .move => |move| if (move.path_idx < move.path.size) blk: {
                const a = move.path.get(move.path_idx).toAddData();
                const t0 = rtile.translate_tile_to_screen(move.curr_pos.x, move.curr_pos.y);

                const speed = rtile.size - @divTrunc(
                    @as(i32, move.timer) * rtile.size,
                    State.constants.animation_start_timer,
                );

                const ax = a.x * speed;
                const ay = a.y * speed;
                break :blk if (a.adds)
                    .{ .x = t0.x + @as(i32, ax), .y = t0.y + @as(i32, ay) }
                else
                    .{ .x = t0.x - @as(i32, ax), .y = t0.y - @as(i32, ay) };
            } else rtile.translate_tile_to_screen(move.curr_pos.x, move.curr_pos.y),
        });
        rpiece.draw_piece_at(renderer, backend, piece, pconfig, t);
    }

    fn draw_piece_at(rpiece: Renderer.Piece, renderer: *const Renderer, backend: *Backend, piece: Model.Piece, pconfig: Model.Config.PieceConfig, t: ScreenPos) void {
        const rtile = renderer.tile;

        const piece_factor_size = rpiece.kinds_factor_size[@intFromEnum(piece.kind)];
        const piece_div_size = rpiece.kinds_div_size[@intFromEnum(piece.kind)];
        const piece_size = rtile.size * piece_factor_size / piece_div_size;

        switch (piece.kind) {
            .capitan => {
                const pad = (rtile.size - piece_size + 1) / 2;
                backend.draw_rect_outline(
                    t.x + pad,
                    t.y + pad,
                    piece_size,
                    piece_size,
                    rpiece.color,
                    rpiece.outline_size,
                    rpiece.outline_color,
                );
            },
            .minion => {
                const pad = rtile.size / 2;
                backend.draw_circ_outline(
                    t.x + pad,
                    t.y + pad,
                    @floatFromInt(piece_size),
                    rpiece.color,
                    rpiece.outline_size,
                    rpiece.outline_color,
                );
            },
        }

        const radius = rtile.size * rpiece.energy.size_frac / rpiece.energy.size_div;
        const max_energy = @max(
            pconfig.starting_energies[@intFromEnum(piece.kind)],
            piece.energy,
        );
        rpiece.energy.draw_energies(renderer, backend, radius, piece.energy, max_energy, t);
    }
};

pub const MapCursor = struct {
    colors: [State.CursorTag.count][State.MapCursor.Selection.count]Color,
    outline_size: u8,
    outline_color: Color,

    pub const default = MapCursor{
        .colors = std.enums.directEnumArray(State.CursorTag, [State.MapCursor.Selection.count]Color, 0, .{
            .map = std.enums.directEnumArray(State.MapCursor.Selection.@"enum", Color, 0, .{
                .none = Backend.magenta,
                .piece = Backend.orange,
            }),
            .time = std.enums.directEnumArray(State.MapCursor.Selection.@"enum", Color, 0, .{
                .none = Backend.pink,
                .piece = Backend.yellow,
            }),
        }),

        .outline_size = 1,
        .outline_color = Backend.gold,
    };

    fn draw_map_cursor_rect(rmcursor: *const Renderer.MapCursor, backend: *Backend, t: ScreenPos, cursor_color: Color) void {
        const renderer = @as(*const Renderer, @alignCast(@fieldParentPtr("map_cursor", rmcursor)));
        const rtile = renderer.tile;

        const diff = rtile.size / 16;
        const tile_size_1_8 = rtile.size / 8;
        const tile_size_3_8 = 3 * tile_size_1_8;
        const c = cursor_color;
        const oc = rmcursor.outline_color;

        const Rect = struct { x: i32, y: i32, w: i32, h: i32, c: Color };
        const rectangles = blk: {
            const small = @as(i32, tile_size_1_8);
            const big = @as(i32, tile_size_3_8);
            const o_small = small + 2 * rmcursor.outline_size;
            const o_big = big + 2 * rmcursor.outline_size;

            const x_min = t.x - diff;
            const y_min = t.y - diff;
            const x_max = t.x + rtile.size + diff;
            const y_max = t.y + rtile.size + diff;

            const ox_min = x_min - rmcursor.outline_size;
            const oy_min = y_min - rmcursor.outline_size;
            const ox_max = x_max + rmcursor.outline_size;
            const oy_max = y_max + rmcursor.outline_size;

            const x_min2 = x_min + small;
            const y_min2 = y_min + small;
            const x_max2 = x_max - small;
            const y_max2 = y_max - small;

            const ox_min2 = x_min2 + rmcursor.outline_size;
            const oy_min2 = y_min2 + rmcursor.outline_size;
            const ox_max2 = x_max2 - rmcursor.outline_size;
            const oy_max2 = y_max2 - rmcursor.outline_size;

            break :blk [_]Rect{
                .{ .x = ox_min, .y = oy_min, .w = o_big, .h = o_small, .c = oc },
                .{ .x = ox_min, .y = oy_min, .w = o_small, .h = o_big, .c = oc },
                .{ .x = x_min, .y = y_min, .w = big, .h = small, .c = c },
                .{ .x = x_min, .y = y_min, .w = small, .h = big, .c = c },

                .{ .x = ox_min, .y = oy_max2, .w = o_big, .h = o_small, .c = oc },
                .{ .x = ox_min2, .y = oy_max, .w = -o_small, .h = -o_big, .c = oc },
                .{ .x = x_min, .y = y_max2, .w = big, .h = small, .c = c },
                .{ .x = x_min2, .y = y_max, .w = -small, .h = -big, .c = c },

                .{ .x = ox_max, .y = oy_max, .w = -o_big, .h = -o_small, .c = oc },
                .{ .x = ox_max, .y = oy_max, .w = -o_small, .h = -o_big, .c = oc },
                .{ .x = x_max, .y = y_max, .w = -big, .h = -small, .c = c },
                .{ .x = x_max, .y = y_max, .w = -small, .h = -big, .c = c },

                .{ .x = ox_max, .y = oy_min2, .w = -o_big, .h = -o_small, .c = oc },
                .{ .x = ox_max2, .y = oy_min, .w = o_small, .h = o_big, .c = oc },
                .{ .x = x_max, .y = y_min2, .w = -big, .h = -small, .c = c },
                .{ .x = x_max2, .y = y_min, .w = small, .h = big, .c = c },
            };
        };

        for (rectangles) |rect| {
            backend.draw_rect(rect.x, rect.y, rect.w, rect.h, rect.c);
        }
    }
};

pub const TimeState = struct {
    width: u8,
    height: u8,
    initial_pad: u8,
    pad: u8,
    indent: u8,
    outline_size: u8,

    color: [State.CursorTag.count][Highlight.count]Color,
    outline_color: Color,

    line_height: u8,

    pub const default = TimeState{
        .width = 128,
        .height = 32,
        .initial_pad = 8,
        .pad = 8,
        .indent = 16,
        .outline_size = 1,

        .color = std.enums.directEnumArray(State.CursorTag, [Highlight.count]Color, 0, .{
            .map = std.enums.directEnumArray(Highlight, Color, 0, .{
                .unrelated = Backend.black,
                .ancestral = Backend.skyblue,
                .parent = Backend.blue,
                .current = Backend.orange,
                .sibling = Backend.darkgreen,
                .child = Backend.magenta,
                .descendant = Backend.purple,
            }),
            .time = std.enums.directEnumArray(Highlight, Color, 0, .{
                .unrelated = Backend.black,
                .ancestral = Backend.skyblue,
                .parent = Backend.blue,
                .current = Backend.red,
                .sibling = Backend.darkgreen,
                .child = Backend.magenta,
                .descendant = Backend.purple,
            }),
        }),
        .outline_color = Backend.raywhite,

        .line_height = 3,
    };

    pub const Highlight = enum {
        unrelated,
        ancestral,
        parent,
        current,
        sibling,
        child,
        descendant,

        pub const count = @typeInfo(@This()).@"enum".fields.len;
    };

    fn draw_line(rtimestate: *const Renderer.TimeState, backend: *Backend, x: i32, y: i32, active_cursor: State.CursorTag, highlight: Renderer.TimeState.Highlight) void {
        const color = rtimestate.color[@intFromEnum(active_cursor)][@intFromEnum(highlight)];
        const width = rtimestate.width + rtimestate.outline_size;
        for (0..rtimestate.line_height) |i| {
            const yi = y + @as(i32, @intCast(i));
            backend.draw_line(x, yi, width, yi, color);
        }
    }

    // TODO: do something with the input to get to this state
    fn draw_timestate(rtimestate: *const Renderer.TimeState, backend: *Backend, x: i32, y: i32, active_cursor: State.CursorTag, highlight: Renderer.TimeState.Highlight) void {
        const color = rtimestate.color[@intFromEnum(active_cursor)][@intFromEnum(highlight)];
        const width = rtimestate.width - x;
        backend.draw_rect_outline(x, y, width, rtimestate.height, color, rtimestate.outline_size, rtimestate.outline_color);
    }
};

pub const Path = struct {
    color: Color,

    pub const default = Path{
        .color = Backend.green,
    };

    fn draw_path(rpath: *const Renderer.Path, backend: *Backend, t: ScreenPos, path: []const Model.Direction) void {
        const renderer = @as(*const Renderer, @alignCast(@fieldParentPtr("path", rpath)));
        const rtile = renderer.tile;

        const half_tile_size = rtile.size / 2;
        const step = rtile.size + rtile.outline_size + rtile.pad;

        var t1 = ScreenPos{
            .x = t.x + half_tile_size,
            .y = t.y + half_tile_size,
        };
        for (0..path.len) |pre_i| {
            const i = path.len - pre_i - 1;
            const p = path[i];
            const t0 = @as(ScreenPos, switch (p) {
                .up => .{ .x = t1.x, .y = t1.y + step },
                .right => .{ .x = t1.x - step, .y = t1.y },
                .down => .{ .x = t1.x, .y = t1.y - step },
                .left => .{ .x = t1.x + step, .y = t1.y },
            });
            backend.draw_line(t0.x, t0.y, t1.x, t1.y, rpath.color);
            t1 = t0;
        }
    }
};

fn begin_window_mode(renderer: Renderer, backend: *Backend, tag: Window.Tag) void {
    renderer.windows[@intFromEnum(tag)].begin_clip(backend, tag);
}

fn end_window_mode(renderer: Renderer, backend: *Backend, tag: Window.Tag) void {
    renderer.windows[@intFromEnum(tag)].end_clip(backend, tag);
}

fn draw_map(renderer: Renderer, backend: *Backend, map: *const Model.Config.MapConfig) void {
    std.debug.assert(backend.curr_tag == @intFromEnum(Window.Tag.board));
    const offset = map.bounds.y * map.bounds.x - 1;
    for ([_]bool{ false, true }) |mirrored| {
        for (map.map(), 0..) |tile, pre_idx| {
            const idx = if (mirrored) offset - pre_idx else pre_idx;
            const y = idx / map.bounds.x;
            const x = idx % map.bounds.x;
            renderer.tile.draw_tile(backend, tile, @intCast(x), @intCast(y));
        }
    }
}

fn draw_pieces_anims(renderer: Renderer, backend: *Backend, pieces: []const Model.Piece, pconfig: Model.Config.PieceConfig, anims: []const State.Animation) void {
    var anim_idx = @as(Model.constants.PiecesSize, 0);
    for (pieces) |piece| {
        if (anim_idx < anims.len and piece.id == anims[anim_idx].piece_id) {
            const anim = anims[anim_idx];
            renderer.piece.draw_piece_anim(backend, piece, pconfig, anim);
            anim_idx += 1;
        } else {
            std.debug.assert(anims.len <= anim_idx or piece.id < anims[anim_idx].piece_id);
            renderer.piece.draw_piece(backend, piece, pconfig);
        }
    }
}

fn draw_map_cursor(renderer: Renderer, backend: *Backend, map_cursor: State.MapCursor, active_cursor: State.CursorTag) void {
    const t = renderer.tile.translate_tile_to_screen(map_cursor.pos.x, map_cursor.pos.y);

    const cursor_color = renderer.map_cursor.colors[@intFromEnum(active_cursor)][@intFromEnum(map_cursor.selection)];

    switch (map_cursor.selection) {
        .none => {},
        .piece => |piece| renderer.path.draw_path(backend, t, piece.path.slice()),
    }

    renderer.map_cursor.draw_map_cursor_rect(backend, t, cursor_color);
}

// TODO: use time_cursor.old_model_idx
fn draw_timeline(renderer: Renderer, backend: *Backend, time_cursor: State.TimeCursor, active_cursor: State.CursorTag) void {
    const Idx = @TypeOf(time_cursor.model_tree).StateIdx;
    const model_tree = time_cursor.model_tree;
    const model_idx = time_cursor.model_idx;

    const parents = model_tree.parent_states_slice();
    const len = parents.len;

    var lefts_buffer = [_]Idx{undefined} ** @TypeOf(model_tree).state_capacity;
    const lefts = model_tree.state_left_siblings(&lefts_buffer);

    var rights_buffer = [_]Idx{undefined} ** @TypeOf(model_tree).state_capacity;
    const rights = model_tree.state_right_siblings(&rights_buffer);

    var indent_diff_buffer = [_]i32{0} ** @TypeOf(model_tree).state_capacity;
    const indent_diff = if (0 < len) indent_diff: {
        var id_bufs = @as([2][@TypeOf(model_tree).state_capacity]@TypeOf(model_tree).StateIdx, undefined);
        var last_id = model_tree.get_state_id(0, &id_bufs[0]);
        var id_idx = @as(u1, 1);
        for (indent_diff_buffer[0 .. len - 1], 1..) |*out, i| {
            const curr_id = model_tree.get_state_id(@intCast(i), &id_bufs[id_idx]);

            const min_len = @min(last_id.len, curr_id.len);
            const prefix = for (last_id[0..min_len], curr_id[0..min_len], 0..) |l, c, idx| {
                if (l != c) {
                    break idx;
                }
            } else min_len;
            std.debug.assert(
                (min_len == curr_id.len and
                    prefix == min_len - 1) or
                    (min_len != curr_id.len and
                        min_len == last_id.len and
                        prefix == min_len),
            );

            var diff = @as(i32, @intFromBool(lefts[i] == i and rights[i] != i));
            out.* = for (last_id[prefix..]) |j| {
                diff -= if (lefts[j] != j and rights[j] == j) 1 else 0;
            } else diff;

            last_id = curr_id;
            id_idx ^= 1;
        }
        break :indent_diff indent_diff_buffer[0 .. len - 1];
    } else indent_diff_buffer[0 .. len - 1];

    var highlights_buffer = [_]Renderer.TimeState.Highlight{.unrelated} ** @TypeOf(model_tree).state_capacity;
    const highlights = highlights: {
        {
            var it = model_idx;
            var curr_highlight = Renderer.TimeState.Highlight.current;
            while (it != parents[it]) : (it = parents[it]) {
                highlights_buffer[it] = curr_highlight;
                curr_highlight = switch (curr_highlight) {
                    .current => .parent,
                    .parent => .ancestral,
                    .ancestral => .ancestral,
                    else => unreachable,
                };
            }
            highlights_buffer[it] = curr_highlight;
        }
        for (highlights_buffer[0..len], parents, 0..) |*out, pi, i| {
            if (out.* != .unrelated) {
                continue;
            }
            var it = @as(Idx, @intCast(i));
            var depth = @as(Idx, 0);
            while (it != parents[it] and it != model_idx) : (it = parents[it]) {
                depth += 1;
            }
            out.* = if (it == model_idx)
                if (depth <= 1)
                    .child
                else
                    .descendant
            else if (parents[model_idx] == pi)
                .sibling
            else
                .unrelated;
        }
        break :highlights highlights_buffer[0..len];
    };

    if (0 < len) {
        var indent = @as(i32, 0);
        var x = @as(i32, renderer.timestate.initial_pad);
        var y = @as(i32, renderer.timestate.initial_pad);

        renderer.timestate.draw_timestate(backend, x, y, active_cursor, highlights[0]);
        y += renderer.timestate.pad + renderer.timestate.height;

        for (1..len) |i| {
            indent += indent_diff[i - 1];
            x += indent_diff[i - 1] * renderer.timestate.indent;

            std.debug.assert(x == renderer.timestate.initial_pad + indent * (renderer.timestate.indent));
            const has_left_sibling = parents[i] != i - 1;

            if (has_left_sibling) {
                renderer.timestate.draw_line(backend, x, y - renderer.timestate.pad / 2, active_cursor, highlights[i]);
                y += renderer.timestate.line_height;
            } else {
                // Nothing
            }

            renderer.timestate.draw_timestate(backend, x, y, active_cursor, highlights[i]);
            y += renderer.timestate.pad + renderer.timestate.height;
        }
    }
}
