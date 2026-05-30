# swift-testing requires the full Xcode toolchain (Command Line Tools lacks it),
# so point SwiftPM at Xcode without changing the global `xcode-select` setting.
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

.PHONY: build release test run install

build:
	swift build

release:
	swift build -c release

test:
	swift test

run: release
	.build/release/glaze-borders

install: release
	cp .build/release/glaze-borders ~/.local/bin/glaze-borders
