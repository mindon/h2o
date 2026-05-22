const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "h2o",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // C++ 桥接：OpenCV 图像处理 (位于 vision/c_bridge/)
    exe.root_module.addCSourceFile(.{ .file = b.path("src/vision/c_bridge/opencv_bridge.cpp"), .flags = &.{ "-std=c++17", "-I/opt/homebrew/opt/opencv/include/opencv4" } });
    
    // CoreLocation 桥接
    exe.root_module.addCSourceFile(.{ .file = b.path("src/vision/c_bridge/location.m"), .flags = &.{"-fobjc-arc"} });
    exe.root_module.addIncludePath(b.path("src/vision/c_bridge"));
    exe.root_module.linkFramework("CoreLocation", .{});
    exe.root_module.linkFramework("Foundation", .{});

    exe.root_module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/opencv/lib" });
    exe.root_module.linkSystemLibrary("opencv4", .{});
    exe.root_module.link_libc = true;
    exe.root_module.link_libcpp = true;

    b.installArtifact(exe);
}
