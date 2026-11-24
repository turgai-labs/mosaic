// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Mosaic",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "Mosaic", targets: ["Mosaic"]),
        .library(name: "MosaicHTML", targets: ["MosaicHTML"]),
        .library(name: "MosaicSwiftUI", targets: ["MosaicSwiftUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.9.0")
    ],
    targets: [
        // A widget as values: the pieces, their styles, and what makes one whole. No dependencies.
        .target(name: "Mosaic"),
        // A widget as an HTML page, kept live in the browser.
        .target(
            name: "MosaicHTML",
            dependencies: ["Mosaic", .product(name: "Elementary", package: "elementary")]
        ),
        // A widget drawn with SwiftUI, on the platforms that have it.
        .target(name: "MosaicSwiftUI", dependencies: ["Mosaic"]),
        .testTarget(name: "MosaicTests", dependencies: ["Mosaic"]),
        .testTarget(name: "MosaicSwiftUITests", dependencies: ["Mosaic", "MosaicSwiftUI"]),
        .testTarget(
            name: "MosaicHTMLTests",
            dependencies: ["Mosaic", "MosaicHTML", .product(name: "Elementary", package: "elementary")]
        ),
    ]
)

// Swift 7's language, ahead of it.
for target in package.targets {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("ImmutableWeakCaptures"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        ]
}
