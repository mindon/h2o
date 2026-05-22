const std = @import("std");
const Io = std.Io;
const Dir = Io.Dir;
const EnvContext = @import("../core/env_context.zig").EnvContext;
const EnvironmentCollector = @import("../core/env_context.zig").EnvironmentCollector;

fn buildRecordEntry(allocator: std.mem.Allocator, data: []const u8, env: EnvContext) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{{\"ts\":{d},\"data\":\"{s}\",\"env\":{{\"temp\":{d:.1},\"hum\":{d:.1},\"pressure\":{d:.1},\"wind_speed\":{d:.1},\"weather\":\"{s}\",\"lat\":{d:.6},\"lon\":{d:.6}}}}}\n",
        .{ env.timestamp, data, env.temperature, env.humidity, env.pressure, env.wind_speed, env.weather, env.latitude, env.longitude },
    );
}

pub const Collector = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]const u8),
    data_dir: []const u8,
    io: Io,

    pub fn init(allocator: std.mem.Allocator, io: Io) Collector {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap([]const u8).init(allocator),
            .data_dir = "data",
            .io = io,
        };
    }

    pub fn withDir(allocator: std.mem.Allocator, io: Io, data_dir: []const u8) Collector {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap([]const u8).init(allocator),
            .data_dir = data_dir,
            .io = io,
        };
    }

    pub fn deinit(self: *Collector) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// 带环境上下文的日志追加
    pub fn logRecord(self: *Collector, user_id: []const u8, data: []const u8) !void {
        const env = try EnvironmentCollector.fetchCurrent();
        const entry = try buildRecordEntry(self.allocator, data, env);
        defer self.allocator.free(entry);

        const io = self.io;
        const cwd = Dir.cwd();

        // 确保 data_dir/user_id 目录存在并打开
        var user_dir = try Dir.createDirPathOpen(cwd, io, self.data_dir, .{});
        defer user_dir.close(io);

        var sub_dir = try Dir.createDirPathOpen(user_dir, io, user_id, .{});
        defer sub_dir.close(io);

        // 以追加模式打开
        var file = try Dir.createFile(sub_dir, io, "records.jsonl", .{ .truncate = false });
        defer file.close(io);

        try file.writeStreamingAll(io, entry);

        // 触发评估
        try self.runAssessment(user_id, data, env);
    }

    fn runAssessment(self: *Collector, user_id: []const u8, data: []const u8, env: EnvContext) !void {
        const Assessment = @import("../llm/assessment.zig");
        const Ollama = @import("../llm/ollama.zig");

        const req = Assessment.AssessmentRequest{
            .data = data,
            .env = .{ .temp = env.temperature, .hum = env.humidity, .weather = env.weather, .timestamp = env.timestamp, .lat = env.latitude, .lon = env.longitude },
        };
        const prompt = try Assessment.generateAssessmentPrompt(self.allocator, req);
        defer self.allocator.free(prompt);

        var client = Ollama.Client.init(self.allocator);
        const response = try client.generate("llama3", prompt);
        defer self.allocator.free(response);
        const assessment = try client.extractResponse(response);
        defer self.allocator.free(assessment);

        // 保存评估结果
        const entry = try std.fmt.allocPrint(self.allocator, "{{\"ts\":{d},\"assessment\":{s}}}\n", .{ env.timestamp, assessment });
        defer self.allocator.free(entry);

        const io = self.io;
        const cwd = Dir.cwd();
        var user_dir = try Dir.createDirPathOpen(cwd, io, self.data_dir, .{});
        defer user_dir.close(io);
        var sub_dir = try Dir.createDirPathOpen(user_dir, io, user_id, .{});
        defer sub_dir.close(io);
        var file = try Dir.createFile(sub_dir, io, "assessment.jsonl", .{ .truncate = false });
        defer file.close(io);
        try file.writeStreamingAll(io, entry);
    }

    /// 按需获取：先查缓存，未命中则从文件读取最后一行
    pub fn fetch(self: *Collector, key: []const u8) ![]const u8 {
        if (self.cache.get(key)) |val| {
            return val;
        }

        const io = self.io;
        const cwd = Dir.cwd();

        // 打开 data_dir
        var data_dir = Dir.openDir(cwd, io, self.data_dir, .{}) catch return error.CaptureFailed;
        defer data_dir.close(io);

        // 打开 h01 子目录
        var user_dir = Dir.openDir(data_dir, io, "h01", .{}) catch return error.CaptureFailed;
        defer user_dir.close(io);

        // 读取文件内容到固定 buffer
        var buf: [1024 * 64]u8 = undefined;
        const data = Dir.readFile(user_dir, io, "records.jsonl", &buf) catch return error.CaptureFailed;

        if (data.len == 0) return error.CaptureFailed;

        // 找到最后一个非空行：从尾部向前扫描
        var end = data.len;
        // 跳过尾部空白
        while (end > 0 and (data[end - 1] == '\n' or data[end - 1] == '\r')) {
            end -= 1;
        }
        if (end == 0) return error.CaptureFailed;
        // 找到行首
        var start = end;
        while (start > 0 and data[start - 1] != '\n') {
            start -= 1;
        }
        const last_line = data[start..end];

        const owned = try self.allocator.dupe(u8, last_line);
        try self.cache.put(key, owned);
        return owned;
    }
};

test "buildRecordEntry serializes GPS location" {
    const allocator = std.testing.allocator;
    const env = EnvContext{
        .temperature = 24.5,
        .humidity = 61.0,
        .pressure = 1008.2,
        .wind_speed = 5.4,
        .weather = "小雨",
        .timestamp = 1775786391,
        .latitude = 39.9042,
        .longitude = 116.4074,
    };

    const entry = try buildRecordEntry(allocator, "拍照完成", env);
    defer allocator.free(entry);

    try std.testing.expect(std.mem.containsAtLeast(u8, entry, 1, "\"lat\":39.904200"));
    try std.testing.expect(std.mem.containsAtLeast(u8, entry, 1, "\"lon\":116.407400"));
    try std.testing.expect(std.mem.containsAtLeast(u8, entry, 1, "\"weather\":\"小雨\""));
    try std.testing.expect(std.mem.containsAtLeast(u8, entry, 1, "\"pressure\":1008.2"));
    try std.testing.expect(std.mem.containsAtLeast(u8, entry, 1, "\"wind_speed\":5.4"));
}

test "fetch returns last non-empty line and uses cache" {
    const allocator = std.testing.allocator;
    var threaded: Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var user_dir = try Dir.createDirPathOpen(tmp.dir, io, "h01", .{});
    defer user_dir.close(io);

    {
        var file = try Dir.createFile(user_dir, io, "records.jsonl", .{ .truncate = true });
        defer file.close(io);
        try file.writeStreamingAll(io, "first line\nsecond line\n\n");
    }

    const data_dir = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path[0..]});
    defer allocator.free(data_dir);

    var collector = Collector.withDir(allocator, io, data_dir);
    defer collector.deinit();

    const first_fetch = try collector.fetch("latest_audio_snapshot");
    try std.testing.expectEqualStrings("second line", first_fetch);

    {
        var file = try Dir.createFile(user_dir, io, "records.jsonl", .{ .truncate = true });
        defer file.close(io);
        try file.writeStreamingAll(io, "third line\n");
    }

    const cached_fetch = try collector.fetch("latest_audio_snapshot");
    try std.testing.expectEqualStrings("second line", cached_fetch);

    const refreshed_fetch = try collector.fetch("latest_feedback_snapshot");
    try std.testing.expectEqualStrings("third line", refreshed_fetch);
}
