const std = @import("std");

const simulation = @import("simulation");
const utils = @import("utils");

const Model = simulation.Model;
const State = simulation.State;

const raylib = @cImport({
    @cInclude("raylib.h");
});

tile: Tile = .{},
piece: Piece = .{},
map_cursor: MapCursor = .{},
// TODO: time_cursor: TimeCursor = .{},
path: Path = .{},

const RaylibRenderer = @This();

pub fn draw(renderer: RaylibRenderer, state: State, model_config: Model.Config) void {
    raylib.BeginDrawing();

    raylib.ClearBackground(raylib.LIGHTGRAY);

    const model = state.get_curr_model();
    renderer.draw_map(&model_config.map);
    renderer.draw_pieces_anims(model.pieces.slice(), model_config.piece, state.anims.slice());
    renderer.draw_map_cursor(state.map_cursor);

    raylib.EndDrawing();
}

const ScreenPos = struct { x: c_int, y: c_int };

pub const Tile = struct {
    size: u8 = 64,
    initial_pad: u8 = 16,
    pad: u8 = 8,
    outline_size: u8 = 1,

    color: raylib.Color = raylib.BLACK,
    outline_color: raylib.Color = raylib.RAYWHITE,

    fn translate_tile_to_screen(rtile: RaylibRenderer.Tile, x: c_int, y: c_int) ScreenPos {
        const step = rtile.size + rtile.outline_size + rtile.pad;
        return .{
            .x = step * x + rtile.initial_pad,
            .y = step * y + rtile.initial_pad,
        };
    }

    fn draw_tile(rtile: RaylibRenderer.Tile, tile: Model.Config.Tile, x: c_int, y: c_int) void {
        std.debug.assert(tile == .empty);

        const t = rtile.translate_tile_to_screen(x, y);
        draw_rect_outline(t.x, t.y, rtile.size, rtile.size, rtile.color, rtile.outline_size, rtile.outline_color);
    }
};

