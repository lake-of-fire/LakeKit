// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SessionPortTests",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/lake-of-fire/keychain-swift.git",
                 revision: "15460dbb60bde406dec045d018a1895425c89cd1"),
    ],
    targets: [
        .target(name: "LakeKit", dependencies: [.product(name: "KeychainSwift", package: "keychain-swift")]),
        .testTarget(name: "SessionPortTests", dependencies: ["LakeKit"]),
    ]
)
