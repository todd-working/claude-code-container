# Claude Code Container

A Docker-based sandbox for running Claude Code CLI in isolation from your host system.

## Why Use This?

- **Isolation**: Claude Code runs in a container with no access to your host filesystem (except the project you mount)
- **Unconstrained**: Claude Code runs with `--dangerously-skip-permissions`, auto-approving all actions
- **Safe**: The combination of container isolation + full permissions means Claude can work freely without risk to your host

## Installation

```bash
git clone <repo-url>
cd claude-code-container
make install
source ~/.zshrc
```

This will:
1. Build the Docker image (`claude-sandbox`)
2. Prompt to add the `claude-sandbox` shell function to your `~/.zshrc`

### Manual Setup

If you prefer not to use the install script:

```bash
# Build the image
make build

# Add this function to your shell rc file
claude-sandbox() {
    local project_path="${1:-$(pwd)}"
    local project_name="$(basename "$project_path")"
    docker run -it --rm \
        --name "claude-$project_name" \
        -v "$project_path":/home/claude/workspace \
        claude-sandbox
}
```

### Uninstall

```bash
make uninstall
```

This removes the Docker image. You'll need to manually remove the shell function from `~/.zshrc` if desired.

## Usage

```bash
# Run from a project directory (mounts current directory)
cd ~/projects/my-app
claude-sandbox

# Or specify a project path
claude-sandbox ~/projects/my-app
```

## Authentication

Each container session requires fresh OAuth authentication. When Claude Code starts, it will prompt you to sign in via your browser. Credentials are not persisted between sessions.

## Security Notes

- **Container isolation**: Only the mounted project directory is accessible to Claude Code
- **No host credentials**: Your `~/.claude` directory is not mounted; each session authenticates independently
- **Ephemeral containers**: The `--rm` flag ensures containers are destroyed on exit
- **`--dangerously-skip-permissions`**: This flag is safe here because the container provides the isolation boundary

## What's Installed

- Ubuntu 24.04
- curl, git, build-essential
- Python 3, pip
- Node.js, npm
- Claude Code CLI (`@anthropic-ai/claude-code`)
