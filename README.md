## H2O — Home Health Observer

家庭健康观察员：基于多模态 AI Agent 的非侵入式健康监测系统。

### 架构

```
┌─────────────────────────────────────────────────┐
│                   Workflow 状态机                 │
│         evaluate → guidance → collect → ...      │
├──────────┬──────────┬───────────────────────────┤
│ HealthAgent       │ EnvironmentAgent            │
│ (证据评估/引导)    │ (环境风险分析)               │
├──────────┴──────────┴───────────────────────────┤
│              ContextBrain (上下文中枢)            │
│              按需查询 · 动态缓存 · 注入           │
├──────────┬──────────┬──────────┬────────────────┤
│ Mapper   │ Anomaly  │ Guider   │ Memory         │
│ 动态评估  │ 异常检测  │ 采集引导  │ 文件存档        │
├──────────┴──────────┴──────────┴────────────────┤
│   Audio      │    Vision      │    LLM          │
│ 深度语音分析  │ 皮肤/形态学     │ Ollama 推理     │
└──────────────┴────────────────┴─────────────────┘
```

### 核心理念

**逐渐披露（Progressive Disclosure）** —— Agent 不接收全量预注入数据，而是通过 `ContextBrain` 按需拉取所需上下文。当评估证据不足时，`ProbingGuider` 主动引导用户采集额外数据，形成 **评估 → 引导 → 采集 → 重评估** 的闭环。

### 模块说明

| 模块 | 路径 | 职责 |
|------|------|------|
| **ContextBrain** | `src/core/context.zig` | 上下文中枢，缓存 + 按需查询 |
| **Mapper** | `src/core/mapper.zig` | 动态加权多模态融合评估引擎 |
| **Workflow** | `src/core/workflow.zig` | 状态机驱动的评估工作流 |
| **HealthAgent** | `src/core/agents.zig` | 证据充分性评估 + 引导触发 |
| **EnvironmentAgent** | `src/core/agents.zig` | 环境风险分析 |
| **ProbingGuider** | `src/core/guider.zig` | 采集操作指引生成 |
| **AnomalyDetector** | `src/core/anomaly.zig` | 余弦相似度异常检测 |
| **Memory** | `src/core/memory.zig` | 基于文件的多用户记录管理 |
| **Collector** | `src/io/collector.zig` | 带缓存 + 环境上下文的数据采集器 |
| **DeepAnalyzer** | `src/audio/deep.zig` | 深度语音分析 (RMS/F0/语速/情绪) |
| **SkinTone** | `src/vision/skin.zig` | HSV 空间肤色分析 |
| **Morphology** | `src/vision/morphology.zig` | OpenCV 斑点形态学分析 |
| **Ollama Client** | `src/llm/ollama.zig` | 本地 LLM 推理客户端 |

### 构建与运行

**依赖**:
- Zig ≥ 0.16.0-dev
- OpenCV 4 (`brew install opencv`)

```bash
# 构建
zig build

# 运行
zig-out/bin/h2o
```

### 数据格式

健康记录存储在 `data/<user_id>/` 下，JSONL 格式：

- `records.jsonl` — 评估结果记录
- `feedback.jsonl` — 用户反馈
- `medication.jsonl` — 用药记录
