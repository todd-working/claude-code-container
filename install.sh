#!/bin/bash

SHELL_FUNCTION='# Claude Code sandbox function
claude-sandbox() {
    local project_path="${1:-$(pwd)}"
    local project_name="$(basename "$project_path")"
    docker run -it --rm \
        --name "claude-$project_name" \
        -e TERM=xterm-256color \
        -v "$project_path":/home/claude/workspace \
        claude-sandbox
}'

RC_FILE="$HOME/.zshrc"

# Check if function already exists
if grep -q "claude-sandbox()" "$RC_FILE" 2>/dev/null; then
    echo "claude-sandbox function already exists in $RC_FILE"
    exit 0
fi

echo "This will add the following to $RC_FILE:"
echo ""
echo "$SHELL_FUNCTION"
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "" >> "$RC_FILE"
    echo "$SHELL_FUNCTION" >> "$RC_FILE"
    echo "Added claude-sandbox function to $RC_FILE"
    echo "Run 'source $RC_FILE' to activate"
else
    echo "Aborted"
    exit 1
fi
