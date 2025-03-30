const std = @import("std");

const simulation = @import("simulation");

const State = simulation.State;

const raylib = @cImport({
    @cInclude("raylib.h");
});

const RaylibRenderer = @This();

pub fn draw(renderer: RaylibRenderer, state: State) void {
    _ = renderer;
    _ = state;
    // TODO
}
