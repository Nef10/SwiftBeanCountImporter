// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "SwiftBeanCountImporter",
    platforms: [.iOS(.v16), .macOS(.v11)],
    products: [
        .library(
            name: "SwiftBeanCountImporter",
            targets: ["SwiftBeanCountImporter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Nef10/SwiftBeanCountModel.git", exact: "0.1.6"),
        .package(url: "https://github.com/yaslab/CSV.swift.git", from: "2.4.3"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git", from: "1.0.0"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper.git", from: "1.7.0"),
        .package(url: "https://github.com/Nef10/WealthsimpleDownloader.git", from: "2.0.2"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountSheetSync.git", from: "1.1.0"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountRogersBankMapper.git", exact: "0.0.14"),
        .package(url: "https://github.com/Nef10/RogersBankDownloader.git", exact: "0.2.2"),
        .package(url: "https://github.com/Nef10/TangerineDownloader.git", exact: "0.0.3"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountTangerineMapper.git", exact: "0.0.3"),
        .package(url: "https://github.com/Nef10/CompassCardDownloader.git", exact: "0.0.1"),
        .package(url: "https://github.com/Nef10/SwiftBeanCountCompassCardMapper.git", exact: "0.1.1"),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountImporter",
            dependencies: [
                .product(name: "CSV", package: "CSV.swift"),
                "RogersBankDownloader",
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountRogersBankMapper",
                "SwiftBeanCountWealthsimpleMapper",
                "SwiftBeanCountCompassCardMapper",
                .product(name: "CompassCardDownloader", package: "CompassCardDownloader", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "TangerineDownloader", package: "TangerineDownloader", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "SwiftBeanCountTangerineMapper", package: "SwiftBeanCountTangerineMapper", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "SwiftBeanCountSheetSync", package: "SwiftBeanCountSheetSync", condition: .when(platforms: [.macOS])),
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader"),
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"]
        ),
    ],
    swiftLanguageModes: [.v5],
)
