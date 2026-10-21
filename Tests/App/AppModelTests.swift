import AppKit
import XCTest
import AetherZipCore
@testable import AetherZipAppLogic

final class AppModelTests: XCTestCase {
  @MainActor
  func fixture() throws -> (URL, AppModel) {
    _ = NSApplication.shared
    for key in AppPreferences.defaults.dictionaryRepresentation().keys {
      AppPreferences.defaults.removeObject(forKey: key)
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("AetherZipModelTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let model = AppModel(executable: repo.appendingPathComponent("Resources/7zz"))
    model.revealAfterExtract = false
    return (root, model)
  }

  @MainActor
  func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
    for _ in 0..<500 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("Timed out waiting for archive operation")
  }

  @MainActor
  func makeArchive(_ model: AppModel, root: URL) throws -> URL {
    let source = root.appendingPathComponent("source.txt")
    try Data("model regression".utf8).write(to: source)
    let archive = root.appendingPathComponent("bundle.zip")
    _ = try model.engine.create(sources: [source], destination: archive, options: ArchiveOptions())
    return archive
  }

  @MainActor
  func testQueuedIdenticalOutputNamesRemainDistinct() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = try makeArchive(model, root: root)
    let output = root.appendingPathComponent("output")
    model.enqueue(.extract(archive, output, "", [], .auto, false))
    model.enqueue(.extract(archive, output, "", [], .auto, false))
    try await waitUntil { model.activeJobs == 0 }
    XCTAssertEqual(model.jobs.filter { $0.state == .completed }.count, 2)
    XCTAssertEqual(Set(model.jobs.compactMap(\.output)).count, 2)
    for job in model.jobs {
      let path = try XCTUnwrap(job.output).appendingPathComponent("source.txt")
      XCTAssertEqual(try Data(contentsOf: path), Data("model regression".utf8))
    }
  }

  @MainActor
  func testSelectedExtractionNeverTrashesSource() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = try makeArchive(model, root: root)
    let original = try Data(contentsOf: archive)
    model.trashAfterExtract = true
    model.enqueue(.extract(archive, root.appendingPathComponent("selection"), "", ["source.txt"], .auto, true))
    try await waitUntil { model.activeJobs == 0 }
    XCTAssertEqual(model.jobs.first?.state, .completed)
    XCTAssertEqual(try Data(contentsOf: archive), original)
  }

  @MainActor
  func testClosingWhileListingDoesNotRestoreOldEntries() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = try makeArchive(model, root: root)
    model.openArchive(archive)
    model.closeArchive()
    var terminated = false
    if !model.prepareToTerminate(completion: { terminated = true }) { terminated = true }
    try await waitUntil { terminated }
    XCTAssertNil(model.openedArchive)
    XCTAssertTrue(model.entries.isEmpty)
    XCTAssertFalse(model.isReading)
  }

  @MainActor
  func testQuitDuringPreviewFinishesAndRemovesTemporaryOutput() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = try makeArchive(model, root: root)
    model.openedArchive = archive
    model.previewEntry(ArchiveEntry(path: "source.txt", size: 16))
    var terminated = false
    XCTAssertTrue(model.prepareToTerminate { terminated = true })
    try await waitUntil { terminated }
    XCTAssertFalse(model.isPreviewing)
  }

  @MainActor
  func testDragExportSurvivesCloseAndCleansUpOnQuit() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = try makeArchive(model, root: root)
    model.openedArchive = archive
    let item = try XCTUnwrap(model.exportItem(for: ArchiveEntry(path: "source.txt", size: 16)))
    let output = try await item.provideFile()
    model.closeArchive()
    XCTAssertEqual(try Data(contentsOf: output), Data("model regression".utf8))
    XCTAssertFalse(model.prepareToTerminate {})
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
  }

  @MainActor
  func testFilePromiseResolvesWithoutMainActorAndRejectsAfterQuit() async throws {
    let (root, model) = try fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    model.openedArchive = try makeArchive(model, root: root)
    let item = try XCTUnwrap(model.exportItem(for: ArchiveEntry(path: "source.txt")))
    let finished = DispatchSemaphore(value: 0)
    let delivery = Task.detached {
      defer { finished.signal() }
      return try await item.provideFile()
    }
    // AppKit may synchronously resolve promises while the main actor is occupied.
    XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
    let output = try await delivery.value
    XCTAssertEqual(try Data(contentsOf: output), Data("model regression".utf8))
    XCTAssertFalse(model.prepareToTerminate {})
    do {
      _ = try await item.provideFile()
      XCTFail("A pending file promise must not start work after termination")
    } catch ArchiveFailure.cancelled {
      // Expected: no late file promise can outlive termination cleanup.
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
  }
}
