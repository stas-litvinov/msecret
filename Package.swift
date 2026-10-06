// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "msecret",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "msecret", targets: ["msecret"])],
    targets: [
        .target(name: "MSecretCore"),
        .executableTarget(name: "msecret", dependencies: ["MSecretCore"]),
        .testTarget(name: "MSecretCoreTests", dependencies: ["MSecretCore"])
    ]
)
