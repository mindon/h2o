const std = @import("std");

/// 皮肤色彩分析器：从 RGB 图像数据中提取 HSV 空间的肤色特征
pub const SkinTone = struct {
    pub const Result = struct {
        index: f32, // 综合肤色指数 (0.0 - 1.0)
        hue_mean: f32, // 色调均值 (0-360)
        saturation: f32, // 饱和度均值 (0.0 - 1.0)
        brightness: f32, // 明度均值 (0.0 - 1.0)
    };

    pub fn init() SkinTone {
        return SkinTone{};
    }

    /// 分析 RGB 图像数据（每 3 字节为一个像素: R, G, B）
    /// 返回皮肤区域的色彩特征
    pub fn analyzeRGB(self: *const SkinTone, image_data: []const u8) Result {
        _ = self;
        const pixel_count = image_data.len / 3;
        if (pixel_count == 0) return .{ .index = 0, .hue_mean = 0, .saturation = 0, .brightness = 0 };

        var hue_sum: f64 = 0.0;
        var sat_sum: f64 = 0.0;
        var val_sum: f64 = 0.0;
        var skin_pixels: usize = 0;

        var i: usize = 0;
        while (i < pixel_count) : (i += 1) {
            const r = @as(f64, @floatFromInt(image_data[i * 3])) / 255.0;
            const g = @as(f64, @floatFromInt(image_data[i * 3 + 1])) / 255.0;
            const b = @as(f64, @floatFromInt(image_data[i * 3 + 2])) / 255.0;

            // RGB -> HSV 转换
            const hsv = rgbToHsv(r, g, b);

            // 肤色检测：HSV 空间中的肤色范围
            // H: 0-50°, S: 0.15-0.75, V: 0.2-0.95
            if (hsv[0] <= 50.0 and hsv[1] >= 0.15 and hsv[1] <= 0.75 and hsv[2] >= 0.2) {
                hue_sum += hsv[0];
                sat_sum += hsv[1];
                val_sum += hsv[2];
                skin_pixels += 1;
            }
        }

        if (skin_pixels == 0) {
            return .{ .index = 0, .hue_mean = 0, .saturation = 0, .brightness = 0 };
        }

        const count_f = @as(f64, @floatFromInt(skin_pixels));
        const hue_mean: f32 = @floatCast(hue_sum / count_f);
        const saturation: f32 = @floatCast(sat_sum / count_f);
        const brightness: f32 = @floatCast(val_sum / count_f);

        // 综合肤色指数：基于色调偏移 + 饱和度 + 亮度的加权组合
        // 色调越接近 20°（健康肤色中心值），指数越高
        const hue_score: f32 = 1.0 - @min(1.0, @abs(hue_mean - 20.0) / 30.0);
        const index = hue_score * 0.4 + saturation * 0.3 + brightness * 0.3;

        return .{
            .index = index,
            .hue_mean = hue_mean,
            .saturation = saturation,
            .brightness = brightness,
        };
    }

    /// 快速字节流分析（兼容旧接口，将字节流视为灰度数据）
    pub fn calculateIndex(self: *const SkinTone, image_data: []const u8) f32 {
        _ = self;
        if (image_data.len == 0) return 0.0;

        // 对灰度数据计算平均亮度归一化
        var sum: u64 = 0;
        for (image_data) |byte| {
            sum += byte;
        }
        return @as(f32, @floatFromInt(sum / image_data.len)) / 255.0;
    }
};

/// RGB -> HSV 转换，返回 [H(0-360), S(0-1), V(0-1)]
fn rgbToHsv(r: f64, g: f64, b: f64) [3]f64 {
    const max_val = @max(r, @max(g, b));
    const min_val = @min(r, @min(g, b));
    const delta = max_val - min_val;

    var h: f64 = 0.0;
    const s: f64 = if (max_val > 0) delta / max_val else 0.0;
    const v: f64 = max_val;

    if (delta > 1e-6) {
        if (max_val == r) {
            h = 60.0 * @mod((g - b) / delta, 6.0);
        } else if (max_val == g) {
            h = 60.0 * ((b - r) / delta + 2.0);
        } else {
            h = 60.0 * ((r - g) / delta + 4.0);
        }
        if (h < 0) h += 360.0;
    }

    return .{ h, s, v };
}
