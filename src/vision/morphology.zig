const std = @import("std");

pub const SpotData = extern struct {
    area: f32,
    perimeter: f32,
    width: f32,
    height: f32,
};

pub extern fn analyze_image_opencv(image_path: [*:0]const u8) SpotData;

/// 封装 OpenCV 的斑点形态学分析器
pub const Analyzer = struct {
    pub const Features = struct {
        circularity: f32,
        aspect_ratio: f32,
    };

    /// 计算图像中斑点的形态特征指数
    pub fn calculate(image_path: []const u8) Features {
        const allocator = std.heap.page_allocator;
        const path_buf = std.fmt.allocPrint(allocator, "{s}\x00", .{image_path}) catch unreachable;
        defer allocator.free(path_buf);

        const data = analyze_image_opencv(@ptrCast(path_buf.ptr));

        const pi = 3.1415926535;
        const circularity = if (data.perimeter > 0) (4.0 * pi * data.area) / (data.perimeter * data.perimeter) else 0.0;
        const aspect_ratio = if (data.height > 0) data.width / data.height else 1.0;

        return .{ .circularity = circularity, .aspect_ratio = aspect_ratio };
    }
};
