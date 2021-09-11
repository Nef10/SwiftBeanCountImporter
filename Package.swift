// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountImporter",
    platforms: [
       .macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftBeanCountImporter",
            targets: ["SwiftBeanCountImporter"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/yaslab/CSV.swift.git",
            .upToNextMinor(from: "2.4.3")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            .exact("0.0.1")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper.git",
            .upToNextMajor(from: "1.2.4")
        ),
        .package(
            url: "https://github.com/Nef10/WealthsimpleDownloader.git",
            .upToNextMajor(from: "1.0.7")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountImporter",
            dependencies: [
                "SwiftBeanCountModel",
                .product(name: "CSV", package: "CSV.swift"),
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountWealthsimpleMapper",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader"),
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"]
        ),
    ]
)
