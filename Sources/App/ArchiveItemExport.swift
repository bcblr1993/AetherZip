import AetherZipCore
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ArchiveItemExport: Transferable, Sendable {
  let provideFile: @Sendable () async throws -> URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .item) { export in
      SentTransferredFile(try await export.provideFile(), allowAccessingOriginalFile: false)
    }
  }
}

/// File promises can be resolved while AppKit blocks the main thread, including at quit.
/// All mutable state is protected by the lock; extraction never hops to MainActor.
final class ArchiveExportStore: @unchecked Sendable {
  private let lock = NSLock()
  private var controls: [UUID: OperationControl] = [:]
  private var directories: Set<URL> = []
  private var terminating = false
  private var completion: (@Sendable () -> Void)?

  var isActive: Bool { lock.withLock { !controls.isEmpty } }

  func extract(engine: ArchiveEngine, archive: URL, entry: ArchiveEntry,
    password: String, encoding: ArchiveEncoding) throws -> URL {
    let id = UUID()
    let control = OperationControl()
    try lock.withLock {
      guard !terminating else { throw ArchiveFailure.cancelled }
      controls[id] = control
    }
    let staging = FileManager.default.temporaryDirectory.appendingPathComponent(
      ".aetherzip-drag-" + id.uuidString, isDirectory: true)
    var retained = false
    defer {
      let callback: (@Sendable () -> Void)? = lock.withLock {
        if retained && !terminating {
          directories.insert(staging)
        } else {
          try? FileManager.default.removeItem(at: staging)
        }
        controls.removeValue(forKey: id)
        guard terminating, controls.isEmpty else { return nil }
        let callback = completion
        completion = nil
        return callback
      }
      callback?()
    }
    _ = try engine.extract(archive, to: staging, password: password,
      selected: [entry.path], encoding: encoding, control: control)
    try control.check()
    let file = staging.appendingPathComponent(entry.path)
    guard FileManager.default.fileExists(atPath: file.path) else {
      throw ArchiveFailure.invalid("未找到要导出的归档条目。")
    }
    retained = true
    return file
  }

  /// Returns true when in-flight work must finish before termination can proceed.
  func prepareToTerminate(completion: @escaping @Sendable () -> Void) -> Bool {
    lock.withLock {
      terminating = true
      for control in controls.values { control.cancel() }
      for directory in directories { try? FileManager.default.removeItem(at: directory) }
      directories.removeAll()
      guard !controls.isEmpty else { return false }
      self.completion = completion
      return true
    }
  }
}
