const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    const sim_mod = b.addModule("simulation", .{
        .root_source_file = b.path("src/simulation/sim.zig"),
        .imports = &.{
            .{ .name = "utils", .module = utils_mod },
        },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    const backend_mod = b.createModule(.{
        .root_source_file = b.path("src/raylib_backend.zig"),
        .imports = &.{
            .{ .name = "utils", .module = utils_mod },
            .{ .name = "simulation", .module = sim_mod },
        },
        .target = target,
        .optimize = optimize,
    });
    backend_mod.linkLibrary(raylib_dep.artifact("raylib"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "simulation", .module = sim_mod },
            .{ .name = "backend", .module = backend_mod },
        },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "simulation",
        .root_module = sim_mod,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig_game",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const utils_unit_tests = b.addTest(.{
        .root_module = utils_mod,
    });

    const run_utils_unit_tests = b.addRunArtifact(utils_unit_tests);

    const sim_unit_tests = b.addTest(.{
        .root_module = sim_mod,
    });

    const run_sim_unit_tests = b.addRunArtifact(sim_unit_tests);

    // const exe_unit_tests = b.addTest(.{
    //     .root_module = exe_mod,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_utils_unit_tests.step);
    test_step.dependOn(&run_sim_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}
