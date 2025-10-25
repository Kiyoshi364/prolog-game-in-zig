const sim_c = @cImport({
    @cInclude("simulation.h");
});

pub const StartingError = error{
    NotEnoughMemory,
    InternalError,
};

pub const StartingErrorInfo = struct {
    len: u64,

    pub const empty = StartingErrorInfo{
        .len = 0,
    };
};

pub fn starting_config(config_buffer: []u8, err_info_opt: ?*StartingErrorInfo) StartingError![]const u8 {
    var len = @as(u64, config_buffer.len);
    if (!sim_c.starting_config(config_buffer.ptr, &len)) {
        if (config_buffer.len < len) {
            if (err_info_opt) |err_info| {
                err_info.*.len = len;
            }
            return error.NotEnoughMemory;
        } else {
            if (err_info_opt) |err_info| {
                err_info.*.len = len;
            }
            return error.InternalError;
        }
    }
    return config_buffer[0..len];
}

pub fn starting_state(config: []const u8, state_buffer: []u8, err_info_opt: ?*StartingErrorInfo) StartingError![]u8 {
    var len = @as(u64, state_buffer.len);
    if (!sim_c.starting_state(config.ptr, config.len, state_buffer.ptr, &len)) {
        if (state_buffer.len < len) {
            if (err_info_opt) |err_info| {
                err_info.*.len = len;
            }
            return error.NotEnoughMemory;
        } else {
            if (err_info_opt) |err_info| {
                err_info.*.len = len;
            }
            return error.InternalError;
        }
    }
    return state_buffer[0..len];
}

pub fn state_step(input: []const u8, config: []const u8, state: []const u8, out_state: []u8) ?[]u8 {
    var len = @as(u64, out_state.len);
    return if (sim_c.state_step(
        input.ptr,
        input.len,
        config.ptr,
        config.len,
        state.ptr,
        state.len,
        out_state.ptr,
        &len,
    )) out_state[0..len] else null;
}

pub fn state_draw(ctx: ?*anyopaque, renderer: *const sim_c.Renderer, config: []const u8, state: []const u8) void {
    sim_c.state_draw(
        ctx,
        renderer,
        config.ptr,
        config.len,
        state.ptr,
        state.len,
    );
}
