const std = @import("std");

const simulation = @import("simulation");

pub const Inputer = @import("raylib_backend/Inputer.zig");
pub const Renderer = @import("raylib_backend/Renderer.zig");

const raylib = @cImport({
    @cInclude("raylib.h");
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
