const std = @import("std");
const ContextBrain = @import("context.zig").ContextBrain;
const Guider = @import("guider.zig").ProbingGuider;

/// 健康评估 Agent
/// 负责判断当前数据是否充足，不足时触发 ProbingGuider 引导采集
pub const HealthAgent = struct {
    allocator: std.mem.Allocator,

    pub fn evaluate(self: *HealthAgent, brain: *const ContextBrain) !?Guider.Instruction {
        const feedback = brain.query(.user_feedback) catch {
            // 无法获取反馈，触发语音采集引导
            return Guider.getGuidance(1);
        };
        defer self.allocator.free(feedback);

        // 反馈内容太短，证据不足
        if (feedback.len < 10) {
            return Guider.getGuidance(1);
        }

        // 检查是否包含异常关键词
        if (std.mem.indexOf(u8, feedback, "dizzy") != null or
            std.mem.indexOf(u8, feedback, "pain") != null)
        {
            return Guider.getGuidance(2);
        }

        return null; // 数据充足，无需引导
    }
};

/// 环境分析 Agent
/// 通过 ContextBrain 查询环境数据，返回环境健康指数 (0.0 - 1.0)
pub const EnvironmentAgent = struct {
    pub fn analyze(brain: *const ContextBrain) !f32 {
        const env_data = brain.query(.environment_risk) catch {
            return 0.5; // 默认中等风险
        };
        defer std.heap.page_allocator.free(env_data);

        // 解析温度信息进行风险评估
        // 环境 JSON 格式: {"temp":22.5,"hum":45.0,"weather":"晴"}
        if (std.mem.indexOf(u8, env_data, "temp")) |_| {
            // 有环境数据，返回较好的指数
            return 0.7;
        }

        return 0.5;
    }
};
