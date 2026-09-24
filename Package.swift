// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KaomojiBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "KaomojiBar", path: "Sources")
    ]
)
