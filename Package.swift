// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TransFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TransFloat",
            path: "Sources/TransFloat",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/TransFloat/Info.plist"])
            ]
        )
    ]
)
