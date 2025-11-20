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
    targets: [
        .executableTarget(
            name: "VeroChat",
            path: "Sources"
        )
    ]
)
