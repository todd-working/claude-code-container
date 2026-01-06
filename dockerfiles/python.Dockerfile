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

# Container-specific CLAUDE.md (copied to workspace/.claude/ on startup by base entrypoint)
USER root
RUN cat > /opt/claude-container/CLAUDE.md << 'EOF'
# Container Environment: Python

## Available Tools

- **uv** - Fast Python package manager (use instead of pip)
- **ruff** - Linter and formatter
- **mypy** - Type checker
- **pytest** - Test runner
- **ipython** - Interactive Python shell

## Virtual Environments

Create a virtual environment for your project:

```bash
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

## Running on Host Mac

Python code runs the same in the container and on Mac. For dependencies that require compilation (numpy, etc.), you may need to rebuild on the Mac:

```bash
# On Mac:
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

## Makefile.local Template

For convenience on the host Mac, create a `Makefile.local`:

```makefile
# Makefile.local - Host Mac targets
# Generated for Python project

.PHONY: check-deps install-deps venv test lint clean

# Check for required tools
check-deps:
	@echo "Checking dependencies..."
	@command -v python3 >/dev/null || { echo "❌ Python not found. Run: brew install python@3.12"; exit 1; }
	@command -v uv >/dev/null || { echo "❌ uv not found. Run: brew install uv"; exit 1; }
	@echo "✓ Python $$(python3 --version | cut -d' ' -f2)"
	@echo "✓ uv $$(uv --version | cut -d' ' -f2)"
	@echo "All dependencies satisfied."

# Install missing dependencies (macOS with Homebrew)
install-deps:
	@command -v brew >/dev/null || { echo "Homebrew required: https://brew.sh"; exit 1; }
	@command -v python3 >/dev/null || brew install python@3.12
	@command -v uv >/dev/null || brew install uv
	@echo "Dependencies installed."

# Create virtual environment and install dependencies
venv: check-deps
	uv venv
	. .venv/bin/activate && uv pip install -r requirements.txt

# Run tests
test:
	. .venv/bin/activate && pytest

# Run linter
lint:
	. .venv/bin/activate && ruff check .

clean:
	rm -rf .venv __pycache__ .pytest_cache .mypy_cache .ruff_cache
```
EOF

USER claude
