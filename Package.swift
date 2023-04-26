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
        .package(url: "https://github.com/lake-of-fire/AsyncView.git", branch: "main"),
        .package(url: "https://github.com/NuPlay/ExpandableText.git", branch: "main"),
//        .package(url: "https://github.com/lake-of-fire/swiftui-webview.git", branch: "main"),
        .package(path: "../swiftui-webview"),
        .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "7.3.2")),
        .package(url: "https://github.com/lake-of-fire/swift-url.git", branch: "main"),
//        .package(url: "https://github.com/demharusnam/SwiftUIDrag.git", branch: "main"),
        .package(path: "../SwiftUIDrag"),
        .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/BetterSafariView.git", branch: "main"),
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", branch: "master"),
        .package(url: "https://github.com/dagronf/DSFSearchField.git", branch: "main"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", branch: "master"),
        .package(url: "https://github.com/elai950/AlertToast.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/swiftui-layout-guides.git", branch: "main"),
//        .package(path: "../swiftui-layout-guides"),
        .package(url: "https://github.com/malcommac/SwiftDate.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-algorithms.git", branch: "main"),
//        .package(url: "https://github.com/exyte/Grid.git", branch: "master"),
//        .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
//        .package(url: "https://github.com/JiHoonAHN/XcodeSnippet.git", branch: "main"),
        .package(url: "https://github.com/russell-archer/StoreHelper", branch: "main"),
        .package(url: "https://github.com/ggruen/CloudKitSyncMonitor.git", branch: "main"),
        .package(url: "https://github.com/shaps80/SwiftUIBackports.git", branch: "main"),
//        .package(url: "https://github.com/ryanlintott/FrameUp.git", branch: "main"),
//        .package(url: "https://github.com/tevelee/SwiftUI-Flow.git", branch: "main"),
//        .package(path: "../SwiftUI-Flow"),
        .package(url: "https://github.com/CodeSlicing/pure-swift-ui.git", branch: "develop"),
//        .package(url: "https://github.com/danielsaidi/SwiftUIKit.git", branch: "master"),
        .package(url: "https://github.com/markrenaud/FilePicker.git", branch: "main"),
        .package(url: "https://github.com/f-meloni/SwiftBrotli.git", branch: "master"),
//        .package(url: "https://github.com/lake-of-fire/SwiftyMonaco", branch: "main"),
        .package(path: "../PagerTabStripView"),
        .package(path: "../navigation-stack-backport"),
        .package(path: "../VisionLiveText_SwiftUICompatible"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LakeKit",
            dependencies: [
                .product(name: "Realm", package: "realm-swift"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "AsyncView", package: "AsyncView"),
                .product(name: "SwiftUIWebView", package: "swiftui-webview"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "WebURLFoundationExtras", package: "swift-url"),
                .product(name: "SwiftUIDrag", package: "SwiftUIDrag"),
                .product(name: "Popovers", package: "Popovers"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "BetterSafariView", package: "BetterSafariView"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "DSFSearchField", package: "DSFSearchField"),
//                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Introspect", package: "SwiftUI-Introspect"),
                .product(name: "BigSyncKit", package: "BigSyncKit"),
                .product(name: "AlertToast", package: "AlertToast"),
                .product(name: "SwiftUILayoutGuides", package: "swiftui-layout-guides"),
                .product(name: "SwiftDate", package: "SwiftDate"),
                .product(name: "Algorithms", package: "swift-algorithms"),
//                .product(name: "ExyteGrid", package: "Grid"),
//                .product(name: "XcodeSnippet", package: "XcodeSnippet"),
                .product(name: "StoreHelper", package: "StoreHelper"),
                .product(name: "CloudKitSyncMonitor", package: "CloudKitSyncMonitor"),
                .product(name: "SwiftUIBackports", package: "SwiftUIBackports"),
//                .product(name: "FrameUp", package: "FrameUp"),
//                .product(name: "Flow", package: "SwiftUI-Flow"),
                .product(name: "PureSwiftUI", package: "pure-swift-ui"),
//                .product(name: "SwiftUIKit", package: "SwiftUIKit"),
                .product(name: "PagerTabStripView", package: "PagerTabStripView"),
                .product(name: "NavigationStackBackport", package: "navigation-stack-backport"),
                .product(name: "VisionLiveText_SwiftUICompatible", package: "VisionLiveText_SwiftUICompatible"),
                .product(name: "FilePicker", package: "FilePicker"),
                .product(name: "SwiftBrotli", package: "SwiftBrotli"), // Only needed for iOS 15 Brotli (somehow missing in simulator at least)
//                .product(name: "SwiftyMonaco", package: "SwiftyMonaco"),
            ]
        ),
        .testTarget(
            name: "LakeKitTests",
            dependencies: ["LakeKit"]),
    ]
)
