// Compile with Sources/Core/*.swift; runs the same engine used by the app, including staging and verification.
import Foundation

@main struct Benchmark {
  static func emit(_ fields: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) {
      FileHandle.standardOutput.write(data + Data([10]))
    }
  }
  static func main() throws {
    let args = CommandLine.arguments
    guard args.count == 6 else { fatalError("benchmark operation engine input output format") }
    let engine = ArchiveEngine(executable: URL(fileURLWithPath: args[2]))
    let input = URL(fileURLWithPath: args[3])
    let output = URL(fileURLWithPath: args[4])
    var options = ArchiveOptions()
    let encrypted = args[5].hasSuffix("-aes")
    options.format = ArchiveFormat(rawValue: args[5].replacingOccurrences(of: "-aes", with: ""))!
    if encrypted { options.password = "AetherZip-large-fixture-only-2026!" }
    let start = ProcessInfo.processInfo.systemUptime
    let progress: @Sendable (ArchiveProgress) -> Void = { value in
      emit(["event": "progress", "seconds": ProcessInfo.processInfo.systemUptime - start,
        "stage": value.stage, "fraction": value.fraction ?? -1])
    }
    do {
      switch args[1] {
      case "create":
        _ = try engine.create(sources: [input], destination: output, options: options, progress: progress)
      case "extract":
        _ = try engine.extract(input, to: output, password: options.password, progress: progress)
      case "list":
        let entries = try engine.list(input, password: options.password)
        emit(["event": "listing", "entries": entries.count, "bytes": ArchiveSafety.totalKnownSize(entries)])
      default: fatalError("Unknown operation")
      }
      emit(["event": "complete", "seconds": ProcessInfo.processInfo.systemUptime - start])
    } catch {
      emit(["event": "failure", "seconds": ProcessInfo.processInfo.systemUptime - start,
        "error": error.localizedDescription])
      throw error
    }
  }
}
