const std = @import("std");

const simulation = @import("simulation");

const StateInput = simulation.State.StateInput;

const Direction = StateInput.Direction;
const ModifierFlags = StateInput.ModifierFlags;
const Button = StateInput.Button;

const raylib = @cImport({
    @cInclude("raylib.h");
});

const RaylibInputer = @This();

dirs: [Direction.count]Timer = .{.off} ** Direction.count,
button: [Button.count]Timer = .{.off} ** Button.count,

pub const Key = c_int;

pub const Config = struct {
    timer_cooldown: u7 = 25,
    dir_keymap: [Direction.count]Key = std.enums.directEnumArray(Direction, Key, 0, .{
        .up = raylib.KEY_W,
        .right = raylib.KEY_D,
        .down = raylib.KEY_S,
        .left = raylib.KEY_A,
    }),
    mod_keymap: [ModifierFlags.count]Key = std.enums.directEnumArray(ModifierFlags, Key, 0, .{
        .control = raylib.KEY_LEFT_ALT,
    }),
    button_keymap: [Button.count]Key = std.enums.directEnumArray(Button, Key, 0, .{
        .ok = raylib.KEY_J,
        .back = raylib.KEY_K,
    }),
};

pub fn get_input(
    inputer: RaylibInputer,
    config: Config,
    out_inputer: *RaylibInputer,
) StateInput {
    const dirs = blk: {
        var dirs = @as([Direction.count]bool, undefined);
        for (config.dir_keymap, inputer.dirs, &out_inputer.dirs, &dirs) |key, in_timer, *out_timer, *dir| {
            dir.* = in_timer.check_keydown(key, config, out_timer);
        }
        break :blk dirs;
    };

    const mods = blk: {
        var mods = @as([ModifierFlags.count]bool, undefined);
        for (config.mod_keymap, &mods) |key, *mod| {
            mod.* = raylib.IsKeyDown(key);
        }
        break :blk mods;
    };

    const button = blk: {
        var button = @as(?Button, null);
        for (config.button_keymap, inputer.button, &out_inputer.button, 0..) |key, in_timer, *out_timer, i| {
            if (button) |_| {
                out_timer.* = in_timer.tick();
            } else {
                const pressed = in_timer.check_keydown(key, config, &out_timer.*);
                button = if (pressed) @enumFromInt(i) else null;
            }
        }
        break :blk button;
    };

    return .{
        .dirs = dirs,
        .mods = mods,
        .button = button,
    };
}

const constants = struct {
    const TimerInt: type = u7;
    comptime {
        const int_info = @typeInfo(TimerInt).int;
        std.debug.assert(int_info.signedness == .unsigned);
    }
};

const TimerEnum = enum(u1) { off, cooldown };
const Timer = union(TimerEnum) {
    off: void,
    cooldown: constants.TimerInt,

    fn tick(t: Timer) Timer {
        return switch (t) {
            .off => .off,
            .cooldown => |timer| blk: {
                const ov = @subWithOverflow(timer, 1);
                break :blk if (ov[1] == 0)
                    .{ .cooldown = ov[0] }
                else
                    .off;
            },
        };
    }

    fn check_keydown(timer: Timer, key: Key, config: Config, out_timer: *Timer) bool {
        return if (raylib.IsKeyDown(key))
            switch (timer) {
                .off => blk: {
                    out_timer.* = .{ .cooldown = config.timer_cooldown };
                    break :blk true;
                },
                .cooldown => blk: {
                    out_timer.* = timer.tick();
                    break :blk false;
                },
            }
        else blk: {
            out_timer.* = .off;
            break :blk false;
        };
    }
};
