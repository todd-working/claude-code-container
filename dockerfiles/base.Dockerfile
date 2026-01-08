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

# Verify mount points are accessible (output to stderr to not interfere with commands)
verify_mounts() {
    local failed=false

    # Check ~/.claude is writable
    if ! touch ~/.claude/.mount-test 2>/dev/null; then
        echo "⚠ Warning: ~/.claude is not writable" >&2
        failed=true
    else
        rm -f ~/.claude/.mount-test
    fi

    # Check workspace is writable
    if ! touch /home/claude/workspace/.mount-test 2>/dev/null; then
        echo "⚠ Warning: /home/claude/workspace is not writable" >&2
        failed=true
    else
        rm -f /home/claude/workspace/.mount-test
    fi

    # Check for CLAUDE.md files (informational)
    if [ -f ~/.claude/CLAUDE.md ]; then
        echo "✓ Global CLAUDE.md found" >&2
    else
        echo "○ No global ~/.claude/CLAUDE.md" >&2
    fi

    if [ -f /home/claude/workspace/CLAUDE.md ]; then
        echo "✓ Project CLAUDE.md found (root)" >&2
    elif [ -f /home/claude/workspace/.claude/CLAUDE.md ]; then
        echo "✓ Project CLAUDE.md found (.claude/)" >&2
    else
        echo "○ No project CLAUDE.md (run /init to create)" >&2
    fi

    if $failed; then
        echo "" >&2
        echo "Mount verification failed. Check your docker run command." >&2
        echo "Expected: -v \"\$HOME/.claude\":/home/claude/.claude" >&2
        echo "          -v \"\$PROJECT\":/home/claude/workspace" >&2
    fi
}
verify_mounts

# Check for Claude Code CLI updates (background, non-blocking)
check_claude_update() {
    # Wait for Claude to start before printing anything to avoid output interleaving
    sleep 3
    local installed=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    # Timeout after 5 seconds to avoid hanging on slow/unreachable registry
    local latest=$(timeout 5 npm show @anthropic-ai/claude-code version 2>/dev/null)
    if [ -n "$installed" ] && [ -n "$latest" ] && [ "$installed" != "$latest" ]; then
        echo "" >&2
        echo "╔════════════════════════════════════════════════════════════╗" >&2
        echo "║  Claude Code update available: $installed → $latest" >&2
        echo "║  Run 'make update-claude' on host to rebuild image" >&2
        echo "╚════════════════════════════════════════════════════════════╝" >&2
        echo "" >&2
    fi
}
check_claude_update &

# Append container-specific instructions to existing CLAUDE.md (if present)
# Only append, never create - user should run /init first
MARKER="/home/claude/workspace/.claude/.container-initialized"
if [ -f /opt/claude-container/CLAUDE.md ] && [ ! -f "$MARKER" ]; then
    if [ -f /home/claude/workspace/.claude/CLAUDE.md ]; then
        # Append container instructions to existing CLAUDE.md
        echo "" >> /home/claude/workspace/.claude/CLAUDE.md
        cat /opt/claude-container/CLAUDE.md >> /home/claude/workspace/.claude/CLAUDE.md
        echo "✓ Appended container instructions to .claude/CLAUDE.md" >&2
    elif [ -f /home/claude/workspace/CLAUDE.md ]; then
        # Append to root CLAUDE.md if that's where it is
        echo "" >> /home/claude/workspace/CLAUDE.md
        cat /opt/claude-container/CLAUDE.md >> /home/claude/workspace/CLAUDE.md
        echo "✓ Appended container instructions to CLAUDE.md" >&2
    else
        echo "○ No CLAUDE.md found - run /init to create one" >&2
    fi
    mkdir -p /home/claude/workspace/.claude
    touch "$MARKER"
fi
exec "$@"
SCRIPT

WORKDIR /home/claude/workspace
USER claude

ENTRYPOINT ["/opt/claude-container/entrypoint.sh"]
# Launch Claude Code with full permissions (safe since container is isolated)
CMD ["claude", "--dangerously-skip-permissions"]