pub const Piece = struct {
    outline_size: u8 = 1,
    outline_color: raylib.Color = raylib.GOLD,
    color: raylib.Color = raylib.RED,

    kinds_factor_size: [Model.Piece.Kind.count]u8 = std.enums.directEnumArray(Model.Piece.Kind, u8, 0, .{
        .capitan = 1,
        .minion = 1,
    }),
    kinds_div_size: [Model.Piece.Kind.count]u8 = std.enums.directEnumArray(Model.Piece.Kind, u8, 0, .{
        .capitan = 3,
        .minion = 6,
    }),

    fn draw_piece(rpiece: RaylibRenderer.Piece, rtile: RaylibRenderer.Tile, piece: Model.Piece, pconfig: Model.Config.PieceConfig) void {
        const t = rtile.translate_tile_to_screen(piece.pos.x, piece.pos.y);
        rpiece.draw_piece_at(rtile, piece, pconfig, t);
    }

    fn draw_piece_anim(rpiece: RaylibRenderer.Piece, rtile: RaylibRenderer.Tile, piece: Model.Piece, pconfig: Model.Config.PieceConfig, anim: State.Animation) void {
        const t = @as(ScreenPos, switch (anim.state) {
            .move => |move| blk: {
                const a = move.path.get(move.path_idx).toAddData();
                const t0 = rtile.translate_tile_to_screen(move.curr_pos.x, move.curr_pos.y);

                const speed = rtile.size - @divTrunc(
                    @as(c_int, move.timer) * rtile.size,
                    State.constants.animation_start_timer,
                );

                const ax = a.x * speed;
                const ay = a.y * speed;
                break :blk if (a.adds)
                    .{ .x = t0.x + @as(c_int, ax), .y = t0.y + @as(c_int, ay) }
                else
                    .{ .x = t0.x - @as(c_int, ax), .y = t0.y - @as(c_int, ay) };
            },
        });
        rpiece.draw_piece_at(rtile, piece, pconfig, t);
    }

    fn draw_piece_at(rpiece: RaylibRenderer.Piece, rtile: RaylibRenderer.Tile, piece: Model.Piece, pconfig: Model.Config.PieceConfig, t: ScreenPos) void {
        const piece_factor_size = rpiece.kinds_factor_size[@intFromEnum(piece.kind)];
        const piece_div_size = rpiece.kinds_div_size[@intFromEnum(piece.kind)];
        const piece_size = rtile.size * piece_factor_size / piece_div_size;

        switch (piece.kind) {
            .capitan => {
                const pad = (rtile.size - piece_size + 1) / 2;
                draw_rect_outline(
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
                draw_circ_outline(
                    t.x + pad,
                    t.y + pad,
                    @floatFromInt(piece_size),
                    rpiece.color,
                    rpiece.outline_size,
                    rpiece.outline_color,
                );
            },
        }

        {
            // TODO: extract constants to config
            const radius = rtile.size * 1 / 16;
            const max_energy = @max(
                pconfig.starting_energies[@intFromEnum(piece.kind)],
                piece.energy,
            );
            const energy_used_frac = 5;
            const energy_used_div = 8;

            var x = t.x;
            const splits = 2 * @as(c_int, max_energy) + 1 + 2;

            var it = utils.LenSpliter(c_int).init_iterator(rtile.size, splits);
            // Note: start Pad
            x += it.next().?;
            // Note: first inner Pad
            x += it.next().?;
            for (0..max_energy) |i| {
                const is_energy_used = i < piece.energy;
                const color = if (is_energy_used)
                    rpiece.color
                else
                    raylib.Color{
                        .r = @intCast(@as(u16, rpiece.color.r) * energy_used_frac / energy_used_div),
                        .g = @intCast(@as(u16, rpiece.color.g) * energy_used_frac / energy_used_div),
                        .b = @intCast(@as(u16, rpiece.color.b) * energy_used_frac / energy_used_div),
                        .a = 0xFF,
                    };
                const outline_color = if (is_energy_used) rpiece.outline_color else raylib.Color{ .a = 0 };

                {
                    const step = it.next().?;
                    draw_circ_outline(
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
    }
};

pub const MapCursor = struct {
    colors: [State.MapCursor.Selection.count]raylib.Color = std.enums.directEnumArray(State.MapCursor.Selection.@"enum", raylib.Color, 0, .{
        .none = raylib.PINK,
        .piece = raylib.ORANGE,
    }),

    outline_size: u8 = 1,
    outline_color: raylib.Color = raylib.GOLD,

    fn draw_map_cursor_rect(rmcursor: RaylibRenderer.MapCursor, rtile: RaylibRenderer.Tile, t: ScreenPos, cursor_color: raylib.Color) void {
        const diff = rtile.size / 16;
        const tile_size_1_8 = rtile.size / 8;
        const tile_size_3_8 = 3 * tile_size_1_8;
        const c = cursor_color;
        const oc = rmcursor.outline_color;

        const Rect = struct { x: c_int, y: c_int, w: c_int, h: c_int, c: raylib.Color };
        const rectangles = blk: {
            const small = @as(c_int, tile_size_1_8);
            const big = @as(c_int, tile_size_3_8);
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
            raylib.DrawRectangle(rect.x, rect.y, rect.w, rect.h, rect.c);
        }
    }
};

pub const Path = struct {
    color: raylib.Color = raylib.GREEN,

    fn draw_path(rpath: RaylibRenderer.Path, rtile: RaylibRenderer.Tile, t: ScreenPos, path: []const Model.Direction) void {
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
            raylib.DrawLine(t0.x, t0.y, t1.x, t1.y, rpath.color);
            t1 = t0;
        }
    }
};

fn draw_map(renderer: RaylibRenderer, map: *const Model.Config.MapConfig) void {
    const offset = map.bounds.y * map.bounds.x - 1;
    for ([_]bool{ false, true }) |mirrored| {
        for (map.map(), 0..) |tile, pre_idx| {
            const idx = if (mirrored) offset - pre_idx else pre_idx;
            const y = idx / map.bounds.x;
            const x = idx % map.bounds.x;
            renderer.tile.draw_tile(tile, @intCast(x), @intCast(y));
        }
    }
}

fn draw_pieces_anims(renderer: RaylibRenderer, pieces: []const Model.Piece, pconfig: Model.Config.PieceConfig, anims: []const State.Animation) void {
    var anim_idx = @as(Model.constants.PiecesSize, 0);
    for (pieces) |piece| {
        if (anim_idx < anims.len and piece.id == anims[anim_idx].piece_id) {
            const anim = anims[anim_idx];
            renderer.piece.draw_piece_anim(renderer.tile, piece, pconfig, anim);
            anim_idx += 1;
        } else {
            std.debug.assert(anims.len <= anim_idx or piece.id < anims[anim_idx].piece_id);
            renderer.piece.draw_piece(renderer.tile, piece, pconfig);
        }
    }
}

// TODO: ask for active_cursor
fn draw_map_cursor(renderer: RaylibRenderer, map_cursor: State.MapCursor) void {
    const t = renderer.tile.translate_tile_to_screen(map_cursor.pos.x, map_cursor.pos.y);

    const cursor_color = renderer.map_cursor.colors[@intFromEnum(map_cursor.selection)];

    switch (map_cursor.selection) {
        .none => {},
        .piece => |piece| renderer.path.draw_path(renderer.tile, t, piece.path.slice()),
    }

    renderer.map_cursor.draw_map_cursor_rect(renderer.tile, t, cursor_color);
}

///////////////////////// Raylib Abstraction Interface /////////////////////////

fn draw_rect_outline(
    x: c_int,
    y: c_int,
    w: c_int,
    h: c_int,
    color: raylib.Color,
    outline_size: c_int,
    outline_color: raylib.Color,
) void {
    const ox = x - outline_size;
    const oy = y - outline_size;
    const ow = w + 2 * outline_size;
    const oh = h + 2 * outline_size;
    raylib.DrawRectangle(ox, oy, ow, oh, outline_color);
    raylib.DrawRectangle(x, y, w, h, color);
}

fn draw_circ_outline(
    x: c_int,
    y: c_int,
    r: f32,
    color: raylib.Color,
    outline_size: c_int,
    outline_color: raylib.Color,
) void {
    raylib.DrawCircle(x, y, r + @as(f32, @floatFromInt(outline_size)), outline_color);
    raylib.DrawCircle(x, y, r, color);
}
