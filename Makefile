# Makefile for gh-refme

SHELL := /bin/bash
.SHELLFLAGS := -e

# Configuration
VERSION := 1.2.1
PREFIX := /usr/local
EXTENSION_NAME := gh-refme

# Paths
TEST_DIR := tests
EXAMPLE_DIR := examples
DOCS_DIR := docs

# Files
SCRIPT_NAME := gh-refme
TEST_SCRIPTS := $(wildcard $(TEST_DIR)/*.sh)
EXAMPLE_FILES := $(wildcard $(EXAMPLE_DIR)/*.sh $(EXAMPLE_DIR)/*.yml)

# Targets
.PHONY: all test clean install uninstall dist gh-extension check help npm-pack npm-publish

# Default target
all: help

# Install as a GitHub CLI extension
gh-extension-install:
	@echo "Installing as GitHub CLI extension..."
	@gh extension install .
	@echo "Extension installed! Run 'gh refme --help' to get started."

# Run all tests
test: 
	@echo "Running all tests..."
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/*.sh
	@$(TEST_DIR)/run-all-tests.sh

# Run basic test only
test-basic:
	@echo "Running basic test..."
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/test.sh
	@$(TEST_DIR)/test.sh

# Run security test only
test-security:
	@echo "Running security tests..."
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/security-test.sh
	@$(TEST_DIR)/security-test.sh

# Run shellcheck if available
check:
	@echo "Running shellcheck..."
	@chmod +x $(SCRIPT_NAME)
	@chmod +x $(TEST_DIR)/shellcheck-test.sh
	@$(TEST_DIR)/shellcheck-test.sh

# Install the script
install:
	@echo "Installing $(SCRIPT_NAME) to $(PREFIX)/bin/gh-refme"
	@mkdir -p $(PREFIX)/bin
	@install -m 755 $(SCRIPT_NAME) $(PREFIX)/bin/gh-refme

# Uninstall the script
uninstall:
	@echo "Uninstalling gh-refme from $(PREFIX)/bin"
	@rm -f $(PREFIX)/bin/gh-refme

# Create a distribution tarball
dist:
	@echo "Creating distribution package..."
	@mkdir -p dist
	@tar -czf dist/gh-refme-$(VERSION).tar.gz $(SCRIPT_NAME) gh-refme.json README.md $(DOCS_DIR) $(EXAMPLE_DIR) $(TEST_DIR) LICENSE

# NPM targets
npm-pack:
	@echo "Creating npm package..."
	@npm pack

npm-publish:
	@echo "Publishing to npm..."
	@npm publish

# Clean up generated files
clean:
	@echo "Cleaning up..."
	@rm -rf dist
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@rm -f *.tgz

# Show help information
help:
	@echo "GitHub RefMe - Makefile Help"
	@echo "=========================="
	@echo "Available targets:"
	@echo "  all                  : Run all tests (default)"
	@echo "  test                 : Run all tests"
	@echo "  test-basic           : Run basic functionality test"
	@echo "  test-security        : Run security tests"
	@echo "  check                : Run shellcheck analysis"
	@echo "  install              : Install script to $(PREFIX)/bin"
	@echo "  uninstall            : Remove script from $(PREFIX)/bin"
	@echo "  gh-extension-install : Install as GitHub CLI extension locally"
	@echo "  dist                 : Create distribution package"
	@echo "  npm-pack             : Create npm package"
	@echo "  npm-publish          : Publish to npm"
	@echo "  clean                : Remove temporary files"
	@echo "  help                 : Show this help information"
	@echo ""
	@echo "Configuration:"
	@echo "  PREFIX      : Installation prefix (default: $(PREFIX))"
	@echo "  Example: make PREFIX=/usr/local install"
