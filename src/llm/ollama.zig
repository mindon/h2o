const std = @import("std");

/// Ollama 多模态推理客户端 — 通过 HTTP POST 调用本地 Ollama API
pub const Client = struct {
    allocator: std.mem.Allocator,
    host: []const u8 = "127.0.0.1",
    port: u16 = 11434,

    pub fn init(allocator: std.mem.Allocator) Client {
        return .{ .allocator = allocator };
    }

    pub fn withEndpoint(allocator: std.mem.Allocator, host: []const u8, port: u16) Client {
        return .{ .allocator = allocator, .host = host, .port = port };
    }

    /// 调用 Ollama /api/generate 接口进行文本推理
    pub fn generate(self: Client, model: []const u8, prompt: []const u8) ![]u8 {
        const GenerateRequest = struct {
            model: []const u8,
            prompt: []const u8,
            stream: bool,
        };

        const body = try std.json.Stringify.valueAlloc(self.allocator, GenerateRequest{
            .model = model,
            .prompt = prompt,
            .stream = false,
        }, .{});
        defer self.allocator.free(body);

        return self.httpPost("/api/generate", body);
    }

    /// 调用 Ollama /api/chat 接口进行对话
    pub fn chat(self: Client, model: []const u8, user_message: []const u8) ![]u8 {
        const Message = struct {
            role: []const u8,
            content: []const u8,
        };
        const ChatRequest = struct {
            model: []const u8,
            messages: []const Message,
            stream: bool,
        };

        const messages = [_]Message{.{ .role = "user", .content = user_message }};
        const body = try std.json.Stringify.valueAlloc(self.allocator, ChatRequest{
            .model = model,
            .messages = &messages,
            .stream = false,
        }, .{});
        defer self.allocator.free(body);

        return self.httpPost("/api/chat", body);
    }

    /// 底层 HTTP POST：通过 Zig 标准库连接本地 Ollama
    fn httpPost(self: Client, path: []const u8, body: []const u8) ![]u8 {
        const url = try std.fmt.allocPrint(self.allocator, "http://{s}:{d}{s}", .{ self.host, self.port, path });
        defer self.allocator.free(url);

        var threaded: std.Io.Threaded = .init(self.allocator, .{});
        defer threaded.deinit();

        var client: std.http.Client = .{
            .allocator = self.allocator,
            .io = threaded.io(),
        };
        defer client.deinit();

        var response_body = std.Io.Writer.Allocating.init(self.allocator);
        defer response_body.deinit();

        const result = try client.fetch(.{
            .location = .{ .url = url },
            .payload = body,
            .response_writer = &response_body.writer,
            .headers = .{
                .user_agent = .{ .override = "h2o/0.1" },
                .content_type = .{ .override = "application/json" },
            },
            .keep_alive = false,
        });
        if (result.status != .ok) return error.HttpRequestFailed;

        return try response_body.toOwnedSlice();
    }

    /// 从 Ollama JSON 响应中提取 "response" 字段的值
    pub fn extractResponse(self: Client, json_data: []const u8) ![]u8 {
        // 简单的 JSON 字段提取：查找 "response":" 然后取到下一个未转义的引号
        const needle = "\"response\":\"";
        if (std.mem.indexOf(u8, json_data, needle)) |start| {
            const value_start = start + needle.len;
            var end = value_start;
            while (end < json_data.len) : (end += 1) {
                if (json_data[end] == '"' and (end == value_start or json_data[end - 1] != '\\')) break;
            }
            return try self.allocator.dupe(u8, json_data[value_start..end]);
        }
        return try self.allocator.dupe(u8, json_data);
    }
};
