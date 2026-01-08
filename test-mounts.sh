#!/bin/bash
# Test script to verify container mount points are working (read/write)
# Uses inside/outside checksum comparison to verify alignment

set -e

IMAGE="${1:-claude-sandbox-base}"
PROJECT_DIR="${2:-$(pwd)}"

echo "=== Mount Point Alignment Test ==="
echo "Image: $IMAGE"
echo "Project: $PROJECT_DIR"
echo ""

# ============================================================
# PART 1: Check for required directories and Claude files
# ============================================================

echo "1. Checking required directories and files..."
echo ""

# --- Global ~/.claude directory ---
echo "   Global ~/.claude:"

if [[ ! -d "$HOME/.claude" ]]; then
    echo "   ✗ Directory not found: ~/.claude"
    echo ""
    echo "   To fix: Run Claude Code outside the container first:"
    echo "     claude"
    echo ""
    echo "   This will create ~/.claude with auth and settings."
    exit 1
fi
echo "   ✓ Directory exists"

# Check for global settings.json
GLOBAL_SETTINGS=""
if [[ -f "$HOME/.claude/settings.json" ]]; then
    GLOBAL_SETTINGS="$HOME/.claude/settings.json"
    echo "   ✓ settings.json exists"
else
    echo "   ⚠ settings.json not found (created after first use)"
fi

# Check for global CLAUDE.md
GLOBAL_CLAUDE_MD=""
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
    echo "   ✓ CLAUDE.md exists (global instructions)"
else
    echo "   ⚠ CLAUDE.md not found"
    echo "     To create: Run 'claude' and use /init, or create manually"
fi

echo ""

# --- Project directory ---
echo "   Project $PROJECT_DIR:"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "   ✗ Project directory not found"
    exit 1
fi
echo "   ✓ Directory exists"

# Check for project CLAUDE.md (can be at root or in .claude/)
PROJECT_CLAUDE_MD=""
PROJECT_CLAUDE_CONTAINER_PATH=""
if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
    PROJECT_CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
    PROJECT_CLAUDE_CONTAINER_PATH="/home/claude/workspace/CLAUDE.md"
    echo "   ✓ CLAUDE.md exists (at project root)"
elif [[ -f "$PROJECT_DIR/.claude/CLAUDE.md" ]]; then
    PROJECT_CLAUDE_MD="$PROJECT_DIR/.claude/CLAUDE.md"
    PROJECT_CLAUDE_CONTAINER_PATH="/home/claude/workspace/.claude/CLAUDE.md"
    echo "   ✓ CLAUDE.md exists (in .claude/)"
else
    echo "   ⚠ CLAUDE.md not found"
    echo "     To create:"
    echo "       Option 1 (outside container): cd $PROJECT_DIR && claude"
    echo "                                     Then run /init"
    echo "       Option 2 (inside container):  claude-sandbox python $PROJECT_DIR"
    echo "                                     Then run /init"
fi

echo ""

# ============================================================
# PART 2: Test mount read/write with synthetic files
# ============================================================

TEST_DIR="$(mktemp -d)"
TEST_ID="$$-$(date +%s)"

echo "2. Testing mount read/write with temporary files..."
echo "   Test dir: $TEST_DIR"

# Create test structure
mkdir -p "$TEST_DIR/.claude"
mkdir -p "$TEST_DIR/workspace/.claude"
echo "host-global-$TEST_ID" > "$TEST_DIR/.claude/test-file"
echo "host-workspace-$TEST_ID" > "$TEST_DIR/workspace/test-file"
echo "host-project-$TEST_ID" > "$TEST_DIR/workspace/.claude/test-file"

# Test container can read
echo ""
echo "   Testing container can READ host files..."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/claude \
    -v "$TEST_DIR/.claude":/home/claude/.claude \
    -v "$TEST_DIR/workspace":/home/claude/workspace \
    "$IMAGE" bash -c '
        cat ~/.claude/test-file > /dev/null
        cat /home/claude/workspace/test-file > /dev/null
        cat /home/claude/workspace/.claude/test-file > /dev/null
    '
echo "   ✓ Container can read all mount points"

# Test container can write to ~/.claude
echo ""
echo "   Testing container can WRITE to ~/.claude..."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/claude \
    -v "$TEST_DIR/.claude":/home/claude/.claude \
    -v "$TEST_DIR/workspace":/home/claude/workspace \
    "$IMAGE" bash -c "echo 'container-wrote-$TEST_ID' > ~/.claude/write-test"

if [[ -f "$TEST_DIR/.claude/write-test" ]] && grep -q "container-wrote-$TEST_ID" "$TEST_DIR/.claude/write-test"; then
    echo "   ✓ ~/.claude is writable"
else
    echo "   ✗ ~/.claude write failed"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Test container can write to workspace
