const std = @import("std");
const HealthAgent = @import("agents.zig").HealthAgent;
const EnvironmentAgent = @import("agents.zig").EnvironmentAgent;
const ContextBrain = @import("context.zig").ContextBrain;
const Mapper = @import("mapper.zig").Mapper;
const Guider = @import("guider.zig").ProbingGuider;
const AudioDeep = @import("../audio/deep.zig").DeepAnalyzer;

pub const State = enum {
    evaluate,
    guidance,
    await_collection,
    completed,
};

pub const Workflow = struct {
    allocator: std.mem.Allocator,
    brain: *ContextBrain,
    health_agent: HealthAgent,
    current_state: State = .evaluate,
    latest_metrics: ?Mapper.HealthMetrics = null,
    max_rounds: u8 = 3,
    round: u8 = 0,

    pub fn init(allocator: std.mem.Allocator, brain: *ContextBrain) Workflow {
        return .{
            .allocator = allocator,
            .brain = brain,
            .health_agent = HealthAgent{ .allocator = allocator },
        };
    }

    /// 执行完整的评估工作流
    pub fn run(self: *Workflow, audio_features: AudioDeep.Features, image_path: []const u8) !Mapper.HealthMetrics {
        while (self.current_state != .completed) {
            switch (self.current_state) {
                .evaluate => {
                    self.round += 1;
                    std.debug.print("  [轮次 {d}] 执行多模态融合评估...\n", .{self.round});

                    // 核心评估
                    const metrics = try Mapper.evaluate(self.allocator, self.brain, audio_features, image_path);
                    self.latest_metrics = metrics;

                    std.debug.print("    综合评分: {d:.3}\n", .{metrics.overall});

                    // 环境协作分析
                    const env_index = EnvironmentAgent.analyze(self.brain) catch 0.5;
                    std.debug.print("    环境健康指数: {d:.2}\n", .{env_index});

                    // 检查是否需要更多数据
                    if (metrics.overall < 0.5 and self.round < self.max_rounds) {
                        if (self.health_agent.evaluate(self.brain)) |maybe_instr| {
                            if (maybe_instr) |instr| {
                                std.debug.print("    ⚠ 证据不足，触发引导: {s}\n", .{instr.action});
                                std.debug.print("      原因: {s} (建议 {d}秒)\n", .{ instr.reason, instr.duration_sec });
                                self.current_state = .guidance;
                                continue;
                            }
                        } else |_| {}
                    }

                    self.current_state = .completed;
                },
                .guidance => {
                    std.debug.print("  [引导] 等待用户按指引采集数据...\n", .{});
                    self.current_state = .await_collection;
                },
                .await_collection => {
                    // 模拟：用户已完成数据采集，回到评估
                    std.debug.print("  [采集] 新数据已到达，重新评估...\n", .{});
                    self.current_state = .evaluate;
                },
                .completed => break,
            }
        }

        return self.latest_metrics orelse Mapper.HealthMetrics{
            .skin_risk = 0,
            .morphology_score = 0,
            .vocal_health = 0,
            .text_sentiment = 0,
            .measurement_score = 0,
            .medication_impact = 0,
            .overall = 0,
        };
    }
};
