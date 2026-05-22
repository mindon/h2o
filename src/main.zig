const std = @import("std");
const Io = std.Io;
const Memory = @import("core/memory.zig").Memory;
const ContextBrain = @import("core/context.zig").ContextBrain;
const AudioDeep = @import("audio/deep.zig").DeepAnalyzer;
const Collector = @import("io/collector.zig").Collector;
const Workflow = @import("core/workflow.zig").Workflow;
const EnvCollector = @import("core/env_context.zig").EnvironmentCollector;

fn isWeatherMode(init: std.process.Init) bool {
    if (init.environ_map.get("H2O_MODE")) |mode| {
        if (std.mem.eql(u8, mode, "weather")) return true;
    }

    var args_it = std.process.Args.Iterator.init(init.minimal.args);
    _ = args_it.next();
    if (args_it.next()) |arg| {
        return std.mem.eql(u8, arg, "weather");
    }

    return false;
}

fn runWeatherMode() !void {
    const env = try EnvCollector.fetchCurrent();
    std.debug.print(
        "当前位置: ({d:.4}, {d:.4})\n天气: {s}\n气温: {d:.1}°C\n湿度: {d:.1}%\n气压: {d:.1} hPa\n风速: {d:.1} km/h\n",
        .{ env.latitude, env.longitude, env.weather, env.temperature, env.humidity, env.pressure, env.wind_speed },
    );
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    if (isWeatherMode(init)) {
        try runWeatherMode();
        return;
    }

    std.debug.print("\n═══════════════════════════════════════\n", .{});
    std.debug.print("  H2O — Home Health Observer v0.5\n", .{});
    std.debug.print("═══════════════════════════════════════\n\n", .{});

    // ── 初始化服务栈 ──────────────────
    var col = Collector.init(allocator, io);
    defer col.deinit();

    var brain = ContextBrain.init(allocator);
    defer brain.deinit();

    var memory = Memory.init(allocator, io);
    const sound = AudioDeep.init();

    const user_id = "h01";

    // ── 阶段 1: 环境上下文采集 ─────────
    std.debug.print("[1] 采集环境上下文...\n", .{});
    const env = EnvCollector.fetchCurrent() catch |err| {
        std.debug.print("    ⚠ 环境采集失败: {}\n", .{err});
        return;
    };
    std.debug.print(
        "    温度: {d:.1}°C | 湿度: {d:.1}% | 气压: {d:.1} hPa | 风速: {d:.1} km/h | 天气: {s}\n",
        .{ env.temperature, env.humidity, env.pressure, env.wind_speed, env.weather },
    );

    // 注入环境数据到 ContextBrain
    const env_json = try std.fmt.allocPrint(
        allocator,
        "{{\"temp\":{d:.1},\"hum\":{d:.1},\"pressure\":{d:.1},\"wind_speed\":{d:.1},\"weather\":\"{s}\"}}",
        .{ env.temperature, env.humidity, env.pressure, env.wind_speed, env.weather },
    );
    defer allocator.free(env_json);
    try brain.put("environment_risk", env_json);

    // ── 阶段 2: 音频特征提取 ──────────
    std.debug.print("[2] 提取音频特征...\n", .{});
    const audio_data = col.fetch("latest_audio_snapshot") catch &[_]u8{};
    const audio_features = sound.analyze(audio_data);
    std.debug.print("    音高: {d:.1}Hz | 强度: {d:.1}dB | 语速: {d:.1} | 情绪: {d:.2}\n", .{ audio_features.pitch, audio_features.intensity, audio_features.speech_rate, audio_features.emotion_score });

    // ── 阶段 3: Workflow 驱动评估循环 ──
    std.debug.print("[3] 启动评估工作流...\n", .{});
    var workflow = Workflow.init(allocator, &brain);
    const metrics = try workflow.run(audio_features, "daily_check.jpg");

    // ── 阶段 4: 结果汇总 ─────────────
    std.debug.print("\n[4] 评估结果汇总:\n", .{});
    std.debug.print("    ┌─────────────────────────────┐\n", .{});
    std.debug.print("    │ 综合健康评分  {d:.3}          │\n", .{metrics.overall});
    std.debug.print("    │ 皮肤风险      {d:.3}          │\n", .{metrics.skin_risk});
    std.debug.print("    │ 语音健康      {d:.3}          │\n", .{metrics.vocal_health});
    std.debug.print("    │ 文本情绪      {d:.3}          │\n", .{metrics.text_sentiment});
    std.debug.print("    │ 测量数据      {d:.3}          │\n", .{metrics.measurement_score});
    std.debug.print("    │ 用药影响      {d:.3}          │\n", .{metrics.medication_impact});
    std.debug.print("    └─────────────────────────────┘\n", .{});

    // ── 阶段 5: 存档 ────────────────
    std.debug.print("[5] 存档...\n", .{});
    const record = try std.fmt.allocPrint(allocator, "{{\"overall\":{d:.3},\"skin_risk\":{d:.3},\"vocal\":{d:.3},\"text_sentiment\":{d:.3},\"measure\":{d:.3},\"med_impact\":{d:.3}}}", .{ metrics.overall, metrics.skin_risk, metrics.vocal_health, metrics.text_sentiment, metrics.measurement_score, metrics.medication_impact });
    defer allocator.free(record);
    try memory.saveRecord(user_id, record);

    std.debug.print("\n✓ 分析完成\n", .{});
}
