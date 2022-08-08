const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    var sysLibs = [_][]const u8{
        "c",
        "vulkan",
    };

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("window", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    for (sysLibs) |lib| {
        exe.linkSystemLibrary(lib);
    }

    exe.install();

    const run = b.step("run", "Run the app");
    const run_cmd = exe.run();
    run.dependOn(&run_cmd.step);
}
