.PHONY: build install uninstall help

IMAGE_NAME := claude-sandbox

help:
	@echo "Usage:"
	@echo "  make build     - Build the Docker image"
	@echo "  make install   - Build image and add shell function to ~/.zshrc"
	@echo "  make uninstall - Remove the Docker image"

build:
	docker build -t $(IMAGE_NAME) .

install: build
	@./install.sh

uninstall:
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
	@echo "Image removed. Manually remove the claude-sandbox function from ~/.zshrc if desired."
