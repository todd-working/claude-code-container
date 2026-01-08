# Claude Code Container

A little tool I built for myself to run Claude Code in **unhinged mode** with relative safety.

Claude runs with `--dangerously-skip-permissions` (no confirmation prompts), but inside a Docker container that isolates it from your host system. The container can only access the project directory you mount—so Claude can go wild without nuking your machine.

> **Warning**: Your global `~/.claude` directory is mounted read-write into the container. This includes your authentication credentials, settings, and global CLAUDE.md. Claude can modify these files. Be careful, and consider adding protections to your `~/.claude/CLAUDE.md` (see below).

## Why Use This?

- **Unhinged**: Claude runs with `--dangerously-skip-permissions`, auto-approving all actions
- **Isolated**: Container has no access to your host filesystem except the mounted project
- **Safe-ish**: The combination means Claude can work freely without destroying your system
- **Language-optimized**: Dedicated images with full toolchains, linters, and profilers

## Available Images

| Image | Contents |
|-------|----------|
| `claude-sandbox-base` | Node.js 22, Claude CLI, git, common tools |
| `claude-sandbox-go` | Go 1.23, golangci-lint, delve, gopls, gofumpt |
| `claude-sandbox-rust` | Rust stable, clippy, rustfmt, rust-analyzer, cargo-watch |
| `claude-sandbox-python` | Python 3.12, uv, ruff, mypy, pytest, ipython |

## Prerequisites

1. **Docker Desktop** - Install and start Docker Desktop
2. **Claude Code CLI** - Run once outside the container to create `~/.claude`:
   ```bash
   npx @anthropic-ai/claude-code
   ```

## Installation

```bash
git clone https://github.com/todd-working/claude-code-container.git
cd claude-code-container
make install
source ~/.zshrc  # or open a new terminal
```

This will:
1. Build all Docker images (base + language variants)
2. Install `claude-sandbox` script to `~/.claude/bin/`
3. Add `~/.claude/bin` to your PATH

Your `~/.claude` directory is mounted directly into the container, so authentication and settings sync bidirectionally between host and container.

## Usage

```bash
# Go project
claude-sandbox go ~/projects/my-go-app

# Rust project
claude-sandbox rust ~/projects/my-rust-app

# Python project
claude-sandbox python ~/projects/my-python-app

# Base image (just Claude CLI + common tools)
claude-sandbox base ~/projects/any-project

# Default: base image, current directory
claude-sandbox
```

### Rust Profiling

For profiling Rust code with `flamegraph`, add the `--profile` flag which enables necessary kernel access:

```bash
claude-sandbox rust ~/projects/my-rust-app --profile
```

Inside the container, install flamegraph on-demand:
```bash
cargo install flamegraph
cargo flamegraph --bin my-binary
```

## Build Individual Images

```bash
make build-base     # Base image only
make build-go       # Go image (includes base)
make build-rust     # Rust image (includes base)
make build-python   # Python image (includes base)
make build-all      # All images
```

## Updating

Update Claude Code CLI and tools to latest versions:

```bash
make update-claude  # Rebuild base with latest Claude CLI
make update-go      # Rebuild Go image with latest tools
make update-rust    # Rebuild Rust image with latest tools
make update-python  # Rebuild Python image with latest tools
make update-all     # Rebuild everything fresh
```

## Cross-Compilation Notes

### Go

Binaries built in the container are Linux executables. To build for macOS:

```bash
GOOS=darwin GOARCH=arm64 go build -o myapp
```

### Rust

Cross-compiling Rust for macOS from Linux is complex. For macOS binaries—especially those using Metal, GPU acceleration, or Apple frameworks—**build on your Mac directly**.

Recommended workflow:
- Use the container for Claude assistance, linting, and testing
- Build release binaries on your Mac (code is mounted, so changes sync automatically)

## Persistent Caches

Each language image mounts volumes for caches and installed tools:

| Image | Volumes |
|-------|---------|
| Go | `claude-go-cache` (modules), `claude-go-bin` (installed tools) |
| Rust | `claude-cargo-registry`, `claude-cargo-git`, `claude-cargo-bin` (installed tools) |
| Python | `claude-uv-cache` (packages), `claude-python-bin` (installed tools) |

Tools installed via `go install`, `cargo install`, or `uv tool install` persist across sessions.

Additionally, your host's `~/.claude` directory is bind-mounted for bidirectional sync of authentication and settings.

## Uninstall

```bash
make uninstall
```

This removes Docker images, volumes, and the `~/.claude/bin/claude-sandbox` script.

To also remove the PATH entry, edit your `~/.zshrc` and remove the line:
```bash
export PATH="$HOME/.claude/bin:$PATH"
```

## Security Notes

- **Container isolation**: Only the mounted project directory and `~/.claude` are accessible to Claude Code
- **Bidirectional auth sync**: Credentials from `~/.claude` are shared between host and container
- **Ephemeral containers**: The `--rm` flag ensures containers are destroyed on exit
- **`--dangerously-skip-permissions`**: Safe here because the container provides the isolation boundary
- **UID matching**: Container runs as your host UID, so file permissions work correctly

### Protecting Your Global ~/.claude Directory

Since `~/.claude` is mounted read-write, Claude can modify your global settings and CLAUDE.md. To add a safeguard, add this to your `~/.claude/CLAUDE.md`:

```markdown
# Global Claude Configuration

**IMPORTANT**: This is my global ~/.claude directory. Always ask before modifying any files here, including this file, settings.json, or any other configuration.
```

This won't prevent changes when Claude is unhinged, but it helps when running Claude normally outside the container.

## Project-Level Instructions

Language containers (Python, Go, Rust) will append container-specific instructions to your project's `CLAUDE.md` on first run. This includes cross-compilation notes, tooling tips, and Makefile templates.

**Important**: The container only appends to an existing CLAUDE.md—it won't create one. Run `/init` inside Claude first to create your project's CLAUDE.md, then the container will add its instructions on next startup.

To ignore the container marker file in git:

```
.claude/.container-initialized
```

## What's Installed

### Base Image
- Ubuntu 24.04
- Node.js 22.x (LTS)
- Claude Code CLI
- git, curl, build-essential, jq, ripgrep, fd-find

### Go Image (extends base)
- Go 1.23
- golangci-lint (meta-linter)
- delve (debugger)
- gopls (language server)
- gofumpt (formatter)
- graphviz (for pprof visualization)

### Rust Image (extends base)
- Rust stable via rustup
- clippy, rustfmt
- rust-analyzer
- cargo-watch, cargo-edit
- lldb (debugger)

### Python Image (extends base)
- Python 3.12
- uv (fast package manager)
- ruff (linter/formatter)
- mypy (type checker)
- pytest
- ipython
