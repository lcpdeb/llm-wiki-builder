<!-- llm-wiki-builder:start -->
## LLM Wiki 工作区

本项目使用 `llm-wiki/` 作为内嵌 LLM Wiki。当前项目根目录就是源材料；不要要求用户把代码或文档复制到 `raw/`。

### 读取范围
- 读取项目根目录中的代码、文档和配置作为分析材料。
- 默认排除 `llm-wiki/`、`.git/`、`.obsidian/`、`node_modules/`、`vendor/`、`dist/`、`build/`、`.next/`、`target/`、二进制大文件和 `.env*` 等密钥文件。

### 写入范围
- 分析输出只能写入 `llm-wiki/`。
- 除非用户明确要求，不修改项目源码、原始文档或配置文件。
- 摘要放入 `llm-wiki/资料摘要/`，概念页放入 `llm-wiki/概念/`，综合分析放入 `llm-wiki/综合分析/`，图表资源放入 `llm-wiki/assets/` 或 `llm-wiki/canvas/`。
- 每次分析后更新 `llm-wiki/Wiki 目录.md` 和 `llm-wiki/操作日志.md`。

### 项目名称
- Wiki 名称：llm-wiki-builder
<!-- llm-wiki-builder:end -->

