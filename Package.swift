// swift-tools-version: 5.7
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
        .package(url: "https://github.com/kean/Nuke.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/swift-url.git", branch: "main"),
//        .package(url: "https://github.com/demharusnam/SwiftUIDrag.git", branch: "main"),
        .package(path: "../SwiftUIDrag"),
//        .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/Popovers.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/BetterSafariView.git", branch: "main"),
        .package(url: "https://github.com/objecthub/swift-markdownkit.git", branch: "master"),
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
//        .package(url: "https://github.com/russell-archer/StoreHelper", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/StoreHelper", branch: "main"),
        .package(url: "https://github.com/ggruen/CloudKitSyncMonitor.git", branch: "main"),
        .package(url: "https://github.com/shaps80/SwiftUIBackports.git", branch: "main"),
//        .package(url: "https://github.com/ryanlintott/FrameUp.git", branch: "main"),
//        .package(url: "https://github.com/tevelee/SwiftUI-Flow.git", branch: "main"),
//        .package(path: "../SwiftUI-Flow"),
        .package(url: "https://github.com/CodeSlicing/pure-swift-ui.git", branch: "develop"),
//        .package(url: "https://github.com/danielsaidi/SwiftUIKit.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/FilePicker.git", branch: "main"),
        .package(url: "https://github.com/L1MeN9Yu/Elva.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/SwiftyMonaco", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/TranslucentWindowStyle.git", branch: "main"),
        .package(url: "https://github.com/will-lumley/FaviconFinder.git", branch: "main"),
        .package(url: "https://github.com/nicklockwood/LRUCache.git", branch: "main"),
        .package(url: "https://github.com/Tunous/DebouncedOnChange.git", branch: "main"),
        .package(url: "https://github.com/satoshi-takano/OpenGraph.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", branch: "master"),
        .package(url: "https://github.com/nmdias/FeedKit.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/opml", branch: "master"),
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
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "WebURLFoundationExtras", package: "swift-url"),
                .product(name: "SwiftUIDrag", package: "SwiftUIDrag"),
                .product(name: "Popovers", package: "Popovers"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "MarkdownKit", package: "Swift-MarkdownKit"),
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
                .product(name: "SwiftSoup", package: "SwiftSoup"),
//                .product(name: "FrameUp", package: "FrameUp"),
//                .product(name: "Flow", package: "SwiftUI-Flow"),
                .product(name: "PureSwiftUI", package: "pure-swift-ui"),
                //                .product(name: "SwiftUIKit", package: "SwiftUIKit"),
                .product(name: "PagerTabStripView", package: "PagerTabStripView"),
                .product(name: "NavigationStackBackport", package: "navigation-stack-backport"),
                .product(name: "VisionLiveText_SwiftUICompatible", package: "VisionLiveText_SwiftUICompatible"),
                .product(name: "FilePicker", package: "FilePicker"),
                .product(name: "Brotli", package: "Elva"), // Only needed for iOS 15 Brotli (somehow missing in simulator at least)
                .product(name: "SwiftyMonaco", package: "SwiftyMonaco"),
                .product(name: "TranslucentWindowStyle", package: "TranslucentWindowStyle"),
                .product(name: "FaviconFinder", package: "FaviconFinder"),
                .product(name: "LRUCache", package: "LRUCache"),
                .product(name: "DebouncedOnChange", package: "DebouncedOnChange"),
                .product(name: "OpenGraph", package: "OpenGraph"),
                .product(name: "OPML", package: "OPML"),
                .product(name: "FeedKit", package: "FeedKit"),
            ],
            resources: [
//                .copy("Resources/CSS/Reader.css"),
//                .process("Resources/CSS/"),
//                .process("Resources/JS/"),
//                .copy("Resources/JS/Readability/"),
//                .copy("Resources/CSS/manabi_panel.css"),
//                .copy("Resources/CSS/manabi_readability.css"),
//                .copy("Resources/JS/manabi_panel.js"),
//                .copy("Resources/JS/manabi_reader.js"),
//                .copy("Resources/JS/popper.min.js"),
//                .copy("Resources/JS/tippy_css_loader.js"),
//                .copy("Resources/JS/tippy.umd.min.js"),
            ]
        ),
        .testTarget(
            name: "LakeKitTests",
            dependencies: ["LakeKit"]),
    ]
)
