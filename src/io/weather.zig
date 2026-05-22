const std = @import("std");

pub const WeatherData = struct {
    description: []const u8,
    temperature: f32,
    pressure: f32,
    wind_speed: f32,
    humidity: f32,
};

pub const WeatherClient = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WeatherClient {
        return .{ .allocator = allocator };
    }

    pub fn fetchWeather(self: WeatherClient, lat: f64, lon: f64) !WeatherData {
        const body = try self.httpGet(lat, lon);
        defer self.allocator.free(body);

        const code = parseWeatherCode(body) orelse 0;
        const temp = parseField(body, "\"temperature_2m\":") orelse 0.0;
        const pressure = parseField(body, "\"surface_pressure\":") orelse 0.0;
        const wind_speed = parseField(body, "\"wind_speed_10m\":") orelse 0.0;
        const humidity = parseField(body, "\"relative_humidity_2m\":") orelse 0.0;

        return WeatherData{
            .description = try self.allocator.dupe(u8, describeWeatherCode(code)),
            .temperature = temp,
            .pressure = pressure,
            .wind_speed = wind_speed,
            .humidity = humidity,
        };
    }

    fn httpGet(self: WeatherClient, lat: f64, lon: f64) ![]u8 {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://api.open-meteo.com/v1/forecast?latitude={d:.6}&longitude={d:.6}&current=weather_code,temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m",
            .{ lat, lon },
        );
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
            .response_writer = &response_body.writer,
            .headers = .{
                .user_agent = .{ .override = "h2o/0.1" },
            },
        });
        if (result.status != .ok) return error.HttpRequestFailed;

        return try response_body.toOwnedSlice();
    }
};

fn parseField(json: []const u8, key: []const u8) ?f32 {
    const start = std.mem.lastIndexOf(u8, json, key) orelse return null;
    var index = start + key.len;

    while (index < json.len and (json[index] == ' ' or json[index] == '\n' or json[index] == '\r' or json[index] == '\t')) : (index += 1) {}

    var end = index;
    while (end < json.len and ((json[end] >= '0' and json[end] <= '9') or json[end] == '.' or json[end] == '-')) : (end += 1) {}
    if (end == index) return null;

    return std.fmt.parseFloat(f32, json[index..end]) catch null;
}

fn parseWeatherCode(json: []const u8) ?u8 {
    const key = "\"weather_code\":";
    const start = std.mem.lastIndexOf(u8, json, key) orelse return null;
    var index = start + key.len;

    while (index < json.len and (json[index] == ' ' or json[index] == '\n' or json[index] == '\r' or json[index] == '\t')) : (index += 1) {}

    var end = index;
    while (end < json.len and json[end] >= '0' and json[end] <= '9') : (end += 1) {}
    if (end == index) return null;

    return std.fmt.parseInt(u8, json[index..end], 10) catch null;
}

fn describeWeatherCode(code: u8) []const u8 {
    return switch (code) {
        0 => "晴朗",
        1 => "基本晴",
        2 => "局部多云",
        3 => "阴天",
        45, 48 => "有雾",
        51, 53, 55 => "毛毛雨",
        56, 57 => "冻毛毛雨",
        61, 63, 65 => "下雨",
        66, 67 => "冻雨",
        71, 73, 75, 77 => "下雪",
        80, 81, 82 => "阵雨",
        85, 86 => "阵雪",
        95 => "雷暴",
        96, 99 => "雷暴伴冰雹",
        else => "未知",
    };
}

test "parse weather code from json body" {
    const code = parseWeatherCode("{\"current\":{\"weather_code\":80}}") orelse unreachable;
    try std.testing.expectEqual(@as(u8, 80), code);
}

test "parse float weather fields from json body" {
    const json = "{\"current\":{\"temperature_2m\":23.7,\"relative_humidity_2m\":58,\"surface_pressure\":1012.4,\"wind_speed_10m\":4.8}}";

    try std.testing.expectEqual(@as(?f32, 23.7), parseField(json, "\"temperature_2m\":"));
    try std.testing.expectEqual(@as(?f32, 58), parseField(json, "\"relative_humidity_2m\":"));
    try std.testing.expectEqual(@as(?f32, 1012.4), parseField(json, "\"surface_pressure\":"));
    try std.testing.expectEqual(@as(?f32, 4.8), parseField(json, "\"wind_speed_10m\":"));
}
