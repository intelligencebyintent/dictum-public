// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MurmurKit",
    platforms: [
        // The Kit is UI-framework-free and only uses APIs available on macOS 15+.
        // The app target enforces the real 26.0 floor (Liquid Glass lives there).
        .macOS(.v15),
    ],
    products: [
        .library(name: "MurmurKit", targets: ["MurmurKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "MurmurKit",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "MurmurKitTests",
            dependencies: ["MurmurKit"]
        ),
    ]
)
