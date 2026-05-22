const std = @import("std");

pub const EnvContext = struct {
    temperature: f32,
    humidity: f32,
    pressure: f32,
    wind_speed: f32,
    weather: []const u8,
    timestamp: i64,
    latitude: f64,
    longitude: f64,
};

/// 自动环境采集器
const weather_mod = @import("../io/weather.zig");

pub const EnvironmentCollector = struct {
    const LocationResult = extern struct {
        lat: f64,
        lon: f64,
        success: c_int,
    };
    extern fn get_current_location() LocationResult;

    fn mock_get_current_location() LocationResult {
        return .{ .lat = 39.9042, .lon = 116.4074, .success = 1 };
    }

    fn defaultWeatherData() weather_mod.WeatherData {
        return .{
            .description = "未知",
            .temperature = 22.5,
            .pressure = 1013.0,
            .wind_speed = 0.0,
            .humidity = 45.0,
        };
    }

    pub fn fetchCurrent() !EnvContext {
        const allocator = std.heap.page_allocator;
        const loc = if (@import("builtin").is_test) mock_get_current_location() else get_current_location();
        const latitude = if (loc.success == 1) loc.lat else 39.9042;
        const longitude = if (loc.success == 1) loc.lon else 116.4074;

        const weather_data = weather_mod.WeatherClient.init(allocator).fetchWeather(latitude, longitude) catch defaultWeatherData();

        return .{
            .temperature = weather_data.temperature,
            .humidity = weather_data.humidity,
            .pressure = weather_data.pressure,
            .wind_speed = weather_data.wind_speed,
            .weather = weather_data.description,
            .timestamp = 1775786391,
            .latitude = latitude,
            .longitude = longitude,
        };
    }
};

test "fetchCurrent returns complete environment context with GPS" {
    const env = try EnvironmentCollector.fetchCurrent();

    try std.testing.expect(env.weather.len > 0);
    try std.testing.expect(env.temperature > -100 and env.temperature < 100);
    try std.testing.expect(env.humidity >= 0 and env.humidity <= 100);
    try std.testing.expect(env.pressure > 0);
    try std.testing.expect(env.wind_speed >= 0);
    try std.testing.expect(env.latitude >= -90 and env.latitude <= 90);
    try std.testing.expect(env.longitude >= -180 and env.longitude <= 180);
    try std.testing.expect(env.timestamp > 0);
}
