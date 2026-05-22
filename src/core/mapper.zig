const Morphology = @import("../vision/morphology.zig").Analyzer;
const AudioDeep = @import("../audio/deep.zig").DeepAnalyzer;
const ContextBrain = @import("context.zig").ContextBrain;
const std = @import("std");

pub const Mapper = struct {
    pub const HealthMetrics = struct {
        skin_risk: f32,
        morphology_score: f32,
        vocal_health: f32,
        text_sentiment: f32,
        measurement_score: f32,
        medication_impact: f32,
        overall: f32,
    };

    /// 动态加权评估引擎
    pub fn evaluate(
        allocator: std.mem.Allocator,
        brain: *const ContextBrain,
        audio_features: AudioDeep.Features,
        image_path: []const u8,
    ) !HealthMetrics {
        // 1. 获取核心上下文
        const feedback_raw = try brain.query(.user_feedback);
        defer allocator.free(feedback_raw);

        // 2. 动态因子调整：基于反馈数据动态调整权重
        var weight_vocal: f32 = 0.3;
        var weight_measures: f32 = 0.3;
        if (std.mem.indexOf(u8, feedback_raw, "tired") != null) {
            weight_vocal -= 0.1;
            weight_measures += 0.1;
        }

        const vision = Morphology.calculate(image_path);
        const text_sentiment: f32 = 0.5;
        const measure_score: f32 = 0.9;
        const med_impact: f32 = 0.1;

        const shape_risk: f32 = if (vision.circularity < 0.7) 0.8 else if (vision.circularity < 0.85) 0.4 else 0.1;
        const skin_risk = shape_risk * 0.6;

        const vocal_health = (1.0 - audio_features.emotion_score) * 0.5;

        // 使用动态权重计算
        var overall = (1.0 - skin_risk) * 0.2 + vocal_health * weight_vocal + measure_score * weight_measures - (med_impact * 0.1);

        // 3. 主动探测逻辑：如果评估结果异常，触发二次查询
        if (overall < 0.5) {
            const env_risk = try brain.query(.environment_risk);
            defer allocator.free(env_risk);
            overall -= 0.1;
        }

        return .{
            .skin_risk = skin_risk,
            .morphology_score = vision.circularity,
            .vocal_health = vocal_health,
            .text_sentiment = text_sentiment,
            .measurement_score = measure_score,
            .medication_impact = med_impact,
            .overall = @max(0.0, overall),
        };
    }
};
