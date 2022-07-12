// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LakeKit",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LakeKit",
            targets: ["LakeKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.28.1"),
        .package(path: "../BigSyncKit"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "7.18.0"),
        .package(url: "https://github.com/lake-of-fire/AsyncView.git", branch: "main"),
        .package(url: "https://github.com/NuPlay/ExpandableText.git", branch: "main"),
//        .package(url: "https://github.com/lake-of-fire/swiftui-webview.git", branch: "main"),
        .package(path: "../swiftui-webview"),
        .package(url: "https://github.com/onevcat/Kingfisher", branch: "master"),
        .package(url: "https://github.com/karwa/swift-url.git", .upToNextMinor(from: "0.3.1")),
//        .package(url: "https://github.com/demharusnam/SwiftUIDrag.git", branch: "main"),
        .package(path: "../SwiftUIDrag"),
//        .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
        .package(path: "../Popovers"),
//        .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LakeKit",
            dependencies: [
                .product(name: "Realm", package: "realm-swift"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "AsyncView", package: "AsyncView"),
                .product(name: "SwiftUIWebView", package: "swiftui-webview"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "WebURLFoundationExtras", package: "swift-url"),
                .product(name: "SwiftUIDrag", package: "SwiftUIDrag"),
                .product(name: "Popovers", package: "Popovers"),
//                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "LakeKitTests",
            dependencies: ["LakeKit"]),
    ]
)
