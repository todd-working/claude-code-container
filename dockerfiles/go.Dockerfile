FROM claude-sandbox-base

USER root

# Install Go 1.23 (detect architecture)
ENV GO_VERSION=1.23.4
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | tar -C /usr/local -xzf -

# Install graphviz for pprof visualization
RUN apt-get update && apt-get install -y --no-install-recommends \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Set up Go environment
ENV PATH="/usr/local/go/bin:/home/claude/go/bin:${PATH}"
ENV GOPATH=/home/claude/go
ENV GOBIN=/home/claude/go/bin

# Create .claude directory for CLAUDE.md
RUN mkdir -p /home/claude/.claude && chown claude:claude /home/claude/.claude

USER claude

# Create go directories
RUN mkdir -p /home/claude/go/bin /home/claude/go/pkg

# Create CLAUDE.md with cross-compilation notes
RUN cat > /home/claude/.claude/CLAUDE.md << 'EOF'
# Go Development Environment

## Cross-Compiling for macOS

Binaries built in this container are Linux executables. To build for macOS (Apple Silicon):

```bash
GOOS=darwin GOARCH=arm64 go build -o myapp
```

The resulting binary can run directly on the host Mac.

## CGO Note

If the project uses CGO, disable it for cross-compilation:

```bash
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o myapp
```

Most pure Go projects work fine with CGO disabled.
EOF

# Install Go tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install mvdan.cc/gofumpt@latest

WORKDIR /home/claude/workspace
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
