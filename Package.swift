// swift-tools-version: 6.0
import PackageDescription

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
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("EventKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Speech"),
                .linkedFramework("Vision"),
                .linkedFramework("ShazamKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("Network"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
