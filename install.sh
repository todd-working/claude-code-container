#!/bin/bash

SHELL_FUNCTION='# BEGIN Claude Code sandbox functions
claude-sandbox() {
    local lang="${1:-base}"
    local project_path="${2:-$(pwd)}"

    # If only one arg and it looks like a path, treat as base + path
    if [[ $# -eq 1 && -d "$1" ]]; then
        lang="base"
        project_path="$1"
    fi

    local project_name="$(basename "$project_path")"
    local image="claude-sandbox-base"
    local extra_volumes=""

    case "$lang" in
        go)
            image="claude-sandbox-go"
            extra_volumes="-v claude-go-cache:/home/claude/go/pkg -v claude-go-bin:/home/claude/go/bin"
            ;;
        rust)
            image="claude-sandbox-rust"
            extra_volumes="-v claude-cargo-registry:/home/claude/.cargo/registry -v claude-cargo-git:/home/claude/.cargo/git -v claude-cargo-bin:/home/claude/.cargo/bin"
            ;;
        python|py)
            image="claude-sandbox-python"
            extra_volumes="-v claude-uv-cache:/home/claude/.cache/uv -v claude-python-bin:/home/claude/.local/bin"
            ;;
        base)
            image="claude-sandbox-base"
            ;;
        *)
            echo "Unknown language: $lang"
            echo "Usage: claude-sandbox [go|rust|python|base] [project_path]"
            return 1
            ;;
    esac

    docker run -it --rm \
        --name "claude-$project_name" \
        -e TERM=xterm-256color \
        -v claude-auth:/home/claude/.claude \
        -v "$project_path":/home/claude/workspace \
        $extra_volumes \
        "$image"
}

# Rust profiling variant with capabilities for flamegraph
claude-sandbox-rust-profile() {
    local project_path="${1:-$(pwd)}"
    local project_name="$(basename "$project_path")"

    docker run -it --rm \
        --name "claude-$project_name" \
        -e TERM=xterm-256color \
        --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined \
        -v claude-auth:/home/claude/.claude \
        -v claude-cargo-registry:/home/claude/.cargo/registry \
        -v claude-cargo-git:/home/claude/.cargo/git \
        -v claude-cargo-bin:/home/claude/.cargo/bin \
        -v "$project_path":/home/claude/workspace \
        claude-sandbox-rust
}
# END Claude Code sandbox functions'

RC_FILE="$HOME/.zshrc"

# Remove old claude-sandbox functions if they exist
remove_old_functions() {
    if grep -q "claude-sandbox()" "$RC_FILE" 2>/dev/null; then
        echo "Removing old claude-sandbox functions from $RC_FILE..."
        # Try new marker-based removal first (robust)
        if grep -q "# BEGIN Claude Code sandbox" "$RC_FILE" 2>/dev/null; then
            sed -i.bak '/# BEGIN Claude Code sandbox/,/# END Claude Code sandbox/d' "$RC_FILE"
        else
            # Fallback for old installations without markers
            sed -i.bak '/# Claude Code sandbox/,/^}$/d' "$RC_FILE"
            sed -i.bak '/claude-sandbox-rust-profile()/,/^}$/d' "$RC_FILE"
        fi
        # Clean up consecutive empty lines
        sed -i.bak '/^$/N;/^\n$/d' "$RC_FILE"
        rm -f "$RC_FILE.bak"
        echo "Old functions removed."
    fi
}

remove_old_functions

echo "This will add the following to $RC_FILE:"
echo ""
echo "$SHELL_FUNCTION"
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "" >> "$RC_FILE"
    echo "$SHELL_FUNCTION" >> "$RC_FILE"
    echo ""
    echo "Done! Run 'source $RC_FILE' to activate."
else
    echo "Aborted"
    exit 1
fi
