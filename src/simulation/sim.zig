const std = @import("std");

const sim_c = @cImport({
    @cInclude("simulation.h");
});

pub const Model = @import("Model.zig");
pub const State = @import("State.zig");
pub const Renderer = @import("Renderer.zig");

pub const Config = struct {
    renderer: Renderer,
    model: Model.Config,
};

fn from_buffer(comptime T: type, buf: []const u8) *const T {
    std.debug.assert(@sizeOf(T) <= buf.len);
    return @as(*const T, @alignCast(@ptrCast(buf)));
}

fn starting_config_(buf: [*c]u8, len: [*c]u64) callconv(.c) bool {
    return starting_config(buf[0..len.*], len);
}

pub fn starting_config(config_buf: []u8, out_len: *u64) bool {
    const config_size = @sizeOf(Config);
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

    const config = Config{
        .renderer = Renderer.default,
        .model = model_config,
    };

    @memcpy(config_buf[0..config_size], @as(*const [config_size]u8, @ptrCast(&config)));
    return true;
}

fn starting_state_(config: [*c]const u8, config_len: u64, buf: [*c]u8, len: [*c]u64) callconv(.c) bool {
    return starting_state(
        from_buffer(Config, config[0..config_len]).*,
        buf[0..len.*],
        len,
    );
}

pub fn starting_state(config: Config, buf: []u8, out_len: *u64) bool {
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
            piece.* = piece.refresh(config.model.piece);
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
        from_buffer(State.StateInput, input[0..input_len]).*,
        from_buffer(Config, config[0..config_len]).*,
        from_buffer(State, state[0..state_len]).*,
        out_state[0..out_state_len.*],
        out_state_len,
    );
}

pub fn state_step(input: State.StateInput, config: Config, state: State, out_state_buf: []u8, out_state_len: *u64) bool {
    const out_state_size = @sizeOf(State);
    out_state_len.* = out_state_size;
    if (out_state_buf.len < out_state_size) {
        return false;
    }

    return if (state.step(input, config.model)) |new_state| blk: {
        @memcpy(out_state_buf[0..out_state_size], @as(*const [out_state_size]u8, @ptrCast(&new_state)));
        break :blk true;
    } else false;
}

fn state_draw_(ctx: ?*anyopaque, renderer: [*c]const sim_c.Renderer, config: [*c]const u8, config_len: u64, state: [*c]const u8, state_len: u64) callconv(.c) void {
    state_draw(
        ctx,
        renderer,
        from_buffer(Config, config[0..config_len]).*,
        from_buffer(State, state[0..state_len]).*,
    );
}

fn state_draw(ctx: ?*anyopaque, renderer: *const sim_c.Renderer, config: Config, state: State) void {
    var backend = RenderBackend{ .ctx = ctx, .vtable = renderer };
    config.renderer.draw(&backend, state, config.model);
}

comptime {
    const module = sim_c;
    const funcs = .{
        .{
            .func = &starting_config_,
            .name = "starting_config",
        },
        .{
            .func = &starting_state_,
            .name = "starting_state",
        },
        .{
            .func = &state_step_,
            .name = "state_step",
        },
        .{
            .func = &state_draw_,
            .name = "state_draw",
        },
    };
    for (funcs) |t| {
        const FnType = @TypeOf(@field(module, t.name));
        if (@TypeOf(t.func) != *const FnType) {
            @compileLog(t.func);
            @compileLog(FnType);
        }
        @export(t.func, .{ .name = t.name });
    }
}

