# Claude Code Container

A Docker-based sandbox for running Claude Code CLI in isolation from your host system, with language-specific images for Go, Rust, and Python development.

## Why Use This?

- **Isolation**: Claude Code runs in a container with no access to your host filesystem (except the project you mount)
- **Unconstrained**: Claude Code runs with `--dangerously-skip-permissions`, auto-approving all actions
- **Safe**: The combination of container isolation + full permissions means Claude can work freely without risk to your host
- **Language-optimized**: Dedicated images with full toolchains, linters, and profilers

## Available Images

| Image | Contents |
|-------|----------|
| `claude-sandbox-base` | Node.js 22, Claude CLI, git, common tools |
| `claude-sandbox-go` | Go 1.23, golangci-lint, delve, gopls, gofumpt |
| `claude-sandbox-rust` | Rust stable, clippy, rustfmt, rust-analyzer, cargo-watch |
| `claude-sandbox-python` | Python 3.12, uv, ruff, mypy, pytest, ipython |

## Installation

```bash
git clone https://github.com/todd-working/claude-code-container.git
cd claude-code-container
make install
source ~/.zshrc
```

This will:
1. Build all Docker images (base + language variants)
2. Copy your `~/.claude` credentials into a persistent Docker volume
3. Add the `claude-sandbox` shell function to your `~/.zshrc`

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

For profiling Rust code with `flamegraph`, use the profile variant which enables necessary kernel access:

```bash
claude-sandbox-rust-profile ~/projects/my-rust-app
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
| All | `claude-auth` (credentials) |
| Go | `claude-go-cache` (modules), `claude-go-bin` (installed tools) |
| Rust | `claude-cargo-registry`, `claude-cargo-git`, `claude-cargo-bin` (installed tools) |
| Python | `claude-uv-cache` (packages), `claude-python-bin` (installed tools) |

Tools installed via `go install`, `cargo install`, or `uv tool install` persist across sessions.

## Uninstall

```bash
make uninstall
```

This removes all Docker images and volumes. Manually remove the shell functions from `~/.zshrc` if desired.

## Security Notes

- **Container isolation**: Only the mounted project directory is accessible to Claude Code
- **Persistent auth volume**: Credentials stored in Docker volume, not on host
- **Ephemeral containers**: The `--rm` flag ensures containers are destroyed on exit
- **`--dangerously-skip-permissions`**: Safe here because the container provides the isolation boundary

## Project-Level Instructions

On first run, each language container creates a `.claude/CLAUDE.md` in your project with container-specific instructions (cross-compilation, Makefile templates, etc.). This helps Claude Code understand the container environment.

If you don't want this tracked in git, add to your `.gitignore`:

```
.claude/
```

Or to keep your own CLAUDE.md but ignore the container marker:

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
