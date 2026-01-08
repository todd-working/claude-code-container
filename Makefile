.PHONY: build-base build-go build-rust build-python build-all \
        install uninstall update-claude update-go update-rust update-python update-all help

BASE_IMAGE := claude-sandbox-base
GO_IMAGE := claude-sandbox-go
RUST_IMAGE := claude-sandbox-rust
PYTHON_IMAGE := claude-sandbox-python

help:
	@echo "Usage:"
	@echo "  make install       - Build all images and install claude-sandbox command"
	@echo "  make uninstall     - Remove images, volumes, and claude-sandbox script"
	@echo ""
	@echo "Build:"
	@echo "  make build-all     - Build all Docker images"
	@echo "  make build-base    - Build base image only"
	@echo "  make build-go      - Build Go image"
	@echo "  make build-rust    - Build Rust image"
	@echo "  make build-python  - Build Python image"
	@echo ""
	@echo "Update:"
	@echo "  make update-all    - Rebuild everything with latest versions"
	@echo "  make update-claude - Rebuild base with latest Claude Code CLI"
	@echo "  make update-go     - Rebuild Go image"
	@echo "  make update-rust   - Rebuild Rust image"
	@echo "  make update-python - Rebuild Python image"

build-base:
	docker build -t $(BASE_IMAGE) -f dockerfiles/base.Dockerfile .

build-go: build-base
	docker build -t $(GO_IMAGE) -f dockerfiles/go.Dockerfile .

build-rust: build-base
	docker build -t $(RUST_IMAGE) -f dockerfiles/rust.Dockerfile .

build-python: build-base
	docker build -t $(PYTHON_IMAGE) -f dockerfiles/python.Dockerfile .

build-all: build-base build-go build-rust build-python

install: build-all
	@./install.sh

update-claude:
	@echo "Rebuilding base image to get latest Claude Code CLI..."
	docker build --no-cache -t $(BASE_IMAGE) -f dockerfiles/base.Dockerfile .
	@echo "Done. Run 'make build-all' to rebuild language images on new base."

update-go: update-claude
	@echo "Rebuilding Go image with latest tools..."
	docker build --no-cache -t $(GO_IMAGE) -f dockerfiles/go.Dockerfile .

update-rust: update-claude
	@echo "Rebuilding Rust image with latest tools..."
	docker build --no-cache -t $(RUST_IMAGE) -f dockerfiles/rust.Dockerfile .

update-python: update-claude
	@echo "Rebuilding Python image with latest tools..."
	docker build --no-cache -t $(PYTHON_IMAGE) -f dockerfiles/python.Dockerfile .

update-all: update-go update-rust update-python
	@echo "All images rebuilt with latest versions."

uninstall:
	docker rmi $(BASE_IMAGE) $(GO_IMAGE) $(RUST_IMAGE) $(PYTHON_IMAGE) 2>/dev/null || true
	docker volume rm claude-cargo-registry claude-cargo-git claude-cargo-bin claude-go-cache claude-go-bin claude-uv-cache claude-python-bin 2>/dev/null || true
	rm -f $(HOME)/.claude/bin/claude-sandbox
	@echo "Removed: Docker images, volumes, and ~/.claude/bin/claude-sandbox"
	@echo "Note: PATH entry in shell rc file can be removed manually if desired"
