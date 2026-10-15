import Foundation

public enum ArchiveFormat: String, CaseIterable, Codable, Sendable, Identifiable {
  case zip
  case sevenZip = "7z"
  case tar
  case tarGzip = "tar.gz"
  case tarXz = "tar.xz"
  case tarBzip2 = "tar.bz2"
  public var id: String { rawValue }
  public var title: String { rawValue.uppercased() }
  public var supportsEncryption: Bool { self == .zip || self == .sevenZip }
  public var engineType: String {
    switch self {
    case .sevenZip: "7z"
    case .zip: "zip"
    default: "tar"
    }
  }
  public var filter: String? {
    switch self {
    case .tarGzip: "gzip"
    case .tarXz: "xz"
    case .tarBzip2: "bzip2"
    default: nil
    }
  }
  public static let readableExtensions = Set([
    "zip", "7z", "rar", "tar", "gz", "gzip", "tgz", "xz", "txz", "bz2", "tbz2", "cab", "iso", "dmg",
    "cpio", "xar", "ar", "deb", "rpm", "wim", "jar", "war", "apk", "epub", "z", "lzma", "001",
    "zst", "tzst", "zipx", "bzip2", "tbz",
  ])
  public static func canRead(_ url: URL) -> Bool {
    readableExtensions.contains(url.pathExtension.lowercased())
  }
}

public enum ArchiveEncoding: String, CaseIterable, Codable, Sendable, Identifiable {
  case auto = "auto"
  case utf8 = "utf8"
  case gbk = "gbk"
  case shiftJIS = "shiftjis"
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .auto: return "自动检测"
    case .utf8: return "通用 UTF-8"
    case .gbk: return "简体中文 (GBK / Windows)"
    case .shiftJIS: return "日文 (Shift-JIS)"
    }
  }
  public var codePageArgument: String? {
    switch self {
    case .auto, .utf8: return nil
    case .gbk: return "-mcp=936"
    case .shiftJIS: return "-mcp=932"
    }
  }
}

public struct ArchiveOptions: Sendable {
  public var format: ArchiveFormat = .zip
  public var level: Int = 5
  public var password: String = ""
  public var hideNames = true
  public var cleanMetadata = true
  public var volumeMiB: Int = 0
  public var encoding: ArchiveEncoding = .auto
  public init() {}
}
public struct ArchiveEntry: Identifiable, Sendable, Hashable {
  public var id: String { path }
  public let path: String
  public let size: Int64
  public let packedSize: Int64
  public let directory: Bool
  public let encrypted: Bool
  public let modified: String
  public let symbolicLink: String?
  public init(
    path: String, size: Int64 = 0, packedSize: Int64 = 0, directory: Bool = false,
    encrypted: Bool = false, modified: String = "", symbolicLink: String? = nil
  ) {
    self.path = path
    self.size = size
    self.packedSize = packedSize
    self.directory = directory
    self.encrypted = encrypted
    self.modified = modified
    self.symbolicLink = symbolicLink
  }
}

