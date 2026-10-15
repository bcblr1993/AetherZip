import Darwin
import Foundation

public struct ArchiveEngine: Sendable {
  public let executable: URL
  public let resources: ArchiveResources
  public init(executable: URL, resources: ArchiveResources = ArchiveResources()) {
    self.executable = executable
    self.resources = resources
  }
  private func execute(
    _ args: [String], password: String = "", directory: URL? = nil, writable: URL? = nil,
    control: OperationControl, progress: @escaping @Sendable (Double) -> Void = { _ in }
  ) throws -> String {
    let result = try ArchiveProcess.run(
      executable: executable, arguments: args, input: password + "\n", directory: directory,
      writableDirectory: writable, control: control, progress: progress)
    if result.status != 0 {
      let t = result.text.lowercased()
      if t.contains("wrong password") || t.contains("enter password")
        || t.contains("password is incorrect")
      {
        throw password.isEmpty ? ArchiveFailure.passwordRequired : ArchiveFailure.invalidPassword
      }
      if t.contains("no space") { throw ArchiveFailure.diskSpace }
      throw ArchiveFailure.engine(String(result.text.suffix(2400)))
    }
    return result.text
  }
  private static let filteredExtensions: Set<String> = [
    "gz", "gzip", "tgz", "xz", "txz", "bz2", "bzip2", "tbz", "tbz2", "zst", "tzst",
  ]

