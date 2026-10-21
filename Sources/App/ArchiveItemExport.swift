import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The model owns extraction, cancellation and the lifetime of the exported file.
struct ArchiveItemExport: Transferable, Sendable {
  let provideFile: @Sendable () async throws -> URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .item) { export in
      SentTransferredFile(try await export.provideFile(), allowAccessingOriginalFile: false)
    }
  }
}
