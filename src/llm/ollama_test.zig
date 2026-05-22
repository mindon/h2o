const std = @import("std");
const ollama = @import("ollama.zig");

test "Ollama Client extractResponse correctly" {
    const allocator = std.testing.allocator;
    var client = ollama.Client.init(allocator);

    const json_data = "{\"model\":\"llama3\",\"created_at\":\"2026-04-10T12:00:00Z\",\"response\":\"这是一条测试回复\",\"done\":true}";
    const extracted = try client.extractResponse(json_data);
    defer allocator.free(extracted);

    try std.testing.expectEqualStrings("这是一条测试回复", extracted);
}

test "Ollama Client extractResponse with escaped quotes" {
    const allocator = std.testing.allocator;
    var client = ollama.Client.init(allocator);

    const json_data = "{\"response\":\"He said \\\"Hello\\\"\"}";
    const extracted = try client.extractResponse(json_data);
    defer allocator.free(extracted);

    try std.testing.expectEqualStrings("He said \\\"Hello\\\"", extracted);
}
