// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeReviewBot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "codereview-bot", targets: ["CodeReviewBot"])
    ],
    dependencies: [
            // SwiftSyntax for parsing Swift source (pinned to a matching Swift toolchain version)
            .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
        ],
    targets: [
        .executableTarget(
            name: "CodeReviewBot",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            resources: [
                .copy("./../../Resources/code-review.yml")
            ]
        )
    ]
)
