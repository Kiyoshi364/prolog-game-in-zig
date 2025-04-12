const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const utils_mod = b.createModule(.{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sim_mod = b.createModule(.{
        .root_source_file = b.path("src/simulation/sim.zig"),
        .target = target,
        .optimize = optimize,
    });
    sim_mod.addImport("utils", utils_mod);

    const backend_mod = b.createModule(.{
        .root_source_file = b.path("src/raylib_backend.zig"),
        .target = target,
        .optimize = optimize,
    });
    backend_mod.addImport("utils", utils_mod);
    backend_mod.addImport("simulation", sim_mod);
    backend_mod.linkLibrary(raylib_dep.artifact("raylib"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("simulation", sim_mod);
    exe_mod.addImport("backend", backend_mod);

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
    exe.linkLibrary(raylib_dep.artifact("raylib"));

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