extension ArchiveEntry: Comparable {
  public static func < (lhs: ArchiveEntry, rhs: ArchiveEntry) -> Bool {
    lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
  }
}
public enum ArchiveFailure: LocalizedError, Sendable {
  case passwordRequired, invalidPassword, cancelled
  case unsafePath(String)
  case invalid(String)
  case engine(String)
  case outputExists, diskSpace
  public var isPasswordFailure: Bool {
    switch self {
    case .passwordRequired, .invalidPassword: true
    default: false
    }
  }
  public var errorDescription: String? {
    switch self {
    case .passwordRequired: "这个归档需要密码。"
    case .invalidPassword: "密码错误，或加密数据已损坏。"
    case .cancelled: "任务已取消，原文件保持不变。"
    case .unsafePath(let name): "归档含有不安全的路径或链接：\(name)"
    case .invalid(let reason): reason
    case .engine(let message): message
    case .outputExists: "输出位置已有同名文件，请更换名称。"
    case .diskSpace: "目标磁盘可用空间不足。"
    }
  }
}
public struct ArchiveProgress: Sendable {
  public let fraction: Double?
  public let stage: String
  public init(_ fraction: Double?, _ stage: String) {
    self.fraction = fraction
    self.stage = stage
  }
}
public enum ArchiveSafety {
  public static func validate(path: String) throws {
    let path = path.replacingOccurrences(of: "\\", with: "/")
    guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0"), !path.contains("\n"),
      !path.contains("\r"), !path.contains(":"),
      !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    else { throw ArchiveFailure.unsafePath(path) }
  }
  public static func isMetadata(_ url: URL) -> Bool {
    if url.lastPathComponent == ".DS_Store" || url.lastPathComponent == "__MACOSX" { return true }
    guard url.lastPathComponent.hasPrefix("._"), let h = try? FileHandle(forReadingFrom: url) else {
      return false
    }
    defer { try? h.close() }
    return (try? h.read(upToCount: 4)) == Data([0, 5, 22, 7])
  }
  public static func parseListing(_ text: String, defaultPath: String? = nil) throws
    -> [ArchiveEntry]
  {
    let content: String
    if let range = text.range(of: "----------\n") {
      content = String(text[range.upperBound...])
    } else {
      content = text
    }
    var result = [ArchiveEntry]()
    var fields = [String: String]()
    func flush() throws {
      guard !fields.isEmpty, let path = fields["Path"] ?? defaultPath else {
        fields.removeAll()
        return
      }
      try validate(path: path)
      for key in ["Hard Link", "Copy Link"] {
        if let link = fields[key], !link.isEmpty { throw ArchiveFailure.unsafePath(path) }
      }
      result.append(
        ArchiveEntry(
          path: path, size: Int64(fields["Size"] ?? "") ?? -1,
          packedSize: Int64(fields["Packed Size"] ?? "") ?? 0,
          directory: fields["Folder"] == "+" || (fields["Attributes"]?.contains("D") ?? false),
          encrypted: fields["Encrypted"] == "+", modified: fields["Modified"] ?? "",
          symbolicLink: fields["Symbolic Link"]))
      fields.removeAll()
    }
    for line in content.components(separatedBy: "\n") {
      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        try flush()
        continue
      }
      if let r = line.range(of: " = ") {
        let key = String(line[..<r.lowerBound])
        if fields[key] != nil { throw ArchiveFailure.invalid("归档目录记录存在歧义，无法安全读取。") }
        fields[key] = String(line[r.upperBound...])
      }
    }
    try flush()
    return result
  }
  public static func totalKnownSize(_ entries: [ArchiveEntry]) -> Int64 {
    entries.reduce(Int64(0)) { current, entry in
      let (sum, overflow) = current.addingReportingOverflow(max(0, entry.size))
      return overflow ? Int64.max : sum
    }
  }
  public static func availableName(_ requested: URL) -> URL {
    var result = requested
    var index = 2
    while FileManager.default.fileExists(atPath: result.path) {
      result = requested.deletingLastPathComponent().appendingPathComponent(
        requested.deletingPathExtension().lastPathComponent + " (\(index))"
      ).appendingPathExtension(requested.pathExtension)
      index += 1
    }
    return result
  }
  public static func flattenSingleChildFolder(at destination: URL) throws {
    let fm = FileManager.default
    let items = try fm.contentsOfDirectory(at: destination, includingPropertiesForKeys: [.isDirectoryKey])
    guard items.count == 1, let single = items.first else { return }
    let isDir = (try? single.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    guard isDir else { return }
    let temp = destination.deletingLastPathComponent().appendingPathComponent(".aetherzip-flatten-" + UUID().uuidString)
    try fm.moveItem(at: single, to: temp)
    defer { try? fm.removeItem(at: temp) }
    for item in try fm.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil) {
      let target = destination.appendingPathComponent(item.lastPathComponent)
      if !fm.fileExists(atPath: target.path) {
        try fm.moveItem(at: item, to: target)
      }
    }
  }
}
