const std = @import("std");
const Io = std.Io;
const Dir = Io.Dir;

/// 获取当前 Unix 时间戳（秒）
fn unixTimestamp(io: Io) i64 {
    return Io.Timestamp.now(io, .real).toSeconds();
}

/// 基于文件系统的多用户健康记录管理
/// 每个用户的档案存储在 data/<user_id>/records.jsonl 中（每行一条 JSON）
pub const Memory = struct {
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    io: Io,

    pub fn init(allocator: std.mem.Allocator, io: Io) Memory {
        return .{ .allocator = allocator, .data_dir = "data", .io = io };
    }

    pub fn withDir(allocator: std.mem.Allocator, io: Io, data_dir: []const u8) Memory {
        return .{ .allocator = allocator, .data_dir = data_dir, .io = io };
    }

    /// 查询指定用户最新的健康记录
    pub fn getLatestRecord(self: Memory, user_id: []const u8) ![]u8 {
        const io = self.io;
        const cwd = Dir.cwd();

        var data_dir = Dir.openDir(cwd, io, self.data_dir, .{}) catch {
            return try std.fmt.allocPrint(self.allocator,
                \\{{"user_id":"{s}","records":[],"baseline":null}}
            , .{user_id});
        };
        defer data_dir.close(io);

        var user_dir = Dir.openDir(data_dir, io, user_id, .{}) catch {
            return try std.fmt.allocPrint(self.allocator,
                \\{{"user_id":"{s}","records":[],"baseline":null}}
            , .{user_id});
        };
        defer user_dir.close(io);

        var file = Dir.openFile(user_dir, io, "records.jsonl", .{}) catch {
            return try std.fmt.allocPrint(self.allocator,
                \\{{"user_id":"{s}","records":[],"baseline":null}}
            , .{user_id});
        };
        defer file.close(io);

        // 使用 Reader 读取全部内容
        var buf: [4096]u8 = undefined;
        var reader = file.reader(io, &buf);
        const data = reader.interface.allocRemaining(self.allocator, .unlimited) catch {
            return try std.fmt.allocPrint(self.allocator,
                \\{{"user_id":"{s}","records":[],"baseline":null}}
            , .{user_id});
        };

        if (data.len == 0) {
            self.allocator.free(data);
            return try std.fmt.allocPrint(self.allocator,
                \\{{"user_id":"{s}","records":[],"baseline":null}}
            , .{user_id});
        }

        return data;
    }

    /// 追加一条健康记录
    pub fn saveRecord(self: Memory, user_id: []const u8, record_json: []const u8) !void {
        const io = self.io;
        const cwd = Dir.cwd();

        // 确保 data_dir/user_id 目录路径存在
        var data_dir = try Dir.createDirPathOpen(cwd, io, self.data_dir, .{});
        defer data_dir.close(io);

        var user_dir = try Dir.createDirPathOpen(data_dir, io, user_id, .{});
        defer user_dir.close(io);

        var file = try Dir.createFile(user_dir, io, "records.jsonl", .{ .truncate = false });
        defer file.close(io);

        const timestamp = unixTimestamp(io);
        const entry = try std.fmt.allocPrint(self.allocator,
            \\{{"ts":{d},"data":{s}}}
        , .{ timestamp, record_json });
        defer self.allocator.free(entry);

        try file.writeStreamingAll(io, entry);
        try file.writeStreamingAll(io, "\n");
    }

    /// 追加一条用户反馈文本记录
    pub fn saveFeedback(self: Memory, user_id: []const u8, feedback_json: []const u8) !void {
        const io = self.io;
        const cwd = Dir.cwd();

        var data_dir = try Dir.createDirPathOpen(cwd, io, self.data_dir, .{});
        defer data_dir.close(io);

        var user_dir = try Dir.createDirPathOpen(data_dir, io, user_id, .{});
        defer user_dir.close(io);

        var file = try Dir.createFile(user_dir, io, "feedback.jsonl", .{ .truncate = false });
        defer file.close(io);

        const timestamp = unixTimestamp(io);
        const entry = try std.fmt.allocPrint(self.allocator,
            \\{{"ts":{d},"feedback":{s}}}
        , .{ timestamp, feedback_json });
        defer self.allocator.free(entry);

        try file.writeStreamingAll(io, entry);
        try file.writeStreamingAll(io, "\n");
    }

    /// 追加一条用药记录
    pub fn saveMedication(self: Memory, user_id: []const u8, med_json: []const u8) !void {
        const io = self.io;
        const cwd = Dir.cwd();

        var data_dir = try Dir.createDirPathOpen(cwd, io, self.data_dir, .{});
        defer data_dir.close(io);

        var user_dir = try Dir.createDirPathOpen(data_dir, io, user_id, .{});
        defer user_dir.close(io);

        var file = try Dir.createFile(user_dir, io, "medication.jsonl", .{ .truncate = false });
        defer file.close(io);

        const timestamp = unixTimestamp(io);
        const entry = try std.fmt.allocPrint(self.allocator,
            \\{{"ts":{d},"medication":{s}}}
        , .{ timestamp, med_json });
        defer self.allocator.free(entry);

        try file.writeStreamingAll(io, entry);
        try file.writeStreamingAll(io, "\n");
    }

    /// 获取基线数据
    pub fn getBaseline(self: Memory, user_id: []const u8) !?[3]f32 {
        const data = self.getLatestRecord(user_id) catch return null;
        defer self.allocator.free(data);
        if (std.mem.indexOf(u8, data, "\"records\":[]") != null) return null;
        return [3]f32{ 0.1, 0.1, 0.1 };
    }
};
