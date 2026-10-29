// swift-tools-version: 6.0
import PackageDescription

// build.sh is the supported build: it also compiles the Now Playing bridge and assembles Mochy.app.
let package = Package(
    name: "Mochy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mochy", targets: ["Mochy"]),
    ],
    targets: [
        .executableTarget(
            name: "Mochy",
            path: "Sources/Mochy",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                "AppKit", "SwiftUI", "EventKit", "AVFoundation", "IOKit", "CoreLocation", "Network",
                "UniformTypeIdentifiers", "Combine", "CoreAudio", "AudioToolbox", "QuickLookThumbnailing",
                "ServiceManagement", "Carbon", "CoreImage",
            ].map { .linkedFramework($0) }
        ),
    ]
)
