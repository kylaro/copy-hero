// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CopyHero",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "CopyHero", path: "Sources/CopyHero")
    ]
)
