# <Wiki Name> - LLM Wiki 规则

> 基于 [Andrej Karpathy 的 LLM Wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)。
> 本文件定义 AI Agent 如何维护当前项目内嵌的 wiki。

## 源材料与写入边界

- 项目根目录就是源材料。读取当前目录中的代码、文档、配置、记录和说明。
- 摘要、概念页、综合分析、图表、目录和操作日志只写入 `llm-wiki/`。
- 不要要求用户把材料复制到 `raw/`。这个工作流不使用 `raw/` 目录。
- 除非用户明确要求，不修改项目源码和原始文档。

## 默认排除

忽略 `llm-wiki/`、`.git/`、`.obsidian/`、`node_modules/`、`vendor/`、`dist/`、`build/`、`.next/`、`target/`、缓存目录、二进制文件、压缩包，以及 `.env*` 等密钥文件。

## Graphify 地图层（可选）

当项目启用 Graphify 时，`graphify-out/` 是结构地图层，`llm-wiki/` 是长期知识库层。

- 如存在 `graphify-out/GRAPH_REPORT.md`，回答架构、依赖、模块关系、跨文件连接等问题前，先读取该报告。
- 必要时使用 `graphify-out/graph.json` 或 Graphify 查询命令辅助定位，再回到源文件验证关键结论。
- 不要把 Graphify `--wiki` 生成内容自动合并进 `llm-wiki/`。
- 可复用、经验证的解释仍写入 `llm-wiki/资料摘要/`、`llm-wiki/概念/` 或 `llm-wiki/综合分析/`。

## 目录结构

```text
<project>/
├── llm-wiki/
│   ├── 概念/
│   ├── 资料摘要/
│   ├── 综合分析/
│   ├── 归档/
│   ├── assets/
│   │   └── excalidraw/
│   ├── canvas/
│   ├── templates/
│   ├── Wiki 目录.md
│   ├── 操作日志.md
│   └── 知识库概览.md
├── .obsidian/
├── AGENTS.md
└── <项目源码和文档>
```

## 页面格式

每个由 LLM 维护的 wiki 页面都应包含 frontmatter：

```yaml
---
title: 页面标题
type: entity | concept | topic | comparison | source | synthesis
tags: [标签1, 标签2]
aliases: []
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: []
confidence: high | medium | low
---
```

创建页面前，先读取 `llm-wiki/templates/` 中对应模板，并遵循模板结构。

## 工作流

### 分析

当用户要求分析当前项目时：

1. 按默认排除规则扫描项目根目录。
2. 在 `llm-wiki/资料摘要/` 创建源材料摘要。
3. 在 `llm-wiki/概念/` 创建概念页。
4. 在 `llm-wiki/综合分析/` 创建跨模块、跨主题的综合解读。
5. 更新 `llm-wiki/Wiki 目录.md`，并追加 `llm-wiki/操作日志.md`。

### 查询

回答问题时：

1. 优先读取已有 `llm-wiki/` 页面。
2. 当 wiki 信息不足或用户要求重新检查时，再读取项目源文件。
3. 尽量用 `[[wikilink]]` 引用 wiki 页面。
4. 若答案形成可复用知识，保存到 `llm-wiki/综合分析/`。

### 巡检

当用户要求健康检查时，检查 `llm-wiki/` 中的过时页面、孤页、死链、重复概念、缺失摘要和目录漂移，并把结果记录到 `llm-wiki/操作日志.md`。

## 可视化

- Excalidraw 文件放在 `llm-wiki/assets/excalidraw/`。
- Obsidian Canvas 文件放在 `llm-wiki/canvas/`。
- 简单流程、状态和时序图可以使用 Mermaid。

## 安全规则

- 分析过程中不要移动、改写或删除源文件。
- 除非用户明确要求，不要把密钥或私有本地路径写入 wiki 页面。
- `llm-wiki/detected-paths.json` 是本地配置，不是源材料。

