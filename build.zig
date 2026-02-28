const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Windows: pass -Dsdl2=C:/path/to/SDL2 at build time.
    switch (b.graph.host.result.os.tag) {
        .macos => {
            const prefix = if (b.graph.host.result.cpu.arch == .aarch64) "/opt/homebrew" else "/usr/local";
            mod.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix, "include" }) });
            mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix, "lib" }) });
        },
        .linux => {
            mod.addIncludePath(.{ .cwd_relative = "/usr/include" });
            mod.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
        },
        .windows => {
            const sdl2 = b.option([]const u8, "sdl2", "SDL2 root (e.g. C:/SDL2)") orelse "C:/SDL2";
            mod.addIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdl2, "include" }) });
            mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdl2, "lib" }) });
        },
        else => {},
    }

    mod.linkSystemLibrary("SDL2", .{});

    const exe = b.addExecutable(.{ .name = "raycazig", .root_module = mod });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run raycazig").dependOn(&run.step);
}
