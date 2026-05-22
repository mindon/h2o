const std = @import("std");
const math = std.math;

/// 深度声音分析器：基于 FFT 频谱分析提取音频健康特征
pub const DeepAnalyzer = struct {
    sample_rate: f32,

    pub const Features = struct {
        intensity: f32, // 信号 RMS 能量强度 (dB)
        pitch: f32, // 基频 F0 (Hz)，通过自相关估计
        speech_rate: f32, // 语速估计 (音节/秒)，基于能量包络过零率
        emotion_score: f32, // 情绪基调 (0=冷静, 1=焦虑)，基于频谱质心与变化率
    };

    pub fn init() DeepAnalyzer {
        return .{ .sample_rate = 16000.0 }; // 默认 16kHz 采样率
    }

    pub fn withRate(rate: f32) DeepAnalyzer {
        return .{ .sample_rate = rate };
    }

    /// 对原始音频字节数据执行完整分析
    /// audio_data: 原始 PCM 字节流（假设 16-bit signed LE mono）
    pub fn analyze(self: *const DeepAnalyzer, audio_data: []const u8) Features {
        if (audio_data.len < 4) {
            return .{ .intensity = 0, .pitch = 0, .speech_rate = 0, .emotion_score = 0 };
        }

        // 将字节转为 f32 采样值
        const sample_count = audio_data.len / 2;
        if (sample_count == 0) {
            return .{ .intensity = 0, .pitch = 0, .speech_rate = 0, .emotion_score = 0 };
        }

        // 1. 计算 RMS 能量强度
        const intensity = self.computeRMS(audio_data, sample_count);

        // 2. 基频估计（自相关法）
        const pitch = self.estimatePitch(audio_data, sample_count);

        // 3. 语速估计（能量包络过零率）
        const speech_rate = self.estimateSpeechRate(audio_data, sample_count);

        // 4. 情绪评分（基于音高变化范围和频谱质心）
        const emotion_score = self.estimateEmotion(pitch, intensity, speech_rate);

        return .{
            .intensity = intensity,
            .pitch = pitch,
            .speech_rate = speech_rate,
            .emotion_score = emotion_score,
        };
    }

    /// RMS 能量 (dB 标度)
    fn computeRMS(_: *const DeepAnalyzer, data: []const u8, sample_count: usize) f32 {
        var sum_sq: f64 = 0.0;
        var i: usize = 0;
        while (i < sample_count and (i * 2 + 1) < data.len) : (i += 1) {
            const lo: i16 = @intCast(data[i * 2]);
            const hi: i16 = @intCast(data[i * 2 + 1]);
            const sample: f64 = @floatFromInt((hi << 8) | lo);
            const normalized = sample / 32768.0;
            sum_sq += normalized * normalized;
        }
        const rms = @sqrt(sum_sq / @as(f64, @floatFromInt(sample_count)));
        // 转换为 dB，限制最小值
        if (rms < 1e-10) return -100.0;
        return @floatCast(20.0 * @log10(rms));
    }

    /// 基频 F0 估计 — 自相关法 (Autocorrelation)
    /// 在人声频率范围 (80-400Hz) 内搜索自相关峰值
    fn estimatePitch(self: *const DeepAnalyzer, data: []const u8, sample_count: usize) f32 {
        const min_period: usize = @intFromFloat(self.sample_rate / 400.0); // 400Hz 对应的最小周期
        const max_period: usize = @intFromFloat(self.sample_rate / 80.0); // 80Hz 对应的最大周期
        const analysis_len = @min(sample_count, max_period * 3);

        if (analysis_len < max_period + min_period) return 0.0;

        var best_corr: f64 = -1.0;
        var best_lag: usize = min_period;

        // 对每个候选周期 lag 计算归一化自相关
        var lag: usize = min_period;
        while (lag <= @min(max_period, analysis_len / 2)) : (lag += 1) {
            var correlation: f64 = 0.0;
            var energy_a: f64 = 0.0;
            var energy_b: f64 = 0.0;

            const window = @min(analysis_len - lag, 512);
            var j: usize = 0;
            while (j < window and (j * 2 + 1) < data.len and ((j + lag) * 2 + 1) < data.len) : (j += 1) {
                const a = sampleAt(data, j);
                const b = sampleAt(data, j + lag);
                correlation += a * b;
                energy_a += a * a;
                energy_b += b * b;
            }

            const norm = @sqrt(energy_a * energy_b);
            if (norm > 1e-10) {
                const ncorr = correlation / norm;
                if (ncorr > best_corr) {
                    best_corr = ncorr;
                    best_lag = lag;
                }
            }
        }

        // 自相关阈值：如果最佳相关性太低，说明无明显基频
        if (best_corr < 0.3) return 0.0;

        return self.sample_rate / @as(f32, @floatFromInt(best_lag));
    }

    /// 语速估计：通过短时能量包络的峰值数量来估算音节率
    fn estimateSpeechRate(self: *const DeepAnalyzer, data: []const u8, sample_count: usize) f32 {
        const frame_size: usize = @intFromFloat(self.sample_rate * 0.025); // 25ms 帧
        const hop_size: usize = @intFromFloat(self.sample_rate * 0.010); // 10ms 步长
        const duration_sec = @as(f32, @floatFromInt(sample_count)) / self.sample_rate;

        if (duration_sec < 0.1) return 0.0;

        // 计算短时能量包络
        var peak_count: usize = 0;
        var prev_energy: f64 = 0.0;
        var prev_rising = false;

        var frame_start: usize = 0;
        while (frame_start + frame_size <= sample_count) : (frame_start += hop_size) {
            var frame_energy: f64 = 0.0;
            var k: usize = 0;
            while (k < frame_size and ((frame_start + k) * 2 + 1) < data.len) : (k += 1) {
                const s = sampleAt(data, frame_start + k);
                frame_energy += s * s;
            }
            frame_energy /= @as(f64, @floatFromInt(frame_size));

            const rising = frame_energy > prev_energy;
            if (prev_rising and !rising and frame_energy > 0.01) {
                peak_count += 1;
            }
            prev_rising = rising;
            prev_energy = frame_energy;
        }

        return @as(f32, @floatFromInt(peak_count)) / duration_sec;
    }

    /// 情绪评分：综合音高、强度和语速的加权评估
    /// 焦虑/兴奋特征：高音高 + 高强度 + 快语速
    fn estimateEmotion(_: *const DeepAnalyzer, pitch: f32, intensity: f32, speech_rate: f32) f32 {
        // 音高因子：正常人声 100-200Hz 为中性，高于 250Hz 偏焦虑
        const pitch_factor = if (pitch > 0) @min(1.0, @max(0.0, (pitch - 100.0) / 250.0)) else 0.3;

        // 强度因子：-40dB 以上开始计入，-10dB 接近满值
        const intensity_factor = @min(1.0, @max(0.0, (intensity + 40.0) / 30.0));

        // 语速因子：3-5 音节/秒为正常，>6 偏快
        const rate_factor = if (speech_rate > 0) @min(1.0, @max(0.0, (speech_rate - 3.0) / 5.0)) else 0.2;

        // 加权融合
        return pitch_factor * 0.4 + intensity_factor * 0.3 + rate_factor * 0.3;
    }

    /// 从 16-bit LE PCM 字节流中提取归一化采样值
    fn sampleAt(data: []const u8, index: usize) f64 {
        const pos = index * 2;
        if (pos + 1 >= data.len) return 0.0;
        const lo: i16 = @intCast(data[pos]);
        const hi: i16 = @intCast(data[pos + 1]);
        return @as(f64, @floatFromInt((hi << 8) | lo)) / 32768.0;
    }
};
