// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TouchBarLyrics",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TouchBarLyrics", targets: ["TouchBarLyricsApp"])
    ],
    targets: [
        .target(
            name: "TouchBarLyricsCore"
        ),
        .target(
            name: "TouchBarPrivateBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "DFRFoundation"
                ])
            ]
        ),
        .executableTarget(
            name: "TouchBarLyricsApp",
            dependencies: ["TouchBarLyricsCore", "TouchBarPrivateBridge"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "DFRFoundation"
                ])
            ]
        ),
        .testTarget(
            name: "TouchBarLyricsCoreTests",
            dependencies: ["TouchBarLyricsCore"]
        ),
        .testTarget(
            name: "TouchBarLyricsAppTests",
            dependencies: ["TouchBarLyricsApp"]
        )
    ]
)
