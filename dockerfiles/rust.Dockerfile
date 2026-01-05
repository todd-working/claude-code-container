FROM claude-sandbox-base

USER root

# Install Rust dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    lldb \
    && rm -rf /var/lib/apt/lists/*

# Create .claude directory for CLAUDE.md
RUN mkdir -p /home/claude/.claude && chown claude:claude /home/claude/.claude

USER claude

# Install Rust via rustup
ENV CARGO_HOME=/home/claude/.cargo
ENV RUSTUP_HOME=/home/claude/.rustup
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile default

# Add components and tools
RUN rustup component add clippy rustfmt rust-analyzer \
    && cargo install cargo-watch cargo-edit

# Create CLAUDE.md with build and profiling instructions
RUN cat > /home/claude/.claude/CLAUDE.md << 'EOF'
# Rust Development Environment

## Building for macOS

Binaries built in this container are Linux executables. **For macOS binaries, build on the host Mac.**

This is especially important for projects using:
- **Metal** (GPU acceleration)
- **Core Graphics / Core Audio** (Apple frameworks)
- **Native macOS UI** (Cocoa, SwiftUI bindings)

### Workflow

Use this container for:
- Claude assistance with code
- Running `cargo check`, `cargo clippy`, `cargo test`
- Linting and formatting

Build release binaries on the Mac:
```bash
# Exit container, then on Mac:
cd ~/projects/myapp
cargo build --release
```

Since the project is mounted, code changes made in the container are on the Mac filesystem.

## Profiling with flamegraph

Flamegraph is not pre-installed. When profiling is needed:

1. Install flamegraph:
   ```bash
   cargo install flamegraph
   ```

2. **Important**: This container needs profiling capabilities. Tell the user to:
   - Exit the current container
   - Restart with: `claude-sandbox-rust-profile [project_path]`
   - Or add flags: `--cap-add=SYS_PTRACE --security-opt seccomp=unconfined`

3. Run the profiler:
   ```bash
   cargo flamegraph --bin <binary_name>
   ```
EOF

WORKDIR /home/claude/workspace
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
