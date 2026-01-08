#!/bin/bash

SHELL_FUNCTION='# BEGIN Claude Code sandbox functions
claude-sandbox() {
    local lang="base"
    local project_path="$(pwd)"
    local profile_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                profile_mode=true
                shift
                ;;
            go|rust|python|py|base)
                lang="$1"
                shift
                ;;
            *)
                if [[ -d "$1" ]]; then
                    project_path="$1"
                else
                    echo "Unknown argument: $1"
                    echo "Usage: claude-sandbox [go|rust|python|base] [project_path] [--profile]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    local project_name="$(basename "$project_path")"
    local image="claude-sandbox-base"
    local extra_volumes=""
    local extra_flags=""
    local network_flag=""

    case "$lang" in
        go)
            image="claude-sandbox-go"
            extra_volumes="-v claude-go-cache:/home/claude/go/pkg -v claude-go-bin:/home/claude/go/bin"
            ;;
        rust)
            image="claude-sandbox-rust"
            extra_volumes="-v claude-cargo-registry:/home/claude/.cargo/registry -v claude-cargo-git:/home/claude/.cargo/git -v claude-cargo-bin:/home/claude/.cargo/bin"
            if $profile_mode; then
                extra_flags="--cap-add=SYS_PTRACE --security-opt seccomp=unconfined"
                echo "Profiling mode enabled (SYS_PTRACE + seccomp=unconfined)"
            fi
            ;;
        python|py)
            image="claude-sandbox-python"
            extra_volumes="-v claude-uv-cache:/home/claude/.cache/uv -v claude-python-bin:/home/claude/.local/bin"
            ;;
        base)
            image="claude-sandbox-base"
            ;;
    esac

    # Warn if --profile used with non-Rust
    if $profile_mode && [[ "$lang" != "rust" ]]; then
        echo "Warning: --profile only affects Rust containers (ignored)"
    fi

    # List available Docker networks and ask if user wants to join one
    local networks=($(docker network ls --format "{{.Name}}" | grep -vE "^(bridge|host|none)$"))
    if [[ ${#networks[@]} -gt 0 ]]; then
        echo "Available Docker networks:"
        echo "  0) None (default)"
        local i=1
        for net in "${networks[@]}"; do
            echo "  $i) $net"
            ((i++))
        done
        echo -n "Join a network? [0-$((i-1))]: "
        read -r choice
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ $choice -le ${#networks[@]} ]]; then
            local selected_network="${networks[$((choice-1))]}"
            network_flag="--network $selected_network"
            echo "Joining network: $selected_network"
        fi
    fi

    docker run -it --rm \
        --user "$(id -u):$(id -g)" \
        --name "claude-$project_name" \
        -e TERM=xterm-256color \
        $network_flag \
        $extra_flags \
        -v "$HOME/.claude":/home/claude/.claude \
        -v "$project_path":/home/claude/workspace \
        ${=extra_volumes} \
        "$image"
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
