// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DownloadOne",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DownloadOne",
            path: "Sources"
        )
    ]
)
