import Foundation

@main struct InteropFixtures {
  static func main() throws {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let engine = ArchiveEngine(executable: URL(fileURLWithPath: CommandLine.arguments[2]))
    let fm = FileManager.default
    let source = root.appendingPathComponent("资料 📦")
    try fm.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("Hello Windows! 中文归档\n".utf8).write(to: source.appendingPathComponent("你好.txt"))
    try Data("keep-hidden".utf8).write(to: source.appendingPathComponent(".env"))
    try Data("real-data".utf8).write(to: source.appendingPathComponent("._real.txt"))
    try Data("Finder".utf8).write(to: source.appendingPathComponent(".DS_Store"))
    try Data([0, 5, 22, 7, 0, 0, 0, 0]).write(to: source.appendingPathComponent("._metadata"))
    var random = SystemRandomNumberGenerator()
    let words = (0..<262144).map { _ in UInt64.random(in: .min ... .max, using: &random) }
    try words.withUnsafeBytes { try Data($0).write(to: source.appendingPathComponent("random.bin")) }
    let archives = root.appendingPathComponent("archives")
    try fm.createDirectory(at: archives, withIntermediateDirectories: true)
    for name in ["plain.zip", "encrypted.zip", "encrypted.7z", "split.7z"] {
      var options = ArchiveOptions()
      options.format = name.hasSuffix("zip") ? .zip : .sevenZip
      if name != "plain.zip" { options.password = "AetherZip-large-fixture-only-2026!" }
      if name == "split.7z" { options.volumeMiB = 1 }
      _ = try engine.create(sources: [source], destination: archives.appendingPathComponent(name), options: options)
    }
    // Expected files are the public generated payload, without the Mac metadata deliberately inserted above.
    try fm.removeItem(at: source.appendingPathComponent(".DS_Store"))
    try fm.removeItem(at: source.appendingPathComponent("._metadata"))
    let expected = root.appendingPathComponent("expected")
    try fm.createDirectory(at: expected, withIntermediateDirectories: true)
    try fm.moveItem(at: source, to: expected.appendingPathComponent(source.lastPathComponent))
  }
}
