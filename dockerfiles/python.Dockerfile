FROM claude-sandbox-base

USER root

# Install Python 3.12 from deadsnakes PPA
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Install pip and uv (fast Python package manager)
RUN apt-get update && apt-get install -y --no-install-recommends python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --break-system-packages uv

USER claude

# Set up Python environment
ENV PATH="/home/claude/.local/bin:${PATH}"

# Install Python tools via uv
RUN uv tool install ruff \
    && uv tool install mypy \
    && uv tool install pytest \
    && uv tool install ipython

# Note: py-spy requires sudo/root for some operations, install on-demand if needed

WORKDIR /home/claude/workspace
CMD ["script", "-q", "-c", "claude --dangerously-skip-permissions", "/dev/null"]
