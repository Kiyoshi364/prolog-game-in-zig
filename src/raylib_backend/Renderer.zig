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

    // TODO
}

fn translate_tile_to_screen(x: c_int, y: c_int) struct { x: c_int, y: c_int } {
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
