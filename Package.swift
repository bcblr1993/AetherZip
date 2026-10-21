// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AetherZipCore", platforms: [.macOS("26.0")],
  products: [.library(name: "AetherZipCore", targets: ["AetherZipCore"])],
  targets: [
    .target(name: "AetherZipCore", path: "Sources/Core"),
    .testTarget(
      name: "AetherZipCoreTests", dependencies: ["AetherZipCore"], path: "Tests",
      exclude: ["App"],
      resources: [.copy("Fixtures")]),
    .target(name: "AetherZipAppLogic", dependencies: ["AetherZipCore"], path: "Sources/App",
      exclude: ["AetherZipApp.swift", "ComposeView.swift", "LaunchAtLogin.swift", "MainView.swift",
        "Theme.swift", "Updater.swift"], swiftSettings: [.define("APP_LOGIC_TESTING")]),
    .testTarget(name: "AetherZipAppLogicTests", dependencies: ["AetherZipAppLogic"], path: "Tests/App"),
  ])
