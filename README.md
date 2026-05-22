# repo-beacon

A Claude Code plugin that automatically injects git repo context into every tool call — so Claude always knows which repo it is working in, without exploring the codebase from scratch.

## What it does

Before every file operation (`Write`, `Edit`, `Read`, `Bash`, `Glob`, `Grep`), repo-beacon:

1. Extracts the file path from the tool call
2. Finds the git root for that path
3. Injects the repo name, branch, GitHub URL, and README as context

Claude receives the correct repo context mid-loop, on every tool call, automatically.

## Requirements

- Claude Code v1.0.33 or later
- `jq` installed on your machine (`brew install jq` or `apt install jq`)
- `git` installed

## Local testing

```bash
claude --plugin-dir ./repo-beacon
```

## Installation (once published)

```bash
/plugin install repo-beacon@your-marketplace
```

## Logs

Logs are written to `~/.claude/logs/repo-beacon.log`.
