// swift-tools-version: 5.9
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
//        .package(url: "https://github.com/lake-of-fire/RealmBinary.git", branch: "main"),
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.52.1"),
//        .package(path: "../BigSyncKit"),
        .package(url: "https://github.com/lake-of-fire/BigSyncKit.git", branch: "main"),
//        .package(path: "../RealmSwiftGaps"),
        .package(url: "https://github.com/lake-of-fire/RealmSwiftGaps.git", branch: "main"),
//        .package(path: "../SwiftUIDownloads"),
        .package(url: "https://github.com/lake-of-fire/SwiftUIDownloads.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/SwiftUtilities.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/LakeImage.git", branch: "main"),
//        .package(path: "../SwiftUtilities"),
//        .package(path: "../LakeImage"),
//        .package(url: "https://github.com/NuPlay/ExpandableText.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/swiftui-webview.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/swift-url.git", branch: "main"),
        .package(url: "https://github.com/tomdai/markdown-webview.git", branch: "main"),
//        .package(url: "https://github.com/demharusnam/SwiftUIDrag.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/SwiftUIDrag.git", branch: "main"),
//        .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/Popovers.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/BetterSafariView2.git", branch: "main"),
        .package(url: "https://github.com/objecthub/swift-markdownkit.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/keychain-swift.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/DSFSearchField.git", branch: "main"),
//        .package(url: "https://github.com/twostraws/Inferno.git", branch: "main"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", branch: "main"),
//        .package(url: "https://github.com/elai950/AlertToast.git", branch: "master"),
        .package(url: "https://github.com/exyte/PopupView.git", branch: "master"),
//        .package(url: "https://github.com/lake-of-fire/swiftui-layout-guides.git", branch: "main"),
        .package(url: "https://github.com/malcommac/SwiftDate.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-algorithms.git", branch: "main"),
//        .package(url: "https://github.com/exyte/Grid.git", branch: "master"),
//        .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
//        .package(url: "https://github.com/JiHoonAHN/XcodeSnippet.git", branch: "main"),
//        .package(url: "https://github.com/russell-archer/StoreHelper", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/StoreHelper", branch: "main"),
        .package(url: "https://github.com/shaps80/SwiftUIBackports.git", branch: "main"),
//        .package(url: "https://github.com/ryanlintott/FrameUp.git", branch: "main"),
//        .package(url: "https://github.com/tevelee/SwiftUI-Flow.git", branch: "main"),
//        .package(path: "../SwiftUI-Flow"),
//        .package(url: "https://github.com/danielsaidi/SwiftUIKit.git", branch: "master"),
        .package(url: "https://github.com/lake-of-fire/FilePicker.git", branch: "main"),
        .package(url: "https://github.com/nicklockwood/LRUCache.git", branch: "main"),
//        .package(url: "https://github.com/kean/Pulse.git", branch: "main"),
        .package(url: "https://github.com/stevengharris/SplitView.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/VisionLiveText_SwiftUICompatible.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", branch: "main"),
        .package(url: "https://github.com/Tunous/DebouncedOnChange.git", branch: "main"),
        .package(url: "https://github.com/sushichop/Puppy.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/CloudKitSyncMonitor.git", branch: "main"),
        .package(url: "https://github.com/johnpatrickmorgan/NavigationBackport.git", branch: "main"),
        //        .package(path: "../FramedScreenshotsTool"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LakeKit",
            dependencies: [
                .product(name: "SwiftUIWebView", package: "swiftui-webview"),
//                .product(name: "Realm", package: "RealmBinary"),
//                .product(name: "RealmSwift", package: "RealmBinary"),
//                .product(name: "Realm", package: "realm-swift"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "RealmSwiftGaps", package: "RealmSwiftGaps"),
                .product(name: "WebURL", package: "swift-url"),
                .product(name: "WebURLFoundationExtras", package: "swift-url"),
                .product(name: "SwiftUIDrag", package: "SwiftUIDrag"),
                .product(name: "Popovers", package: "Popovers"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "MarkdownKit", package: "Swift-MarkdownKit"),
                .product(name: "DebouncedOnChange", package: "DebouncedOnChange"),
                .product(name: "BetterSafariView", package: "BetterSafariView2"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "DSFSearchField", package: "DSFSearchField"),
//                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "BigSyncKit", package: "BigSyncKit"),
                .product(name: "PopupView", package: "PopupView"),
                .product(name: "SwiftDate", package: "SwiftDate"),
                .product(name: "Algorithms", package: "swift-algorithms"),
//                .product(name: "ExyteGrid", package: "Grid"),
//                .product(name: "XcodeSnippet", package: "XcodeSnippet"),
                .product(name: "StoreHelper", package: "StoreHelper"),
                .product(name: "SwiftUIBackports", package: "SwiftUIBackports"),
//                .product(name: "FrameUp", package: "FrameUp"),
//                .product(name: "Flow", package: "SwiftUI-Flow"),
                //                .product(name: "SwiftUIKit", package: "SwiftUIKit"),
                .product(name: "VisionLiveText_SwiftUICompatible", package: "VisionLiveText_SwiftUICompatible"),
                .product(name: "FilePicker", package: "FilePicker"),
                .product(name: "SwiftUIDownloads", package: "SwiftUIDownloads"),
                .product(name: "LRUCache", package: "LRUCache"),
//                .product(name: "Pulse", package: "Pulse"),
//                .product(name: "PulseUI", package: "Pulse"),
                .product(name: "SwiftUtilities", package: "SwiftUtilities"),
                .product(name: "SplitView", package: "SplitView"),
                .product(name: "LakeImage", package: "LakeImage"),
                .product(name: "MarkdownWebView", package: "markdown-webview"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Puppy", package: "Puppy"),
//                .product(name: "Inferno", package: "Inferno"),
                .product(name: "CloudKitSyncMonitor", package: "CloudKitSyncMonitor"),
                .product(name: "NavigationBackport", package: "NavigationBackport"),
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
