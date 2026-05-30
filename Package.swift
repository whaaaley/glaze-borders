// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "glaze-borders",
    platforms: [.macOS(.v14)],
    targets: [
        // Library: all logic (pure helpers + AppKit/AX-coupled runtime types).
        // Kept separate from the executable so it can be unit + integration tested.
        .target(
            name: "GlazeBordersCore",
            path: "Sources/GlazeBordersCore"
        ),
        // Executable: thin entry point that wires the library together.
        .executableTarget(
            name: "glaze-borders",
            dependencies: ["GlazeBordersCore"],
            path: "Sources/glaze-borders"
        ),
        // Tests: unit (pure logic) + integration (cross-component behavior).
        .testTarget(
            name: "GlazeBordersTests",
            dependencies: ["GlazeBordersCore"],
            path: "Tests/GlazeBordersTests"
        ),
    ]
)
