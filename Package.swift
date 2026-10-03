// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZARConverter",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ZARConverter", targets: ["ZARConverter"])],
    targets: [
        .executableTarget(name: "ZARConverter", path: "Sources/ZARConverter")
    ]
)
