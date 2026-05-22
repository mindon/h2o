/// 采集引导器：根据评估缺失的数据类型，生成用户操作指引
/// 当 Agent 判断证据不足时，通过 reason_code 获取对应的指导操作
pub const ProbingGuider = struct {
    pub const Instruction = struct {
        action: []const u8,
        reason: []const u8,
        duration_sec: u16, // 建议操作时长 (秒)
    };

    pub fn getGuidance(reason_code: u8) Instruction {
        return switch (reason_code) {
            1 => .{
                .action = "请大声朗读以下绕口令：「四是四，十是十，十四是十四，四十是四十」",
                .reason = "音频特征不足，需要分析语音速率与清晰度",
                .duration_sec = 15,
            },
            2 => .{
                .action = "请进行 30 秒的深呼吸，吸气4秒-屏气4秒-呼气4秒",
                .reason = "生理指标波动剧烈，需要采集安静状态下的基准心率",
                .duration_sec = 30,
            },
            3 => .{
                .action = "请将手指放在手机闪光灯上，保持 10 秒",
                .reason = "需要通过 PPG 信号估算心率和血氧",
                .duration_sec = 10,
            },
            else => .{
                .action = "请面对摄像头，做出自然微笑，然后睁大眼睛",
                .reason = "面部视觉特征检测模糊，需要清晰的面部表情数据",
                .duration_sec = 5,
            },
        };
    }
};
