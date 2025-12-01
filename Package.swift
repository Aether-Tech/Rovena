// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VeroChat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Rovena", targets: ["VeroChat"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "VeroChat",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            resources: [
                .process("App/GoogleService-Info.plist"),
                .process("Config.plist"),
                .process("Documents/TermsAndConditions.md")
            ]
        )
    ]
)
