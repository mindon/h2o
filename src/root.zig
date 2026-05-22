/// H2O 健康多模态分析系统 — 统一导出入口
///
/// 模块结构:
///   types  — 领域数据模型 (Profile, Vitals, Biometrics 等)
///   core   — 核心引擎 (评估、上下文、Agent、工作流、异常检测)
///   audio  — 音频分析 (基础分析器 + 深度特征提取)
///   vision — 视觉分析 (皮肤色彩 + 斑点形态学/OpenCV)
///   io     — 数据采集 (带缓存的 Collector)
///   llm    — LLM 推理 (Ollama 客户端)
pub const types = @import("types/root.zig");

pub const core = struct {
    pub const context = @import("core/context.zig");
    pub const env_context = @import("core/env_context.zig");
    pub const memory = @import("core/memory.zig");
    pub const mapper = @import("core/mapper.zig");
    pub const anomaly = @import("core/anomaly.zig");
    pub const agents = @import("core/agents.zig");
    pub const guider = @import("core/guider.zig");
    pub const workflow = @import("core/workflow.zig");
};

pub const audio = struct {
    pub const analyzer = @import("audio/analyzer.zig");
    pub const deep = @import("audio/deep.zig");
};

pub const vision = struct {
    pub const morphology = @import("vision/morphology.zig");
    pub const skin = @import("vision/skin.zig");
};

pub const io = struct {
    pub const collector = @import("io/collector.zig");
};

pub const llm = struct {
    pub const ollama = @import("llm/ollama.zig");
};
