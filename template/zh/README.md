# <Wiki Name>

本项目使用基于 [LLM Wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) 的内嵌 `llm-wiki/` 工作区。

当前项目目录就是源材料。AI 生成的摘要、概念页、图表和综合分析都放在 `llm-wiki/`。

## 快速开始

1. 用 [Obsidian](https://obsidian.md) 打开项目根目录。
2. 在项目根目录启动 AI Agent。
3. 让它分析当前仓库并更新 `llm-wiki/`。

## 常用操作

### 分析

```text
分析这个仓库并更新 llm-wiki
总结这个项目的架构
为主要领域概念创建概念页
```

### 查询

```text
这个仓库是做什么的？
A 模块和 B 模块是什么关系？
对比当前几种实现方案
```

### 巡检

```text
对 llm-wiki 做一次健康检查
找出过时页面和缺失链接
```

### 地图（可选 Graphify）

```text
/graphify .
$graphify .   # Codex
```

## 目录结构

- `llm-wiki/` - AI 维护的分析输出
- `llm-wiki/概念/` - 概念页
- `llm-wiki/资料摘要/` - 源材料摘要
- `llm-wiki/综合分析/` - 综合解读
- `llm-wiki/assets/` - 附件和图表
- `llm-wiki/canvas/` - Obsidian Canvas 文件
- `graphify-out/` - 可选 Graphify 地图输出
- `.obsidian/` - Obsidian 配置和插件
- `AGENTS.md` - AI Agent 共享规则

