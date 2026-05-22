const std = @import("std");

pub const AnomalyDetector = struct {
    threshold: f32,

    pub fn init(threshold: f32) AnomalyDetector {
        return AnomalyDetector{ .threshold = threshold };
    }

    /// 计算当前样本与基准线的余弦相似度距离
    /// 距离越远，健康偏差越大
    pub fn calculateDeviation(_: *const AnomalyDetector, current: []const f32, baseline: []const f32) f32 {
        var dot_product: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (current, baseline) |c, b| {
            dot_product += c * b;
            norm_a += c * c;
            norm_b += b * b;
        }

        const similarity = dot_product / (@sqrt(norm_a) * @sqrt(norm_b) + 1e-9);
        return 1.0 - similarity; // 返回距离，0表示完全一致，1表示完全不同
    }

    pub fn isAnomaly(self: *const AnomalyDetector, distance: f32) bool {
        return distance > self.threshold;
    }
};
