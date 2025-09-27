const std = @import("std");

// TODO: make a wrapper
const sim_c = @cImport({
    @cInclude("simulation.h");
});

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
        var len = @as(u64, config_buffer.len);
        if (!sim_c.starting_config(&config_buffer, &len)) {
            if (config_buffer.len < len) {
                std.debug.print("{} < {}\n", .{ config_buffer.len, len });
                return error.NotEnoughMemoryForConfig;
            } else {
                std.debug.print("Internal Error: {}\n", .{len});
                return error.InternalErrorForConfig;
            }
        }
        break :blk config_buffer[0..len];
    };

    var state = blk: {
        var len = @as(u64, state_buffer.len);
        if (!sim_c.starting_state(config.ptr, config.len, &state_buffer, &len)) {
            if (state_buffer.len < len) {
                std.debug.print("{} < {}\n", .{ state_buffer.len, len });
                return error.NotEnoughMemoryForState;
            } else {
                std.debug.print("Internal Error: {}\n", .{len});
                return error.InternalErrorForState;
            }
        }
        break :blk state_buffer[0..len];
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

        var len = @as(u64, state_buffer_len);
        if (sim_c.state_step(
            state_input_buf.ptr,
            state_input_buf.len,
            config.ptr,
            config.len,
            state.ptr,
            state.len,
            state_.ptr,
            &len,
        )) {
            state_ = state_[0..len];
        } else unreachable;

        renderer.draw_(state_, config);
    }
}
