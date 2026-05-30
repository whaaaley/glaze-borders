# swift-testing requires the full Xcode toolchain (Command Line Tools lacks it),
# so point SwiftPM at Xcode without changing the global `xcode-select` setting.
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

.PHONY: build release test commit install-hooks

build:
	swift build

release:
	swift build -c release

test:
	swift test

# Validate a message: make commit MSG='feat: do thing'
commit: release
	.build/release/commit '$(MSG)'

# Register the commit-msg hook for the repo (run once per fresh clone).
install-hooks:
	git -C .. config core.hooksPath tools-swift/hooks
