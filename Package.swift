// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CircleMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CircleMenu", path: "Sources/CircleMenu")
    ]
)
