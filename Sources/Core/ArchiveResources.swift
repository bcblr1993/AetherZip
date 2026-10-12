import Foundation

/// Bound parallel work and dictionary sizes instead of scaling up to all host memory.
/// This is a working-set policy, not a hard RSS limit: foreign archives choose their own dictionaries.
public struct ArchiveResources: Sendable {
  public let compressionThreads: Int
  public let extractionThreads: Int

  public init(
    memoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
    processorCount: Int = ProcessInfo.processInfo.activeProcessorCount
  ) {
    compressionThreads = max(1, min(memoryBytes <= 8 * 1024 * 1024 * 1024 ? 2 : 4, processorCount))
    extractionThreads = max(1, min(2, processorCount))
  }

  func creationArguments(format: ArchiveFormat, level: Int) -> [String] {
    var arguments = ["-mmt=\(compressionThreads)"]
    // Keep fast mode's smaller dictionary. Ultra still searches harder and uses a larger dictionary.
    if level > 0 && (format == .sevenZip || format == .tarXz) {
      let dictionaryMiB = level == 1 ? 1 : (level == 9 ? 32 : 16)
      arguments.append(format == .sevenZip ? "-md=\(dictionaryMiB)m" : "-m0=LZMA2:d=\(dictionaryMiB)m")
    }
    return arguments
  }
}
