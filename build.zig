const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });
    const exe = b.addExecutable(.{ .name = "c_compiler", .root_module = exe_mod });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    setupTest(b, target, optimize);
}

fn setupTest(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    // region Test Step
    const test_step = b.step("test", "Run all test");
    const src_dir = b.pathFromRoot("src");
    var dir = std.fs.openDirAbsolute(src_dir, .{ .iterate = true }) catch unreachable;
    defer dir.close();

    var walker = dir.walk(b.allocator) catch unreachable;
    defer walker.deinit();

    while (walker.next() catch unreachable) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
            const t = b.addTest(.{
                .root_source_file = b.path(b.pathJoin(&.{ "src", entry.path })),
                .target = target,
                .optimize = optimize,
            });
            const rt = b.addRunArtifact(t);
            test_step.dependOn(&rt.step);
        }
    }
    // endregion
}
