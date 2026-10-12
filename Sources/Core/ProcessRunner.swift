import Darwin
import Foundation

/// One operation owns one controller. Cancellation stays latched between subprocesses.
public final class OperationControl: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false
  private var paused = false
  public init() {}
  public func check() throws {
    lock.lock()
    let c = cancelled
    lock.unlock()
    if c { throw ArchiveFailure.cancelled }
  }
  func attach(_ p: Process) throws {
    lock.lock()
    defer { lock.unlock() }
    if cancelled { throw ArchiveFailure.cancelled }
    process = p
  }
  func launched() {
    lock.lock()
    defer { lock.unlock() }
    if cancelled, let p = process, p.isRunning {
      kill(p.processIdentifier, SIGCONT)
      p.terminate()
    } else if paused, let p = process, p.isRunning {
      kill(p.processIdentifier, SIGSTOP)
    }
  }
  func detach() {
    lock.lock()
    process = nil
    lock.unlock()
  }
  public func cancel() {
    lock.lock()
    cancelled = true
    if let p = process, p.isRunning {
      kill(p.processIdentifier, SIGCONT)
      p.terminate()
    }
    lock.unlock()
  }
  public func togglePause() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard let p = process, p.isRunning else { return false }
    paused.toggle()
    kill(p.processIdentifier, paused ? SIGSTOP : SIGCONT)
    return paused
  }
}

public struct ProcessOutput: Sendable {
  public let text: String
  public let status: Int32
}
public enum ArchiveProcess {
  public static func run(
    executable: URL, arguments: [String], input: String = "", directory: URL? = nil,
    writableDirectory: URL? = nil, control: OperationControl,
    progress: @escaping @Sendable (Double) -> Void = { _ in }
  ) throws -> ProcessOutput {
    try control.check()
    let p = Process()
    let out = Pipe()
    let stdin = Pipe()
    var args = arguments
    if let writableDirectory {
      // An extraction engine may write only into its newly-created private staging folder.
      let resolved = realpath(writableDirectory.path, nil)
      let canonical = resolved.map { String(cString: $0) } ?? writableDirectory.path
      if let resolved { free(resolved) }
      let escaped = canonical.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
        of: "\"", with: "\\\"")
      let profile =
        "(version 1)(allow default)(deny file-write*)(deny network*)(allow file-write* (subpath \"\(escaped)\"))(allow file-write* (literal \"/dev/null\"))"
      p.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
      args = ["-p", profile, executable.path] + args
    } else {
      p.executableURL = executable
    }
    p.arguments = args
    p.currentDirectoryURL = directory
    p.environment = [
      "PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8",
      "HOME": NSHomeDirectory(),
    ]
    p.standardOutput = out
    p.standardError = out
    p.standardInput = stdin
    try control.attach(p)
    defer { control.detach() }
    try p.run()
    control.launched()
    if !input.isEmpty { try? stdin.fileHandleForWriting.write(contentsOf: Data(input.utf8)) }
    try? stdin.fileHandleForWriting.close()
    var data = Data()
    var tail = ""
    let regex = try! NSRegularExpression(pattern: "([0-9]{1,3})%")
    while true {
      let chunk = out.fileHandleForReading.availableData
      if chunk.isEmpty { break }
      data.append(chunk)
      guard data.count < 64 * 1024 * 1024 else {
        p.terminate()
        p.waitUntilExit()
        throw ArchiveFailure.invalid("归档目录过大，请分批处理。")
      }
      tail += String(decoding: chunk, as: UTF8.self)
      if let m = regex.matches(in: tail, range: NSRange(tail.startIndex..., in: tail)).last,
        let r = Range(m.range(at: 1), in: tail), let value = Double(tail[r])
      {
        progress(min(value / 100, 1))
      }
      tail = String(tail.suffix(64))
    }
    p.waitUntilExit()
    try control.check()
    return ProcessOutput(text: String(decoding: data, as: UTF8.self), status: p.terminationStatus)
  }
}
