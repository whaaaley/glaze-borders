// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "tools",
    platforms: [.macOS(.v14)],
    targets: [
        // Library: pure commit-message parsing + validation, no I/O. Testable.
        .target(
            name: "CommitKit",
            path: "Sources/CommitKit"
        ),
        // Executable: thin CLI that reads a message (arg/file/stdin) and validates it.
        .executableTarget(
            name: "commit",
            dependencies: ["CommitKit"],
            path: "Sources/commit"
        ),
        // Tests: parser + validator parity with the original Deno tools.
        .testTarget(
            name: "CommitKitTests",
            dependencies: ["CommitKit"],
            path: "Tests/CommitKitTests"
        ),
    ]
)
