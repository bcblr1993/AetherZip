import AetherZipCore
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Represents an item inside an archive that can be dragged directly out to Finder or other apps.
/// When the user drops the item, `FileRepresentation` extracts it on-demand into a temporary
/// transfer staging folder and supplies the resulting file to macOS.
struct ArchiveItemExport: Transferable, Sendable {
  let archive: URL
  let entryPath: String
  let password: String
  let executable: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .item) { export in
      let tempParent = FileManager.default.temporaryDirectory
      let staging = tempParent.appendingPathComponent(
        ".aetherzip-drag-" + UUID().uuidString, isDirectory: true)
      let engine = ArchiveEngine(executable: export.executable)
      _ = try engine.extract(
        export.archive, to: staging, password: export.password, selected: [export.entryPath])
      let direct = staging.appendingPathComponent(export.entryPath)
      if FileManager.default.fileExists(atPath: direct.path) {
        return SentTransferredFile(direct)
      }
      let subpaths = (try? FileManager.default.subpathsOfDirectory(atPath: staging.path)) ?? []
      if let match = subpaths.first(where: {
        $0.hasSuffix(URL(fileURLWithPath: export.entryPath).lastPathComponent)
      }) {
        return SentTransferredFile(staging.appendingPathComponent(match))
      }
      return SentTransferredFile(staging)
    }
  }
}