  public func list(
    _ archive: URL, password: String = "", encoding: ArchiveEncoding = .auto,
    control: OperationControl = OperationControl()
  ) throws -> [ArchiveEntry] {
    try withReadablePayload(archive, password: password, control: control) { payload in
      try rawList(payload, password: password, encoding: encoding, control: control)
    }
  }
  private func rawList(
    _ archive: URL, password: String, encoding: ArchiveEncoding = .auto,
    control: OperationControl
  ) throws -> [ArchiveEntry] {
    var args = ["l", "-slt", "-sccUTF-8"]
    if let cp = encoding.codePageArgument { args.append(cp) }
    args += ["--", archive.path]
    let text = try execute(args, password: password, control: control)
    let header = text.components(separatedBy: "----------\n").first ?? ""
    let unnamedStream = ["xz", "bzip2", "zstd", "lzma", "gzip"].contains {
      header.contains("\nType = " + $0 + "\n")
    }
    var fallback = archive.deletingPathExtension().lastPathComponent
    if ["txz", "tgz", "tbz", "tbz2", "tzst"].contains(archive.pathExtension.lowercased()) {
      fallback += ".tar"
    }
    return try ArchiveSafety.parseListing(text, defaultPath: unnamedStream ? fallback : nil)
  }
  /// A filtered TAR is one logical archive in the browser and for selected extraction.
  /// The outer stream is expanded into a private sandboxed directory, never beside the source.
  private func withReadablePayload<T>(
    _ archive: URL, password: String, parent: URL = FileManager.default.temporaryDirectory,
    control: OperationControl, body: (URL) throws -> T
  ) throws -> T {
    guard Self.filteredExtensions.contains(archive.pathExtension.lowercased()) else {
      return try body(archive)
    }
    let entries = try rawList(archive, password: password, control: control)
    let name = archive.lastPathComponent.lowercased()
    let expectsTar =
      name.contains(".tar.")
      || ["tgz", "txz", "tbz", "tbz2", "tzst"].contains(archive.pathExtension.lowercased())
    let namedTar =
      entries.count == 1
      && URL(fileURLWithPath: entries[0].path).pathExtension.lowercased() == "tar"
    guard expectsTar || namedTar else { return try body(archive) }
    guard entries.count <= 1 else { throw ArchiveFailure.invalid("压缩流包含多个项目，无法作为 TAR 归档打开。") }
    if let size = entries.first?.size,
      let capacity = try? parent.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey
      ]).volumeAvailableCapacityForImportantUsage,
      size > capacity
    {
      throw ArchiveFailure.diskSpace
    }
    let fm = FileManager.default
    let work = parent.appendingPathComponent(
      ".aetherzip-payload-" + UUID().uuidString, isDirectory: true)
    try fm.createDirectory(
      at: work, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? fm.removeItem(at: work) }
    _ = try execute(
      ["x", "-mmt=\(resources.extractionThreads)", "-y", "-bso0", "-o" + work.path, "--", archive.path],
      password: password, writable: work, control: control)
    try audit(work)
    let contents = try directoryItems(work)
    guard contents.count == 1, let payload = contents.first else {
      throw ArchiveFailure.invalid("无法读取压缩流中的 TAR 内容。")
    }
    let values = try payload.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw ArchiveFailure.unsafePath(payload.lastPathComponent)
    }
    try control.check()
    return try body(payload)
  }
  public func test(
    _ archive: URL, password: String = "", control: OperationControl = OperationControl()
  ) throws {
    _ = try execute(
      ["t", "-mmt=\(resources.extractionThreads)", "-bso0", "-bsp0", "--", archive.path], password: password, control: control)
  }
  public func create(
    sources: [URL], destination: URL, options: ArchiveOptions,
    control: OperationControl = OperationControl(),
    progress: @escaping @Sendable (ArchiveProgress) -> Void = { _ in }
  ) throws -> URL {
    guard !sources.isEmpty else { throw ArchiveFailure.invalid("请先选择文件或文件夹。") }
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw ArchiveFailure.outputExists
    }
    guard options.password.isEmpty || options.format.supportsEncryption else {
      throw ArchiveFailure.invalid("此格式不支持密码保护，请选择 ZIP 或 7z。")
    }
    guard options.format != .zip || options.password.unicodeScalars.allSatisfy({ $0.value < 128 })
    else { throw ArchiveFailure.invalid("ZIP AES 密码请使用英文、数字或符号。需要中文密码时请选择 7z。") }
    guard !options.password.contains("\n"), !options.password.contains("\r") else {
      throw ArchiveFailure.invalid("密码不能包含换行。")
    }
    guard [0, 1, 5, 9].contains(options.level), options.volumeMiB >= 0 else {
      throw ArchiveFailure.invalid("无效的压缩参数。")
    }
    guard options.volumeMiB == 0 || options.format == .sevenZip else {
      throw ArchiveFailure.invalid("当前分卷写入支持 7z。")
    }
    let fm = FileManager.default
    let work = destination.deletingLastPathComponent().appendingPathComponent(
      ".aetherzip-" + UUID().uuidString, isDirectory: true)
    try fm.createDirectory(
      at: work, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? fm.removeItem(at: work) }
    let staging = work.appendingPathComponent("input", isDirectory: true)
    let output = work.appendingPathComponent("output", isDirectory: true)
    try fm.createDirectory(at: staging, withIntermediateDirectories: false)
    try fm.createDirectory(at: output, withIntermediateDirectories: false)
    var names = Set<String>()
    progress(ArchiveProgress(nil, "扫描文件"))
    for source in sources {
      try control.check()
      let name = source.lastPathComponent
      guard names.insert(name.lowercased()).inserted else {
        throw ArchiveFailure.invalid("不同目录中有同名项目，请分别压缩或先整理文件名。")
      }
      try ArchiveSafety.validate(path: name)
      try stage(
        source, to: staging.appendingPathComponent(name), clean: options.cleanMetadata,
        control: control)
    }
    let outputURL = output.appendingPathComponent(destination.lastPathComponent)
    let first =
      options.format.filter == nil ? outputURL : work.appendingPathComponent("payload.tar")
    var args = [
      "a", "-t" + options.format.engineType, "-mx=\(options.level)",
      "-snl", "-bsp1", "-bso1",
      "-sccUTF-8",
    ]
    args += resources.creationArguments(
      format: options.format.filter == nil ? options.format : .tar, level: options.level)
    if !options.password.isEmpty {
      args.append("-p")
      if options.format == .sevenZip {
        args.append("-mhe=" + (options.hideNames ? "on" : "off"))
      } else {
        args.append("-mem=AES256")
      }
    }
    if options.volumeMiB > 0 { args.append("-v\(options.volumeMiB)m") }
    args += ["--", first.path, "."]
    _ = try execute(
      args, password: options.password, directory: staging, control: control,
      progress: {
        progress(
          ArchiveProgress(
            $0 * (options.format.filter == nil ? 0.85 : 0.6),
            options.password.isEmpty ? "压缩文件" : "压缩并加密"))
      })
    if let filter = options.format.filter {
      _ = try execute(
        ["a", "-t" + filter, "-mx=\(options.level)", "-bsp1"]
          + resources.creationArguments(format: options.format, level: options.level)
          + ["--", outputURL.path, first.path],
        control: control, progress: { progress(ArchiveProgress(0.6 + $0 * 0.25, "压缩归档")) })
    }
    let generated = try fm.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).sorted {
      $0.path < $1.path
    }
    guard let testURL = generated.first else { throw ArchiveFailure.invalid("引擎没有生成归档。") }
    progress(ArchiveProgress(0.9, "校验归档"))
    try test(testURL, password: options.password, control: control)
    try control.check()
    if options.volumeMiB > 0 {
      let volumeFolder = destination.deletingPathExtension().appendingPathExtension("volumes")
      guard !fm.fileExists(atPath: volumeFolder.path) else { throw ArchiveFailure.outputExists }
      try fm.moveItem(at: output, to: volumeFolder)
      progress(ArchiveProgress(1, "完成"))
      return volumeFolder
    }
    try fm.moveItem(at: outputURL, to: destination)
    progress(ArchiveProgress(1, "完成"))
    return destination
  }
  private func stage(_ source: URL, to target: URL, clean: Bool, control: OperationControl) throws {
    try control.check()
    if clean && ArchiveSafety.isMetadata(source) { return }
    let fm = FileManager.default
    let values = try source.resourceValues(forKeys: [
      .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey,
    ])
    if values.isSymbolicLink == true {
      try fm.copyItem(at: source, to: target)
      return
    }
    if values.isDirectory == true {
      try fm.createDirectory(at: target, withIntermediateDirectories: false)
      for item in try directoryItems(source) {
        try stage(
          item, to: target.appendingPathComponent(item.lastPathComponent), clean: clean,
          control: control)
      }
    } else {
      guard values.isRegularFile == true else {
        throw ArchiveFailure.invalid("不能打包设备、套接字或命名管道：" + source.lastPathComponent)
      }
      // A clone avoids duplicating file data on APFS. Cross-volume inputs fall back to a copy.
      let cloned = source.path.withCString { src in
        target.path.withCString { dst in clonefile(src, dst, 0) }
      }
      if cloned != 0 { try fm.copyItem(at: source, to: target) }
    }
  }
  public func extract(
    _ archive: URL, to destination: URL, password: String = "", selected: [String] = [],
    encoding: ArchiveEncoding = .auto, flattenSingleFolder: Bool = false,
    control: OperationControl = OperationControl(),
    progress: @escaping @Sendable (ArchiveProgress) -> Void = { _ in }
  ) throws -> URL {
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw ArchiveFailure.outputExists
    }
    progress(ArchiveProgress(nil, "检查归档"))
    return try withReadablePayload(
      archive, password: password, parent: destination.deletingLastPathComponent(), control: control
    ) { payload in
      try extractContents(
        payload, originalArchive: archive, to: destination, password: password, selected: selected,
        encoding: encoding, flattenSingleFolder: flattenSingleFolder,
        control: control, progress: progress)
    }
  }
  private func extractContents(
    _ archive: URL, originalArchive: URL, to destination: URL, password: String, selected: [String],
    encoding: ArchiveEncoding = .auto, flattenSingleFolder: Bool = false,
    control: OperationControl, progress: @escaping @Sendable (ArchiveProgress) -> Void
  ) throws -> URL {
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw ArchiveFailure.outputExists
    }
    progress(ArchiveProgress(nil, "检查归档"))
    let entries = try rawList(archive, password: password, encoding: encoding, control: control)
    let total = ArchiveSafety.totalKnownSize(entries)
    if let capacity = try? destination.deletingLastPathComponent().resourceValues(forKeys: [
      .volumeAvailableCapacityForImportantUsageKey
    ]).volumeAvailableCapacityForImportantUsage, total > capacity {
      throw ArchiveFailure.diskSpace
    }
    for item in selected { try ArchiveSafety.validate(path: item) }
    let fm = FileManager.default
    let work = destination.deletingLastPathComponent().appendingPathComponent(
      ".aetherzip-" + UUID().uuidString, isDirectory: true)
    try fm.createDirectory(
      at: work, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { try? fm.removeItem(at: work) }
    var args = [
      "x", "-mmt=\(resources.extractionThreads)", "-y", "-spd", "-aoa", "-bsp1", "-sccUTF-8",
    ]
    if let cp = encoding.codePageArgument { args.append(cp) }
    args += ["-o" + work.path, "--", archive.path]
    args += selected
    _ = try execute(
      args, password: password, writable: work, control: control,
      progress: { progress(ArchiveProgress($0 * 0.9, "解压文件")) })
    try audit(work)
    try control.check()
    try fm.moveItem(at: work, to: destination)
    if flattenSingleFolder {
      try? ArchiveSafety.flattenSingleChildFolder(at: destination)
    }
    // Preserve download quarantine so executable content retains macOS protections.
    var quarantine = [UInt8](repeating: 0, count: 4096)
    let count = getxattr(
      originalArchive.path, "com.apple.quarantine", &quarantine, quarantine.count, 0, 0)
    if count > 0 {
      if let enumerator = fm.enumerator(
        at: destination, includingPropertiesForKeys: [.isSymbolicLinkKey])
      {
        for case let url as URL in enumerator {
          _ = setxattr(url.path, "com.apple.quarantine", quarantine, count, 0, XATTR_NOFOLLOW)
        }
      }
      _ = setxattr(destination.path, "com.apple.quarantine", quarantine, count, 0, XATTR_NOFOLLOW)
    }
    progress(ArchiveProgress(1, "完成"))
    return destination
  }
  private func directoryItems(_ directory: URL) throws -> [URL] {
    guard let handle = opendir(directory.path) else {
      throw ArchiveFailure.invalid("无法读取目录：" + directory.lastPathComponent)
    }
    defer { closedir(handle) }
    var items = [URL]()
    while let entry = readdir(handle) {
      let name = withUnsafePointer(to: entry.pointee.d_name) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
      }
      if name != "." && name != ".." { items.append(directory.appendingPathComponent(name)) }
    }
    return items
  }
  private func audit(_ root: URL) throws {
    let prefix = root.resolvingSymlinksInPath().path + "/"
    var pending = [root]
    while let folder = pending.popLast() {
      for item in try directoryItems(folder) {
        let values = try item.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        if values.isSymbolicLink == true {
          if !item.resolvingSymlinksInPath().path.hasPrefix(prefix) {
            throw ArchiveFailure.unsafePath(item.lastPathComponent)
          }
        } else if values.isDirectory == true {
          pending.append(item)
        }
      }
    }
  }
}
