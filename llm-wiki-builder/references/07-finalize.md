# Stage 7: Finalize

Do not initialize a nested git repository for `llm-wiki/`. The wiki is embedded in the user's existing project and should be committed with that project when the user chooses.

## Summary Output

Print one concise summary and stop. Scale it to actual results.

```text
✓ LLM Wiki ready: <project>/llm-wiki

Project:
  <project>

Configured:
  ✓ llm-wiki scaffold
  ✓ AGENTS.md managed block
  ✓ Obsidian plugins and config   # only if this stage ran
  ✓ detected paths saved once to llm-wiki/detected-paths.json

Manual install required:
  ⚠ <only items that actually failed>

Quick start:
  1. cd <project>
  2. Open this project in Obsidian
  3. Start your AI agent
  4. Ask: "Analyze this repository and update llm-wiki"
```

Drop empty sections. Do not add extra re-run tips after the summary.

