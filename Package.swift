// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginKeyboardCleaner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PluginKeyboardCleaner",
            targets: ["PluginKeyboardCleaner"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0")
    ],
    targets: [
        .target(
            name: "PluginKeyboardCleaner",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources/PluginKeyboardCleaner",
            resources: [.process("../../Resources/KeyboardCleaner.xcstrings")]
        ),
        .testTarget(
            name: "PluginKeyboardCleanerTests",
            dependencies: [
                "PluginKeyboardCleaner",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders")
            ],
            path: "Tests/PluginKeyboardCleanerTests"
        )
    ]
)