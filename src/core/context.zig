const std = @import("std");

pub const QueryType = enum {
    recent_vitals,
    medication_history,
    environment_risk,
    user_feedback,
};

/// Agent 按需拉取的上下文中枢
/// 支持缓存、查询和动态注入
pub const ContextBrain = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]u8),

    pub fn init(allocator: std.mem.Allocator) ContextBrain {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap([]u8).init(allocator),
        };
    }

    pub fn deinit(self: *ContextBrain) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// 注入/更新缓存条目
    pub fn put(self: *ContextBrain, key: []const u8, value: []const u8) !void {
        const owned = try self.allocator.dupe(u8, value);
        if (try self.cache.fetchPut(key, owned)) |old| {
            self.allocator.free(old.value);
        }
    }

    /// 按 QueryType 查询数据
    pub fn query(self: *const ContextBrain, query_type: QueryType) ![]u8 {
        const key = @tagName(query_type);
        if (self.cache.get(key)) |val| {
            return try self.allocator.dupe(u8, val);
        }
        // 未命中：返回占位数据
        return try std.fmt.allocPrint(self.allocator, "{{\"source\":\"default\",\"type\":\"{s}\"}}", .{key});
    }

    /// 按字符串 key 查询
    pub fn get(self: *const ContextBrain, key: []const u8) ?[]const u8 {
        return self.cache.get(key);
    }
};
