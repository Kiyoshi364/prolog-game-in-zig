const std = @import("std");

const simulation = @import("simulation");

const Model = simulation.Model;
const State = simulation.State;

const raylib = @cImport({
    @cInclude("raylib.h");
});

const RaylibRenderer = @This();

pub fn draw(renderer: RaylibRenderer, state: State, model_config: Model.Config) void {
    _ = renderer;

    raylib.ClearBackground(raylib.LIGHTGRAY);

    draw_map(&model_config.map);
    draw_pieces_anims(state.model.pieces(), &.{{}});
    draw_cursor(state.cursor);

    // TODO
}

const ScreenPos = struct { x: c_int, y: c_int };

fn translate_tile_to_screen(x: c_int, y: c_int) ScreenPos {
    // TODO: extract to a config
    const tile_size = 64;
    const tile_initial_pad = 16;
    const tile_pad = 8;
    const tile_outline_size = 1;

    const step = tile_size + tile_outline_size + tile_pad;
    return .{
        .x = step * x + tile_initial_pad,
        .y = step * y + tile_initial_pad,
    };
}

fn draw_map(map: *const Model.Config.MapConfig) void {
    const offset = map.bounds.y * map.bounds.x - 1;
    for ([_]bool{ false, true }) |mirrored| {
        for (map.map(), 0..) |tile, pre_idx| {
            const idx = if (mirrored) offset - pre_idx else pre_idx;
            const y = idx / map.bounds.x;
            const x = idx % map.bounds.x;
            draw_tile(tile, @intCast(x), @intCast(y));
        }
    }
}

fn draw_tile(tile: Model.Config.Tile, x: c_int, y: c_int) void {
    std.debug.assert(tile == .empty);

    // TODO: extract to a config
    const tile_color = raylib.BLACK;
    const tile_outline_color = raylib.RAYWHITE;
    const tile_size = 64;
    const tile_outline_size = 1;

    const t = translate_tile_to_screen(x, y);
    draw_rect_outline(t.x, t.y, tile_size, tile_size, tile_color, tile_outline_size, tile_outline_color);
}

fn draw_pieces_anims(pieces: []const Model.Piece, anims: []const void) void {
    _ = anims;
    for (pieces) |piece| {
        draw_piece_anim(piece, {});
    }
}

fn draw_piece_anim(piece: Model.Piece, anim: void) void {
    _ = anim;

    // TODO: extract to config
    const piece_outline_color = raylib.GOLD;
    const piece_outline_size = 1;
    const piece_color = raylib.RED;
    const tile_size = 64;

    const piece_capitan_size = tile_size / 3;
    const piece_minion_size = tile_size / 6;

    const t = translate_tile_to_screen(piece.pos.x, piece.pos.y);
    switch (piece.kind) {
        .capitan => {
            const pad = (tile_size - piece_capitan_size + 1) / 2;
            draw_rect_outline(
                t.x + pad,
                t.y + pad,
                piece_capitan_size,
                piece_capitan_size,
                piece_color,
                piece_outline_size,
                piece_outline_color,
            );
        },
        .minion => {
            const pad = tile_size / 2;
            draw_circ_outline(
                t.x + pad,
                t.y + pad,
                @floatFromInt(piece_minion_size),
                piece_color,
                piece_outline_size,
                piece_outline_color,
            );
        },
    }
}

fn draw_cursor(cursor: State.Cursor) void {
    const t = translate_tile_to_screen(cursor.pos.x, cursor.pos.y);
    const cursor_color = switch (cursor.selection) {
        .none => raylib.PINK,
        .piece => raylib.ORANGE,
    };

    switch (cursor.selection) {
        .none => {},
        .piece => |piece| draw_path(t, piece.path()),
    }

    draw_cursor_rect(t, cursor_color);
}

fn draw_path(t: ScreenPos, path: []const Model.Direction) void {
    // TODO: extract to config
    const tile_size = 64;
    const tile_pad = 8;
    const tile_outline_size = 1;
    const path_color = raylib.GREEN;

    const half_tile_size = tile_size / 2;
    const step = tile_size + tile_outline_size + tile_pad;

    var t1 = ScreenPos{
        .x = t.x + half_tile_size,
        .y = t.y + half_tile_size,
    };
    for (path, 0..) |_, pre_i| {
        const i = path.len - pre_i - 1;
        const p = path[i];
        const t0 = @as(ScreenPos, switch (p) {
            .up => .{ .x = t1.x, .y = t1.y + step },
            .right => .{ .x = t1.x - step, .y = t1.y },
            .down => .{ .x = t1.x, .y = t1.y - step },
            .left => .{ .x = t1.x + step, .y = t1.y },
        });
        raylib.DrawLine(t0.x, t0.y, t1.x, t1.y, path_color);
        t1 = t0;
    }
}

fn draw_cursor_rect(t: ScreenPos, cursor_color: raylib.Color) void {
    // TODO: extract to a config
    const tile_size = 64;
    const cursor_outline_size = 1;
    const cursor_outline_color = raylib.GOLD;

    const diff = tile_size / 16;
    const tile_size_1_8 = tile_size / 8;
    const tile_size_3_8 = 3 * tile_size_1_8;
    const c = cursor_color;
    const oc = cursor_outline_color;

    const Rect = struct { x: c_int, y: c_int, w: c_int, h: c_int, c: raylib.Color };
    const rectangles = blk: {
        const small = tile_size_1_8;
        const big = tile_size_3_8;
        const o_small = small + 2 * cursor_outline_size;
        const o_big = big + 2 * cursor_outline_size;

        const x_min = t.x - diff;
        const y_min = t.y - diff;
        const x_max = t.x + tile_size + diff;
        const y_max = t.y + tile_size + diff;

        const ox_min = x_min - cursor_outline_size;
        const oy_min = y_min - cursor_outline_size;
        const ox_max = x_max + cursor_outline_size;
        const oy_max = y_max + cursor_outline_size;

        const x_min2 = x_min + small;
        const y_min2 = y_min + small;
        const x_max2 = x_max - small;
        const y_max2 = y_max - small;

        const ox_min2 = x_min2 + cursor_outline_size;
        const oy_min2 = y_min2 + cursor_outline_size;
        const ox_max2 = x_max2 - cursor_outline_size;
        const oy_max2 = y_max2 - cursor_outline_size;

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

///////////////////////// Raylib Interface /////////////////////////

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
