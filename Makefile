# Task runner for glaze-borders.
#
# swift-testing and llvm-cov require the full Xcode toolchain (the Command Line
# Tools instance lacks both), so we point SwiftPM at Xcode here without changing
# the global `xcode-select` setting.
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

# Where SwiftPM writes the coverage profile and the test bundle.
ARCH := $(shell uname -m)
BUILD := .build/$(ARCH)-apple-macosx/debug
PROFDATA := $(BUILD)/codecov/default.profdata
TEST_BIN := $(BUILD)/glaze-bordersPackageTests.xctest/Contents/MacOS/glaze-bordersPackageTests

.PHONY: build release test coverage coverage-html run install commit clean help

help: ## List available tasks
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

build: ## Debug build
	swift build

release: ## Optimized release build
	swift build -c release

test: ## Run the test suite
	swift test

coverage: ## Run tests and print a per-file coverage summary for the sources
	swift test --enable-code-coverage
	@xcrun llvm-cov report "$(TEST_BIN)" -instr-profile "$(PROFDATA)" \
		Sources/GlazeBordersCore/*.swift 2>/dev/null \
		| sed 's#.*/GlazeBordersCore/##'

coverage-html: ## Generate an HTML coverage report under .coverage/ and open it
	swift test --enable-code-coverage
	@xcrun llvm-cov show "$(TEST_BIN)" -instr-profile "$(PROFDATA)" \
		-format=html -output-dir=.coverage \
		-ignore-filename-regex='(Tests|\.build|checkouts)' 2>/dev/null
	@echo "open .coverage/index.html"
	@open .coverage/index.html

run: release ## Build release and run the daemon in the foreground
	.build/release/glaze-borders

install: release ## Install the release binary to ~/.local/bin
	cp .build/release/glaze-borders ~/.local/bin/glaze-borders

clean: ## Remove build artifacts and coverage output
	swift package clean
	rm -rf .coverage
