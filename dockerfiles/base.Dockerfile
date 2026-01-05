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
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user with UID 1000 (delete ubuntu user first if it exists)
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 claude

WORKDIR /home/claude/workspace
USER claude

# Launch Claude Code with full permissions (safe since container is isolated)
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
