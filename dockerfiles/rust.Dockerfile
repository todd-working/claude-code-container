FROM claude-sandbox-base

USER root

# Install Rust dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    lldb \
    && rm -rf /var/lib/apt/lists/*

USER claude

# Install Rust via rustup
ENV CARGO_HOME=/home/claude/.cargo
ENV RUSTUP_HOME=/home/claude/.rustup
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile default

# Add components and tools
RUN rustup component add clippy rustfmt rust-analyzer \
    && cargo install cargo-watch cargo-edit \
    && chmod -R 777 /home/claude/.cargo /home/claude/.rustup

# Container-specific CLAUDE.md (copied to workspace/.claude/ on startup by base entrypoint)
USER root
RUN cat > /opt/claude-container/CLAUDE.md << 'EOF'
# Container Environment: Rust

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
   - Restart with: `claude-sandbox rust [project_path] --profile`

3. Run the profiler:
   ```bash
   cargo flamegraph --bin <binary_name>
   ```

## Makefile.local Template

For building on the host Mac, create a `Makefile.local` with this template:

```makefile
# Makefile.local - Host Mac build targets
# Generated for Rust project

.PHONY: check-deps install-deps build-mac build-release run clean

# Check for required tools
check-deps:
	@echo "Checking dependencies..."
	@command -v rustc >/dev/null || { echo "❌ Rust not found. Run: brew install rustup && rustup-init"; exit 1; }
	@command -v cargo >/dev/null || { echo "❌ Cargo not found. Run: rustup-init"; exit 1; }
	@echo "✓ Rust $$(rustc --version | cut -d' ' -f2)"
	@echo "✓ Cargo $$(cargo --version | cut -d' ' -f2)"
	@echo "All dependencies satisfied."

# Install missing dependencies (macOS with Homebrew)
install-deps:
	@command -v brew >/dev/null || { echo "Homebrew required: https://brew.sh"; exit 1; }
	@command -v rustup >/dev/null || { brew install rustup && rustup-init -y; }
	@echo "Dependencies installed."

# Build debug binary for macOS
build-mac: check-deps
	@echo "Building debug binary..."
	cargo build
	@echo "Built: target/debug/"

# Build optimized release binary for macOS
build-release: check-deps
	@echo "Building release binary..."
	cargo build --release
	@echo "Built: target/release/"

# Run the application
run: build-mac
	cargo run

# Run tests
test:
	cargo test

# Run clippy lints
lint:
	cargo clippy -- -D warnings

clean:
	cargo clean
```

Copy this to your project and customize as needed.
EOF

USER claude
