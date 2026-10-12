// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AetherZipCore", platforms: [.macOS("26.0")],
  products: [.library(name: "AetherZipCore", targets: ["AetherZipCore"])],
  targets: [
    .target(name: "AetherZipCore", path: "Sources/Core"),
    .testTarget(
      name: "AetherZipCoreTests", dependencies: ["AetherZipCore"], path: "Tests",
      resources: [.copy("Fixtures")]),
  ])
