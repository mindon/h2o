const std = @import("std");

/// 基础声音分析器：轻量级音频特征提取
/// 提供快速的时域特征计算（不涉及 FFT）
pub const Analyzer = struct {
    sample_rate: f32,

    pub fn init() Analyzer {
        return .{ .sample_rate = 16000.0 };
    }

    /// 从 16-bit LE PCM 音频中提取音高基准 (基于过零率估计)
    pub fn pitchBaseline(self: *const Analyzer, audio_data: []const u8) f32 {
        const sample_count = audio_data.len / 2;
        if (sample_count < 2) return 0.0;

        // 过零率法估计基频（适用于周期信号）
        var zero_crossings: usize = 0;
        var prev_positive = samplePositive(audio_data, 0);

        var i: usize = 1;
        while (i < sample_count and (i * 2 + 1) < audio_data.len) : (i += 1) {
            const current_positive = samplePositive(audio_data, i);
            if (current_positive != prev_positive) {
                zero_crossings += 1;
            }
            prev_positive = current_positive;
        }

        // 基频 ≈ 过零率 / 2（每个周期有两次过零）
        const duration = @as(f32, @floatFromInt(sample_count)) / self.sample_rate;
        if (duration <= 0) return 0.0;

        return @as(f32, @floatFromInt(zero_crossings)) / (2.0 * duration);
    }

    /// 计算音频信号的短时能量 (归一化 0.0 - 1.0)
    pub fn energy(audio_data: []const u8) f32 {
        const sample_count = audio_data.len / 2;
        if (sample_count == 0) return 0.0;

        var sum_sq: f64 = 0.0;
        var i: usize = 0;
        while (i < sample_count and (i * 2 + 1) < audio_data.len) : (i += 1) {
            const lo: i16 = @intCast(audio_data[i * 2]);
            const hi: i16 = @intCast(audio_data[i * 2 + 1]);
            const sample: f64 = @as(f64, @floatFromInt((hi << 8) | lo)) / 32768.0;
            sum_sq += sample * sample;
        }

        return @floatCast(@sqrt(sum_sq / @as(f64, @floatFromInt(sample_count))));
    }

    fn samplePositive(data: []const u8, index: usize) bool {
        const pos = index * 2;
        if (pos + 1 >= data.len) return false;
        const lo: i16 = @intCast(data[pos]);
        const hi: i16 = @intCast(data[pos + 1]);
        return ((hi << 8) | lo) >= 0;
    }
};