echo ""
echo "   Testing container can WRITE to workspace..."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/claude \
    -v "$TEST_DIR/.claude":/home/claude/.claude \
    -v "$TEST_DIR/workspace":/home/claude/workspace \
    "$IMAGE" bash -c "echo 'container-wrote-$TEST_ID' > /home/claude/workspace/write-test"

if [[ -f "$TEST_DIR/workspace/write-test" ]] && grep -q "container-wrote-$TEST_ID" "$TEST_DIR/workspace/write-test"; then
    echo "   ✓ /home/claude/workspace is writable"
else
    echo "   ✗ workspace write failed"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Test container can write to workspace/.claude
echo ""
echo "   Testing container can WRITE to workspace/.claude..."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/home/claude \
    -v "$TEST_DIR/.claude":/home/claude/.claude \
    -v "$TEST_DIR/workspace":/home/claude/workspace \
    "$IMAGE" bash -c "echo 'container-wrote-$TEST_ID' > /home/claude/workspace/.claude/write-test"

if [[ -f "$TEST_DIR/workspace/.claude/write-test" ]] && grep -q "container-wrote-$TEST_ID" "$TEST_DIR/workspace/.claude/write-test"; then
    echo "   ✓ /home/claude/workspace/.claude is writable"
else
    echo "   ✗ workspace/.claude write failed"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"
echo ""

# ============================================================
# PART 3: Inside/Outside checksum comparison
# ============================================================

echo "3. Comparing checksums (outside vs inside container)..."

CHECKSUM_FAILED=false

# Function to get md5 on macOS
get_host_md5() {
    md5 -q "$1"
}

# Test global settings.json
if [[ -n "$GLOBAL_SETTINGS" ]]; then
    echo ""
    echo "   ~/.claude/settings.json:"
    HOST_MD5=$(get_host_md5 "$GLOBAL_SETTINGS")
    CONTAINER_MD5=$(docker run --rm \
        --user "$(id -u):$(id -g)" \
        -e HOME=/home/claude \
        -v "$HOME/.claude":/home/claude/.claude \
        -v "$PROJECT_DIR":/home/claude/workspace \
        "$IMAGE" bash -c "md5sum ~/.claude/settings.json | cut -d' ' -f1")

    echo "     Outside (host):  $HOST_MD5"
    echo "     Inside (container): $CONTAINER_MD5"

    if [[ "$HOST_MD5" == "$CONTAINER_MD5" ]]; then
        echo "   ✓ Checksums match"
    else
        echo "   ✗ Checksums DO NOT match"
        CHECKSUM_FAILED=true
    fi
fi

# Test global CLAUDE.md
if [[ -n "$GLOBAL_CLAUDE_MD" ]]; then
    echo ""
    echo "   ~/.claude/CLAUDE.md:"
    HOST_MD5=$(get_host_md5 "$GLOBAL_CLAUDE_MD")
    CONTAINER_MD5=$(docker run --rm \
        --user "$(id -u):$(id -g)" \
        -e HOME=/home/claude \
        -v "$HOME/.claude":/home/claude/.claude \
        -v "$PROJECT_DIR":/home/claude/workspace \
        "$IMAGE" bash -c "md5sum ~/.claude/CLAUDE.md | cut -d' ' -f1")

    echo "     Outside (host):  $HOST_MD5"
    echo "     Inside (container): $CONTAINER_MD5"

    if [[ "$HOST_MD5" == "$CONTAINER_MD5" ]]; then
        echo "   ✓ Checksums match"
    else
        echo "   ✗ Checksums DO NOT match"
        CHECKSUM_FAILED=true
    fi
fi

# Test project CLAUDE.md
if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    echo ""
    echo "   Project CLAUDE.md:"
    HOST_MD5=$(get_host_md5 "$PROJECT_CLAUDE_MD")
    CONTAINER_MD5=$(docker run --rm \
        --user "$(id -u):$(id -g)" \
        -e HOME=/home/claude \
        -v "$HOME/.claude":/home/claude/.claude \
        -v "$PROJECT_DIR":/home/claude/workspace \
        "$IMAGE" bash -c "md5sum $PROJECT_CLAUDE_CONTAINER_PATH | cut -d' ' -f1")

    echo "     Outside (host):  $HOST_MD5"
    echo "     Inside (container): $CONTAINER_MD5"

    if [[ "$HOST_MD5" == "$CONTAINER_MD5" ]]; then
        echo "   ✓ Checksums match"
    else
        echo "   ✗ Checksums DO NOT match"
        CHECKSUM_FAILED=true
    fi
fi

echo ""

if [[ "$CHECKSUM_FAILED" == "true" ]]; then
    echo "=== FAILED: Checksum mismatch detected ==="
    exit 1
fi

echo "=== All mount tests passed ✓ ==="
echo ""
echo "Mount alignment verified:"
echo "  Host                        Container"
echo "  ~/.claude                → /home/claude/.claude"
echo "  $PROJECT_DIR  → /home/claude/workspace"
