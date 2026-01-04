FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    ncurses-base \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Set terminal environment
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash claude

# Set working directory
WORKDIR /home/claude/workspace

# Switch to non-root user
USER claude

# Launch Claude Code with full permissions (safe since container is isolated)
# Using script to force proper PTY allocation for interactive menus
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
