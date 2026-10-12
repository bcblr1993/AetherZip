import XCTest

@testable import AetherZipCore

final class ArchiveEngineTests: XCTestCase {
  var root: URL!
  var engine: ArchiveEngine!
  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "AetherZipTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    let checkout = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
    engine = ArchiveEngine(executable: checkout.appendingPathComponent("Resources/7zz"))
  }
  override func tearDownWithError() throws {
    if let root { try FileManager.default.removeItem(at: root) }
  }
  func sample() throws -> URL {
    let folder = root.appendingPathComponent("中文资料 📦")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    try Data("hello\n中文保留\n".utf8).write(to: folder.appendingPathComponent("hello.txt"))
    try Data("hidden real data".utf8).write(to: folder.appendingPathComponent(".env"))
    try Data("finder".utf8).write(to: folder.appendingPathComponent(".DS_Store"))
    try Data([0, 5, 22, 7, 0, 0, 0, 0]).write(to: folder.appendingPathComponent("._hello.txt"))
    try Data("real file".utf8).write(to: folder.appendingPathComponent("._real.txt"))
    return folder
  }
  func testAllWritableFormatsRoundTrip() throws {
    let source = try sample()
    for format in ArchiveFormat.allCases {
      var options = ArchiveOptions()
      options.format = format
      let archive = root.appendingPathComponent("sample." + format.rawValue)
      _ = try engine.create(sources: [source], destination: archive, options: options)
      let entries = try engine.list(archive)
      XCTAssertTrue(
        entries.contains { $0.path == source.lastPathComponent + "/hello.txt" },
        "Browser must list logical contents of " + format.rawValue)
      let chosen = root.appendingPathComponent("chosen-" + format.rawValue)
      _ = try engine.extract(
        archive, to: chosen, selected: [source.lastPathComponent + "/hello.txt"])
      XCTAssertTrue(
        FileManager.default.fileExists(
          atPath: chosen.appendingPathComponent(source.lastPathComponent + "/hello.txt").path))
      XCTAssertFalse(
        FileManager.default.fileExists(
          atPath: chosen.appendingPathComponent(source.lastPathComponent + "/.env").path))
      let extracted = root.appendingPathComponent("extracted-" + format.rawValue)
      _ = try engine.extract(archive, to: extracted)
      let result = extracted.appendingPathComponent(source.lastPathComponent)
      XCTAssertEqual(
        try Data(contentsOf: result.appendingPathComponent("hello.txt")),
        try Data(contentsOf: source.appendingPathComponent("hello.txt")), format.rawValue)
      XCTAssertTrue(
        FileManager.default.fileExists(atPath: result.appendingPathComponent(".env").path))
      XCTAssertTrue(
        FileManager.default.fileExists(atPath: result.appendingPathComponent("._real.txt").path))
      XCTAssertFalse(
        FileManager.default.fileExists(atPath: result.appendingPathComponent(".DS_Store").path))
      XCTAssertFalse(
        FileManager.default.fileExists(atPath: result.appendingPathComponent("._hello.txt").path))
      XCTAssertTrue(
        FileManager.default.fileExists(atPath: source.appendingPathComponent(".DS_Store").path))
    }
  }
  func testEncryptedZIPAnd7z() throws {
    let source = try sample()
    for format in [ArchiveFormat.zip, .sevenZip] {
      var options = ArchiveOptions()
      options.format = format
      options.password = format == .zip ? "Demo-2026!" : "测试-Demo-2026!"
      options.hideNames = true
      let archive = root.appendingPathComponent("encrypted." + format.rawValue)
      _ = try engine.create(sources: [source], destination: archive, options: options)
      XCTAssertThrowsError(try engine.test(archive, password: "wrong"))
      try engine.test(archive, password: options.password)
      if format == .sevenZip { XCTAssertThrowsError(try engine.list(archive)) }
      let output = root.appendingPathComponent("decrypt-" + format.rawValue)
      _ = try engine.extract(archive, to: output, password: options.password)
      XCTAssertEqual(
        try Data(
          contentsOf: output.appendingPathComponent(source.lastPathComponent)
            .appendingPathComponent("hello.txt")),
        try Data(contentsOf: source.appendingPathComponent("hello.txt")))
    }
  }
  func testNoOverwriteAndCancellation() throws {
    let source = try sample()
    let target = root.appendingPathComponent("existing.zip")
    try Data("keep me".utf8).write(to: target)
    XCTAssertThrowsError(
      try engine.create(sources: [source], destination: target, options: ArchiveOptions()))
    XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "keep me")
    let control = OperationControl()
    control.cancel()
    XCTAssertThrowsError(
      try engine.create(
        sources: [source], destination: root.appendingPathComponent("cancelled.zip"),
        options: ArchiveOptions(), control: control))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("cancelled.zip").path))
  }
  func testPathTraversalRejected() throws {
    for path in [
      "../escape", "/etc/file", "C:\\Windows\\file", "a/../../file", "a\nPath = injected",
    ] { XCTAssertThrowsError(try ArchiveSafety.validate(path: path)) }
    let malicious = root.appendingPathComponent("unsafe.zip")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [
      "-c",
      "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w'); z.writestr('../escape.txt','bad'); z.close()",
      malicious.path,
    ]
    try process.run()
    process.waitUntilExit()
    XCTAssertThrowsError(
      try engine.extract(malicious, to: root.appendingPathComponent("unsafe-output")))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("escape.txt").path))
  }
  func testSelectedExtraction() throws {
    let source = try sample()
    let archive = root.appendingPathComponent("select.zip")
    _ = try engine.create(sources: [source], destination: archive, options: ArchiveOptions())
    let out = root.appendingPathComponent("selection")
    _ = try engine.extract(archive, to: out, selected: [source.lastPathComponent + "/hello.txt"])
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: out.appendingPathComponent(source.lastPathComponent + "/hello.txt").path))
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: out.appendingPathComponent(source.lastPathComponent + "/.env").path))
  }
  func testRARAndRAR5Fixtures() throws {
    for (name, file, bytes) in [
      ("test_read_format_rar", "test.txt", 20),
      ("test_read_format_rar5_stored", "helloworld.txt", 29),
    ] {
      let archive = Bundle.module.url(
        forResource: name, withExtension: "rar", subdirectory: "Fixtures")!
      let entries = try engine.list(archive)
      XCTAssertTrue(entries.contains { $0.path == file })
      let out = root.appendingPathComponent(name)
      _ = try engine.extract(archive, to: out)
      XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent(file)).count, bytes)
    }
    for name in ["test_read_format_rar4_encrypted", "test_read_format_rar5_encrypted"] {
      let archive = Bundle.module.url(
        forResource: name, withExtension: "rar", subdirectory: "Fixtures")!
      let out = root.appendingPathComponent(name)
      _ = try engine.extract(archive, to: out, password: "password", selected: ["b.txt"])
      XCTAssertTrue(
        try String(contentsOf: out.appendingPathComponent("b.txt"), encoding: .utf8).hasPrefix(
          "This is from b.txt"))
    }
  }
  func testVolumesAndLiteralSelection() throws {
    let input = root.appendingPathComponent("payload.bin")
    let bytes = Data((0..<(2 * 1024 * 1024 + 512)).map { UInt8(truncatingIfNeeded: $0) })
    try bytes.write(to: input)
    var options = ArchiveOptions()
    options.format = .sevenZip
    options.level = 0
    options.volumeMiB = 1
    let folder = try engine.create(
      sources: [input], destination: root.appendingPathComponent("split.7z"), options: options)
    let volumes = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil
    ).sorted { $0.path < $1.path }
    XCTAssertEqual(volumes.count, 3)
    let out = root.appendingPathComponent("joined")
    _ = try engine.extract(volumes[0], to: out)
    XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent(input.lastPathComponent)), bytes)
    let wildcard = root.appendingPathComponent("a*.txt")
    let other = root.appendingPathComponent("ab.txt")
    try Data("selected".utf8).write(to: wildcard)
    try Data("excluded".utf8).write(to: other)
    let zip = root.appendingPathComponent("wildcard.zip")
    _ = try engine.create(sources: [wildcard, other], destination: zip, options: ArchiveOptions())
    let selection = root.appendingPathComponent("literal")
    _ = try engine.extract(zip, to: selection, selected: ["a*.txt"])
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: selection.appendingPathComponent("a*.txt").path))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: selection.appendingPathComponent("ab.txt").path))
  }
  func testSafeAndEscapingSymlinks() throws {
    let source = try sample()
    try FileManager.default.createSymbolicLink(
      atPath: source.appendingPathComponent("link").path, withDestinationPath: "hello.txt")
    let archive = root.appendingPathComponent("links.tar")
    var options = ArchiveOptions()
    options.format = .tar
    _ = try engine.create(sources: [source], destination: archive, options: options)
    let out = root.appendingPathComponent("links")
    _ = try engine.extract(archive, to: out)
    XCTAssertEqual(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: out.appendingPathComponent(source.lastPathComponent + "/link").path), "hello.txt")
    let malicious = root.appendingPathComponent("escape.tar")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = [
      "-c",
      "import tarfile,sys; t=tarfile.open(sys.argv[1],'w'); x=tarfile.TarInfo('outside'); x.type=tarfile.SYMTYPE; x.linkname='../outside'; t.addfile(x); t.close()",
      malicious.path,
    ]
    try process.run()
    process.waitUntilExit()
    XCTAssertThrowsError(try engine.extract(malicious, to: root.appendingPathComponent("rejected")))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: root.appendingPathComponent("rejected").path))
  }

  func testStandaloneStreamsAndEmptyZIP() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-c", """
      import sys,pathlib,gzip,lzma,bz2,zipfile
      root=pathlib.Path(sys.argv[1]); data=b'AetherZip standalone stream'+bytes([10])
      for ext,encode in [('gz',gzip.compress),('xz',lzma.compress),('bz2',bz2.compress)]:
        (root/('plain.txt.'+ext)).write_bytes(encode(data))
      zipfile.ZipFile(root/'empty.zip','w').close()
      """, root.path]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    for ext in ["gz", "xz", "bz2"] {
      let archive = root.appendingPathComponent("plain.txt." + ext)
      XCTAssertEqual(try engine.list(archive).map(\.path), ["plain.txt"])
      let output = root.appendingPathComponent("stream-" + ext)
      _ = try engine.extract(archive, to: output, selected: ["plain.txt"])
      XCTAssertEqual(try String(contentsOf: output.appendingPathComponent("plain.txt"), encoding: .utf8),
        "AetherZip standalone stream\n")
    }
    let empty = root.appendingPathComponent("empty.zip")
    XCTAssertTrue(try engine.list(empty).isEmpty)
    let output = root.appendingPathComponent("empty-output")
    _ = try engine.extract(empty, to: output)
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: output.path).isEmpty)
  }

  func testZstandardPlainAndTAR() throws {
    for (name, item) in [("stream.payload", "stream.payload"), ("stream.tar", "nested/hello.txt")] {
      let archive = Bundle.module.url(forResource: name, withExtension: "zst", subdirectory: "Fixtures")!
      XCTAssertEqual(try engine.list(archive).map(\.path), [item])
      let output = root.appendingPathComponent(name)
      _ = try engine.extract(archive, to: output, selected: [item])
      XCTAssertEqual(try String(contentsOf: output.appendingPathComponent(item), encoding: .utf8),
        "AetherZip stream fixture\n中文解压验证\n")
    }
  }

}