pub const RenderBackend = struct {
    ctx: ?*anyopaque,
    vtable: *const sim_c.Renderer,
    curr_tag: ?u32 = null,
    offx: i32 = 0,
    offy: i32 = 0,

    pub const Color = sim_c.Color;

    // Colors from raylib.h
    pub const lightgray = Color{ .r = 200, .g = 200, .b = 200, .a = 255 };
    pub const gray = Color{ .r = 130, .g = 130, .b = 130, .a = 255 };
    pub const darkgray = Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
    pub const yellow = Color{ .r = 253, .g = 249, .b = 0, .a = 255 };
    pub const gold = Color{ .r = 255, .g = 203, .b = 0, .a = 255 };
    pub const orange = Color{ .r = 255, .g = 161, .b = 0, .a = 255 };
    pub const pink = Color{ .r = 255, .g = 109, .b = 194, .a = 255 };
    pub const red = Color{ .r = 230, .g = 41, .b = 55, .a = 255 };
    pub const maroon = Color{ .r = 190, .g = 33, .b = 55, .a = 255 };
    pub const green = Color{ .r = 0, .g = 228, .b = 48, .a = 255 };
    pub const lime = Color{ .r = 0, .g = 158, .b = 47, .a = 255 };
    pub const darkgreen = Color{ .r = 0, .g = 117, .b = 44, .a = 255 };
    pub const skyblue = Color{ .r = 102, .g = 191, .b = 255, .a = 255 };
    pub const blue = Color{ .r = 0, .g = 121, .b = 241, .a = 255 };
    pub const darkblue = Color{ .r = 0, .g = 82, .b = 172, .a = 255 };
    pub const purple = Color{ .r = 200, .g = 122, .b = 255, .a = 255 };
    pub const violet = Color{ .r = 135, .g = 60, .b = 190, .a = 255 };
    pub const darkpurple = Color{ .r = 112, .g = 31, .b = 126, .a = 255 };
    pub const beige = Color{ .r = 211, .g = 176, .b = 131, .a = 255 };
    pub const brown = Color{ .r = 127, .g = 106, .b = 79, .a = 255 };
    pub const darkbrown = Color{ .r = 76, .g = 63, .b = 47, .a = 255 };

    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const blank = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const magenta = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
    pub const raywhite = Color{ .r = 245, .g = 245, .b = 245, .a = 255 };

    pub const ScreenPos = struct {
        x: i32,
        y: i32,

        const origin = ScreenPos{ .x = 0, .y = 0 };

        fn add(a: ScreenPos, b: ScreenPos) ScreenPos {
            return .{ .x = a.x + b.x, .y = a.y + b.y };
        }
    };

    pub fn clear_background(backend: RenderBackend, color: Color) void {
        return backend.vtable.clear_background.?(backend.ctx, color);
    }

    pub fn begin_window_mode(backend: *RenderBackend, tag: u32, x: i32, y: i32, w: i32, h: i32) void {
        std.debug.assert(backend.curr_tag == null);
        backend.*.offx = x;
        backend.*.offy = y;
        backend.*.curr_tag = tag;
        backend.vtable.set_clip.?(backend.ctx, x, y, w, h);
    }

    pub fn end_window_mode(backend: *RenderBackend, tag: u32) void {
        std.debug.assert(backend.curr_tag == tag);
        backend.vtable.reset_clip.?(backend.ctx);
        backend.*.offx = 0;
        backend.*.offy = 0;
        backend.*.curr_tag = null;
    }

    pub fn draw_rect(backend: RenderBackend, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        return backend.vtable.draw_rect.?(backend.ctx, backend.offx + x, backend.offy + y, w, h, color);
    }

    pub fn draw_rect_outline(backend: RenderBackend, x: i32, y: i32, w: i32, h: i32, color: Color, outline_size: i32, outline_color: Color) void {
        const ox = x - outline_size;
        const oy = y - outline_size;
        const ow = w + 2 * outline_size;
        const oh = h + 2 * outline_size;
        backend.draw_rect(ox, oy, ow, oh, outline_color);
        backend.draw_rect(x, y, w, h, color);
    }

    pub fn draw_circ(backend: RenderBackend, x: i32, y: i32, r: f32, color: Color) void {
        return backend.vtable.draw_circ.?(backend.ctx, backend.offx + x, backend.offy + y, r, color);
    }

    pub fn draw_circ_outline(backend: RenderBackend, x: i32, y: i32, r: f32, color: Color, outline_size: i32, outline_color: Color) void {
        backend.draw_circ(x, y, r + @as(f32, @floatFromInt(outline_size)), outline_color);
        backend.draw_circ(x, y, r, color);
    }

    pub fn draw_line(backend: RenderBackend, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
        return backend.vtable.draw_line.?(backend.ctx, backend.offx + x0, backend.offy + y0, backend.offx + x1, backend.offy + y1, color);
    }
};
