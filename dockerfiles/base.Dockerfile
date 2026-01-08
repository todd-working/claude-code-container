FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8

# Install Node.js 22.x from NodeSource
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list

# Install all packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    git \
    build-essential \
    curl \
    wget \
    jq \
    ripgrep \
    fd-find \
    locales \
    ncurses-base \
    sudo \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8 \
    && echo "ALL ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nopasswd \
    && chmod 440 /etc/sudoers.d/nopasswd

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user with UID 1000 (delete ubuntu user first if it exists)
# Make home directory world-writable so container can run as any UID (via --user flag)
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 claude \
    && chmod 777 /home/claude

# Create entrypoint script that copies container CLAUDE.md to workspace
RUN mkdir -p /opt/claude-container
COPY --chmod=755 <<'SCRIPT' /opt/claude-container/entrypoint.sh
#!/bin/bash

# Check for Claude Code CLI updates (background, non-blocking)
check_claude_update() {
    # Wait for Claude to start before printing anything to avoid output interleaving
    sleep 3
    local installed=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    # Timeout after 5 seconds to avoid hanging on slow/unreachable registry
    local latest=$(timeout 5 npm show @anthropic-ai/claude-code version 2>/dev/null)
    if [ -n "$installed" ] && [ -n "$latest" ] && [ "$installed" != "$latest" ]; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  Claude Code update available: $installed → $latest"
        echo "║  Run 'make update-claude' on host to rebuild image"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
    fi
}
check_claude_update &

# Copy container CLAUDE.md to workspace/.claude/ on startup
MARKER="/home/claude/workspace/.claude/.container-initialized"
if [ -f /opt/claude-container/CLAUDE.md ] && [ ! -f "$MARKER" ]; then
    mkdir -p /home/claude/workspace/.claude
    if [ -f /home/claude/workspace/.claude/CLAUDE.md ]; then
        # Append to existing CLAUDE.md
        echo "" >> /home/claude/workspace/.claude/CLAUDE.md
        cat /opt/claude-container/CLAUDE.md >> /home/claude/workspace/.claude/CLAUDE.md
    else
        cp /opt/claude-container/CLAUDE.md /home/claude/workspace/.claude/CLAUDE.md
    fi
    touch "$MARKER"
fi
exec "$@"
SCRIPT

WORKDIR /home/claude/workspace
USER claude

ENTRYPOINT ["/opt/claude-container/entrypoint.sh"]
# Launch Claude Code with full permissions (safe since container is isolated)
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
