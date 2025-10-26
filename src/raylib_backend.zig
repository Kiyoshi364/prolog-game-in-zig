const std = @import("std");

const simulation = @import("simulation");

pub const Inputer = @import("raylib_backend/Inputer.zig");

const raylib = @cImport({
    @cInclude("raylib.h");
});
const sim_c = @cImport({
    @cInclude("renderer.h");
});

pub const Window = struct {
    width: c_int,
    height: c_int,
    title: [*c]const u8,

    pub fn open(w: Window) void {
        raylib.InitWindow(w.width, w.height, w.title);
        raylib.SetTargetFPS(60);
    }

    pub fn close(w: Window) void {
        _ = w;
        raylib.CloseWindow();
    }

    pub fn should_close(w: Window) bool {
        _ = w;
        return raylib.WindowShouldClose();
    }
};

pub fn to_raylib_color(c: sim_c.Color) raylib.Color {
    return .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a };
}

pub const Renderer = struct {
    pub const vtable = sim_c.Renderer{
        .clear_background = clear_background,
        .set_clip = set_clip,
        .reset_clip = reset_clip,
        .draw_rect = draw_rect,
        .draw_circ = draw_circ,
        .draw_line = draw_line,
    };

    pub fn begin_draw() void {
        raylib.BeginDrawing();
    }

    pub fn end_draw() void {
        raylib.DrawFPS(0, raylib.GetScreenHeight() - 16);
        raylib.EndDrawing();
    }

    fn clear_background(ctx: ?*anyopaque, color: sim_c.Color) callconv(.c) void {
        _ = ctx;
        raylib.ClearBackground(to_raylib_color(color));
    }

    fn set_clip(ctx: ?*anyopaque, x: i32, y: i32, w: i32, h: i32) callconv(.c) void {
        _ = ctx;
        raylib.BeginScissorMode(x, y, w, h);
    }

    fn reset_clip(ctx: ?*anyopaque) callconv(.c) void {
        _ = ctx;
        raylib.EndScissorMode();
    }

    fn draw_rect(ctx: ?*anyopaque, x: i32, y: i32, w: i32, h: i32, color: sim_c.Color) callconv(.c) void {
        _ = ctx;
        raylib.DrawRectangle(x, y, w, h, to_raylib_color(color));
    }

    fn draw_circ(ctx: ?*anyopaque, x: i32, y: i32, r: f32, color: sim_c.Color) callconv(.c) void {
        _ = ctx;
        raylib.DrawCircle(x, y, r, to_raylib_color(color));
    }

    fn draw_line(ctx: ?*anyopaque, x0: i32, y0: i32, x1: i32, y1: i32, color: sim_c.Color) callconv(.c) void {
        _ = ctx;
        raylib.DrawLine(x0, y0, x1, y1, to_raylib_color(color));
    }
};
