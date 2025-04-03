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

    _ = state;
    // TODO
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
    const tile_initial_pad = 16;
    const tile_pad = 8;
    const tile_outline_size = 1;

    const step = tile_size + tile_outline_size + tile_pad;
    const tx = step * x + tile_initial_pad;
    const ty = step * y + tile_initial_pad;
    draw_rect_outline(tx, ty, tile_size, tile_size, tile_color, tile_outline_size, tile_outline_color);
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
