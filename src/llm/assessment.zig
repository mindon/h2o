const std = @import("std");

pub const AssessmentRequest = struct {
    data: []const u8,
    env: Env,
};

pub const Env = struct {
    temp: f32,
    hum: f32,
    weather: []const u8,
    timestamp: i64,
    lat: f64,
    lon: f64,
};

pub const AssessmentResult = struct {
    risk_assessment: []const u8,
    improvement_measures: []const u8,
};

pub fn generateAssessmentPrompt(allocator: std.mem.Allocator, request: AssessmentRequest) ![]u8 {
    return try std.fmt.allocPrint(allocator,
        \\请评估以下用户数据，提供健康风险提示及改善措施。
        \\环境数据：{d}摄氏度，{d}%湿度，天气：{s}，坐标：({d:.6}, {d:.6})，时间戳：{d}
        \\用户记录：{s}
        \\要求：输出格式为{{"risk": "...", "measures": "..."}}
    , .{ request.env.temp, request.env.hum, request.env.weather, request.env.lat, request.env.lon, request.env.timestamp, request.data });
}

test "generateAssessmentPrompt includes risk measures and GPS context" {
    const allocator = std.testing.allocator;
    const request = AssessmentRequest{
        .data = "服药后有轻微头晕",
        .env = .{
            .temp = 26.5,
            .hum = 68.0,
            .weather = "多云",
            .timestamp = 1775786391,
            .lat = 39.9042,
            .lon = 116.4074,
        },
    };

    const prompt = try generateAssessmentPrompt(allocator, request);
    defer allocator.free(prompt);

    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "健康风险提示"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "改善措施"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "39.904200"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "116.407400"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "服药后有轻微头晕"));
}
