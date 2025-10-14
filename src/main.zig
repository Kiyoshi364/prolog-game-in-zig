const std = @import("std");

const sim = @import("sim.zig");

const backend = @import("backend");

const Inputer = backend.Inputer;
const Renderer = backend.Renderer;

var config_buffer = @as([0x10]u8, undefined);

const state_buffer_len = 0x9000;
var state_buffer = @as([state_buffer_len]u8, undefined);
var state_buffer_ = @as([state_buffer_len]u8, undefined);

pub fn main() !void {
    const input_config = Inputer.Config{};
    var inputer = Inputer{};
    var inputer_ = @as(Inputer, undefined);

    const config = blk: {
        var err_info = sim.StartingErrorInfo.empty;
        break :blk sim.starting_config(&config_buffer, &err_info) catch |err| switch (err) {
            error.NotEnoughMemory => {
                std.debug.print("{} < {}\n", .{ config_buffer.len, err_info.len });
                return error.NotEnoughMemoryForStartingConfig;
            },
            error.InternalError => {
                std.debug.print("Internal Error: {}\n", .{ err_info.len });
                return error.InternalErrorForStartingConfig;
            },
        };
    };

    var state = blk: {
        var err_info = sim.StartingErrorInfo.empty;
        break :blk sim.starting_state(config, &state_buffer, &err_info) catch |err| switch (err) {
            error.NotEnoughMemory => {
                std.debug.print("{} < {}\n", .{ state_buffer.len, err_info.len });
                return error.NotEnoughMemoryForStartingState;
            },
            error.InternalError => {
                std.debug.print("Internal Error: {}\n", .{ err_info.len });
                return error.InternalErrorForStartingState;
            },
        };
    };

    var state_ = @as([]u8, state_buffer_[0..]);

    var renderer = Renderer.default;

    var window = backend.Window{
        .width = 800,
        .height = 600,
        .title = "Zig Window",
    };
    window.open();
    defer window.close();

    while (!window.should_close()) : ({
        inputer = inputer_;
        const tmp = state.ptr;
        state = state_;
        state_ = tmp[0..state_buffer_len];
    }) {
        const state_input = inputer.get_input(input_config, &inputer_);
        const state_input_buf = @as(*const [@sizeOf(@TypeOf(state_input))]u8, @ptrCast(&state_input))[0..];

        if (sim.state_step(state_input_buf, config, state, state_)) |new_state| {
            state_ = new_state;
        } else {
            return error.StateStepFailed;
        }

        renderer.draw_(state_, config);
    }
}
