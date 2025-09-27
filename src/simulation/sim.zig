const std = @import("std");

const simulation = @cImport({
    @cInclude("simulation.h");
});

pub const Model = @import("Model.zig");
pub const State = @import("State.zig");

fn starting_config_(buf: [*c]u8, len: [*c]u64) callconv(.c) bool {
    return starting_config(buf[0..len.*], len);
}

pub fn starting_config(config_buf: []u8, out_len: *u64) bool {
    const config_size = @sizeOf(Model.Config);
    out_len.* = config_size;

    if (config_buf.len < config_size) {
        return false;
    }

    // TODO: compress config
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

    @memcpy(config_buf[0..config_size], @as(*const [config_size]u8, @ptrCast(&model_config)));
    return true;
}

fn starting_state_(config: [*c]const u8, config_len: u64, buf: [*c]u8, len: [*c]u64) callconv(.c) bool {
    return starting_state(config[0..config_len], buf[0..len.*], len);
}

pub fn starting_state(config_buf: []const u8, buf: []u8, out_len: *u64) bool {
    std.debug.assert(@sizeOf(Model.Config) <= config_buf.len);
    const model_config = @as(*const Model.Config, @ptrCast(config_buf));

    const state_size = @sizeOf(State);
    out_len.* = state_size;
    if (buf.len < state_size) {
        return false;
    }

    const state = blk: {
        const init_pieces = [_]Model.Piece{
            .{ .kind = .capitan, .pos = .{ .y = 3, .x = 2 } },
            .{ .kind = .minion, .pos = .{ .y = 4, .x = 4 } },
            .{ .kind = .minion, .pos = .{ .y = 2, .x = 5 } },
        };
        var model = Model.empty;
        var pieces = @TypeOf(model.pieces).Builder{};
        pieces.push_slice_mut(&init_pieces);
        for (pieces.slice_mut()) |*piece| {
            piece.*.id = model.genid_mut();
            piece.* = piece.refresh(model_config.piece);
        }
        model.pieces = pieces.frozen();
        break :blk State.with_root(model);
    };
    std.debug.assert(state.get_root_model().check());

    @memcpy(buf[0..state_size], @as(*const [state_size]u8, @ptrCast(&state)));
    return true;
}

fn state_step_(input: [*c]const u8, input_len: u64, config: [*c]const u8, config_len: u64, state: [*c]const u8, state_len: u64, out_state: [*c]u8, out_state_len: [*c]u64) callconv(.c) bool {
    return state_step(
        input[0..input_len],
        config[0..config_len],
        state[0..state_len],
        out_state[0..out_state_len.*],
        out_state_len,
    );
}

pub fn state_step(input_buf: []const u8, config_buf: []const u8, state_buf: []const u8, out_state_buf: []u8, out_state_len: *u64) bool {
    std.debug.assert(@sizeOf(State.StateInput) <= input_buf.len);
    const input = @as(*const State.StateInput, @ptrCast(input_buf)).*;

    std.debug.assert(@sizeOf(Model.Config) <= config_buf.len);
    const model_config = @as(*const Model.Config, @ptrCast(config_buf)).*;

    std.debug.assert(@sizeOf(State) <= state_buf.len);
    const state = @as(*const State, @alignCast(@ptrCast(state_buf)));

    const out_state_size = @sizeOf(State);
    out_state_len.* = out_state_size;
    if (out_state_buf.len < out_state_size) {
        return false;
    }

    return if (state.step(input, model_config)) |new_state| blk: {
        @memcpy(out_state_buf[0..out_state_size], @as(*const [out_state_size]u8, @ptrCast(&new_state)));
        break :blk true;
    } else false;

}

comptime {
    const funcs = .{
        .{
            .func = &starting_config_,
            .name = "starting_config",
            .type = @TypeOf(simulation.starting_config),
        },
        .{
            .func = &starting_state_,
            .name = "starting_state",
            .type = @TypeOf(simulation.starting_state),
        },
        .{
            .func = &state_step_,
            .name = "state_step",
            .type = @TypeOf(simulation.state_step),
        },
    };
    for (funcs) |t| {
        if (@TypeOf(t.func) != *const t.type) {
            @compileLog(t.func);
            @compileLog(t.type);
        }
        @export(t.func, .{ .name = t.name });
    }
}
