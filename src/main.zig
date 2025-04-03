const std = @import("std");

const simulation = @import("simulation");
const backend = @import("backend");

const raylib = @cImport({
    @cInclude("raylib.h");
});

const Model = simulation.Model;
const State = simulation.State;

const Inputer = backend.Inputer;
const Renderer = backend.Renderer;

pub fn main() !void {
    const input_config = Inputer.Config{};
    var inputer = Inputer{};
    var inputer_ = @as(Inputer, undefined);

    const model_config = blk: {
        var map_config = Model.Config.MapConfig{
            .bounds = .{ .y = 7, .x = 8 },
        };
        std.debug.assert(map_config.check());

        for (map_config.map_mut()) |*tile| {
            tile.* = .empty;
        }

        break :blk Model.Config{
            .map = map_config,
        };
    };

    var state = State{};
    {
        const init_pieces = [_]Model.Piece{
            .{ .kind = .capitan, .pos = .{ .y = 3, .x = 2 } },
            .{ .kind = .minion, .pos = .{ .y = 4, .x = 4 } },
            .{ .kind = .minion, .pos = .{ .y = 2, .x = 5 } },
        };
        state.model.pieces_size = init_pieces.len;
        for (init_pieces, state.model.pieces_mut()) |piece, *buf| {
            buf.* = piece;
        }
    }

    var state_ = @as(State, undefined);

    var renderer = Renderer{};

    raylib.InitWindow(800, 600, "Zig Window");
    raylib.SetTargetFPS(60);
    defer raylib.CloseWindow();

    while (!raylib.WindowShouldClose()) : ({
        inputer = inputer_;
        state = state_;
    }) {
        const state_input = inputer.get_input(input_config, &inputer_);

        state_ = state.step(state_input, model_config) orelse unreachable;

        raylib.BeginDrawing();

        renderer.draw(state_, model_config);

        raylib.EndDrawing();
    }
}
