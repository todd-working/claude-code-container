#!/bin/bash
# install.sh - Install claude-sandbox command
#
# This script:
# 1. Checks prerequisites (Docker, ~/.claude, base image)
# 2. Installs claude-sandbox to ~/.claude/bin/
# 3. Adds ~/.claude/bin to PATH in your shell rc file
# 4. Removes old shell function if present (migration)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude/bin"
SCRIPT_NAME="claude-sandbox"

echo "Installing claude-sandbox..."
echo ""

# ============================================================
# PREREQUISITE CHECKS
# ============================================================

# Check Docker is installed
if ! command -v docker &>/dev/null; then
    echo "✗ Docker not found. Install Docker Desktop first."
    exit 1
fi

# Check Docker is running
if ! docker info &>/dev/null 2>&1; then
    echo "✗ Docker is not running. Start Docker Desktop first."
    exit 1
fi
echo "✓ Docker is running"

# Check ~/.claude exists
if [[ ! -d "$HOME/.claude" ]]; then
    echo ""
    echo "✗ ~/.claude not found."
    echo ""
    echo "  Claude Code needs to run once outside the container to create"
    echo "  authentication credentials and settings."
    echo ""
    echo "  Run this first:"
    echo "    npx @anthropic-ai/claude-code"
    echo ""
    echo "  Then re-run this installer."
    exit 1
fi
echo "✓ ~/.claude exists"

# Check if base image exists (offer to build)
if ! docker image inspect claude-sandbox-base &>/dev/null 2>&1; then
    echo ""
    echo "⚠ Docker image 'claude-sandbox-base' not found."
    echo ""
    read -p "Build now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        make -C "$SCRIPT_DIR" build-base || exit 1
    else
        echo "Skipping. Run 'make build-base' before using claude-sandbox."
    fi
else
    echo "✓ Base image exists"
fi

echo ""

# ============================================================
# MIGRATION: Remove old shell function from rc files
# ============================================================

remove_old_function() {
    local rc_file="$1"
    if [[ -f "$rc_file" ]] && grep -q "# BEGIN Claude Code sandbox" "$rc_file" 2>/dev/null; then
        echo "Removing old claude-sandbox function from $rc_file..."
        # Remove everything between BEGIN and END markers
        if sed -i.bak '/# BEGIN Claude Code sandbox/,/# END Claude Code sandbox/d' "$rc_file"; then
            rm -f "$rc_file.bak"
            echo "✓ Old function removed"
        else
            echo "⚠ Could not remove old function from $rc_file"
            echo "  Backup saved at: $rc_file.bak"
        fi
    fi
}

# Check common rc files for old function
remove_old_function "$HOME/.zshrc"
remove_old_function "$HOME/.bashrc"
remove_old_function "$HOME/.profile"

# ============================================================
# INSTALL SCRIPT
# ============================================================

# Validate source script exists
if [[ ! -f "$SCRIPT_DIR/bin/claude-sandbox" ]]; then
    echo "✗ bin/claude-sandbox not found in $SCRIPT_DIR"
    echo "  Make sure you're running from the claude-code-container repository."
    exit 1
fi

# Create bin directory
mkdir -p "$INSTALL_DIR"

# Copy script
cp "$SCRIPT_DIR/bin/claude-sandbox" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "Created: $INSTALL_DIR/$SCRIPT_NAME"
echo ""

# ============================================================
# ADD TO PATH
# ============================================================

# Detect shell and select rc file
PATH_LINE='export PATH="$HOME/.claude/bin:$PATH"'

case "$SHELL" in
    */zsh)  RC_FILE="$HOME/.zshrc" ;;
    */bash) RC_FILE="$HOME/.bashrc" ;;
    *)      RC_FILE="$HOME/.profile" ;;
esac

# Check if already in PATH (check both current PATH and rc file)
if [[ ":$PATH:" == *":$HOME/.claude/bin:"* ]]; then
    echo "~/.claude/bin already in PATH"
elif grep -qF '.claude/bin' "$RC_FILE" 2>/dev/null; then
    echo "PATH already configured in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# Claude Code sandbox" >> "$RC_FILE"
    echo "$PATH_LINE" >> "$RC_FILE"
    echo "Added to PATH in $RC_FILE:"
    echo "  $PATH_LINE"
fi

# Verify PATH is correct
if [[ ":$PATH:" != *":$HOME/.claude/bin:"* ]]; then
    echo ""
    echo "⚠ Note: ~/.claude/bin is not yet in your current PATH."
    echo "  Run: source $RC_FILE"
    echo "  Or open a new terminal."
fi

echo ""
echo "============================================================"
echo "Installation complete!"
echo ""
echo "To activate now:"
echo "  source $RC_FILE"
echo ""
echo "Or open a new terminal."
echo ""
echo "Usage:"
echo "  claude-sandbox [python|go|rust|base] [project_path]"
echo ""
echo "Examples:"
echo "  claude-sandbox python .        # Python, current directory"
echo "  claude-sandbox go ~/myproject  # Go, specific project"
echo ""
echo "Script location: $INSTALL_DIR/$SCRIPT_NAME"
echo "============================================================"
