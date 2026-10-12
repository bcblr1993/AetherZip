import AetherZipCore
import AppKit
import Observation
import SwiftUI

@MainActor @Observable final class AppModel {
  enum Page: String, CaseIterable {
    case home = "开始"
    case archive = "浏览归档"
    case tasks = "任务"
  }
  var page: Page = .home
  var sources: [URL] = []
  var composePresented = false
  var passwordPresented = false
  var options = ArchiveOptions()
  var archiveName = "归档"
  var destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
  var openedArchive: URL?
  var entries: [ArchiveEntry] = []
  var selection = Set<String>()
  var search = ""
  var archivePassword = ""
  var rememberPassword = false
  var jobs: [ArchiveJob] = []
  var isReading = false
  var message: String?
  var composeError: String?
  var passwordError: String?
  var error: String?
  var recent: [URL] = []
  var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system" {
    didSet {
      UserDefaults.standard.set(appearance, forKey: "appearance")
      NSApp.appearance =
        appearance == "system" ? nil : NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
    }
  }
  var cleanDefault = UserDefaults.standard.object(forKey: "cleanDefault") as? Bool ?? true {
    didSet { UserDefaults.standard.set(cleanDefault, forKey: "cleanDefault") }
  }
  var encrypted = false
  var pendingExtract: (URL, URL, [String])?
  var revealMainWindow: (() -> Void)?
  var floatingPanel: NSPanel?
  private var running = false
  private var pending: [PendingJob] = []
  let engine: ArchiveEngine
  init() {
    engine = ArchiveEngine(
      executable: Bundle.main.url(forResource: "7zz", withExtension: nil)
        ?? URL(fileURLWithPath: "/missing/7zz"))
    NSApp.appearance =
      appearance == "system" ? nil : NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
    recent = (UserDefaults.standard.stringArray(forKey: "recentArchives") ?? []).map {
      URL(fileURLWithPath: $0)
    }.filter { FileManager.default.fileExists(atPath: $0.path) }
  }
  var archiveSizeDescription: String {
    if entries.contains(where: { $0.size < 0 }) { return "部分大小未知" }
    return ByteCountFormatter.string(
      fromByteCount: ArchiveSafety.totalKnownSize(entries), countStyle: .file)
  }
  var filteredEntries: [ArchiveEntry] {
    entries.filter { search.isEmpty || $0.path.localizedCaseInsensitiveContains(search) }
  }
  var activeJobs: Int {
    jobs.filter { $0.state == .running || $0.state == .queued || $0.state == .paused }.count
  }
  func pickFiles(preset: String? = nil) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = true
    panel.prompt = "选择"
    if panel.runModal() == .OK { accept(panel.urls, preset: preset) }
  }
  func accept(_ urls: [URL], preset: String? = nil) {
    guard !urls.isEmpty else { return }
    revealMainWindow?()
    if urls.count == 1, ArchiveFormat.canRead(urls[0]), preset == nil {
      openArchive(urls[0])
      return
    }
    rememberPassword = false
    composeError = nil
    sources = urls
    archiveName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "归档"
    destination = urls[0].deletingLastPathComponent()
    options = ArchiveOptions()
    options.cleanMetadata = cleanDefault
    options.format = preset == "secure" || preset == "compact" ? .sevenZip : .zip
    options.level = preset == "compact" ? 9 : 5
    encrypted = preset == "secure"
    composePresented = true
    NSApp.activate(ignoringOtherApps: true)
  }
  func chooseDestination() {
    let p = NSOpenPanel()
    p.canChooseFiles = false
    p.canChooseDirectories = true
    p.directoryURL = destination
    p.prompt = "选择输出目录"
    if p.runModal() == .OK { destination = p.url! }
  }
  func create() {
    guard !archiveName.isEmpty, !archiveName.contains("/"), !archiveName.contains(":"),
      archiveName != ".", archiveName != ".."
    else {
      composeError = "请输入有效的归档名称。"
      return
    }
    guard !encrypted || !options.password.isEmpty else {
      composeError = "请设置归档密码。"
      return
    }
    if !encrypted { options.password = "" }
    guard options.format != .zip || options.password.unicodeScalars.allSatisfy({ $0.value < 128 })
    else {
      composeError = "ZIP AES 密码请使用英文、数字或符号。需要中文密码时请选择 7z。"
      return
    }
    let target = ArchiveSafety.availableName(
      destination.appendingPathComponent(archiveName + "." + options.format.rawValue))
    let snapshot = options
    composePresented = false
    enqueue(.create(sources, target, snapshot), savePassword: encrypted && rememberPassword)
    options.password = ""
    rememberPassword = false
  }
  func quickCreate(_ urls: [URL], format: ArchiveFormat) {
    guard !urls.isEmpty else { return }
    var o = ArchiveOptions()
    o.format = format
    o.cleanMetadata = cleanDefault
    let name = urls.count == 1 ? urls[0].lastPathComponent : "归档"
    let out = ArchiveSafety.availableName(
      urls[0].deletingLastPathComponent().appendingPathComponent(name + "." + format.rawValue))
    enqueue(.create(urls, out, o))
    showFloatingTask()
  }
  func addRecent(_ url: URL) {
    recent.removeAll { $0 == url }
    recent.insert(url, at: 0)
    recent = Array(recent.prefix(12))
    UserDefaults.standard.set(recent.map(\.path), forKey: "recentArchives")
  }
  func openArchive(_ url: URL, password: String = "") {
    revealMainWindow?()
    passwordError = nil
    openedArchive = url
    archivePassword = password
    entries = []
    selection = []
    search = ""
    page = .archive
    isReading = true
    let engine = self.engine
    Task {
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          try engine.list(url, password: password)
        }.value
        guard openedArchive == url else { return }
        entries = result
        if rememberPassword && !password.isEmpty {
          saveVerifiedPassword(password, for: url)
          rememberPassword = false
        }
        isReading = false
        addRecent(url)
      } catch {
        guard openedArchive == url else { return }
        isReading = false
        if case ArchiveFailure.passwordRequired = error {
          passwordPresented = true
        } else if case ArchiveFailure.invalidPassword = error {
          passwordPresented = true
          self.passwordError = error.localizedDescription
        } else {
          self.error = error.localizedDescription
        }
      }
    }
  }
  func unlock() {
    let password = archivePassword
    guard !password.isEmpty, let url = openedArchive else { return }
    passwordPresented = false
    if let pair = pendingExtract {
      pendingExtract = nil
      enqueue(.extract(pair.0, pair.1, password, pair.2), savePassword: rememberPassword)
      rememberPassword = false
      showFloatingTask()
    } else {
      openArchive(url, password: password)
    }
  }
  func cancelUnlock() {
    passwordPresented = false
    archivePassword = ""
    passwordError = nil
    rememberPassword = false
    pendingExtract = nil
    runNext()
  }
  func useSavedPassword() {
    guard let url = openedArchive else { return }
    do {
      archivePassword = try PasswordStore.read(for: url)
      unlock()
    } catch { self.passwordError = error.localizedDescription }
  }
  func extractOpened() {
    guard let archive = openedArchive else { return }
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.canChooseFiles = false
    p.directoryURL = archive.deletingLastPathComponent()
    p.prompt = "解压到这里"
    if p.runModal() == .OK, let parent = p.url {
      let target = ArchiveSafety.availableName(
        parent.appendingPathComponent(outputName(archive), isDirectory: true))
      enqueue(.extract(archive, target, archivePassword, Array(selection)))
    }
  }
  func quickExtract(_ urls: [URL], choose: Bool = false) {
    var parent: URL?
    if choose {
      let p = NSOpenPanel()
      p.canChooseDirectories = true
      p.canChooseFiles = false
      p.prompt = "选择解压位置"
      if p.runModal() != .OK { return }
      parent = p.url
    }
    for url in urls where ArchiveFormat.canRead(url) {
      let target = ArchiveSafety.availableName(
        (parent ?? url.deletingLastPathComponent()).appendingPathComponent(
          outputName(url), isDirectory: true))
      enqueue(.extract(url, target, "", []))
    }
    showFloatingTask()
  }
  private func outputName(_ url: URL) -> String {
    var name = url.deletingPathExtension().lastPathComponent
    if name.hasSuffix(".tar") { name = String(name.dropLast(4)) }
    return name.isEmpty ? "解压文件" : name
  }
  func testOpened() {
    guard let url = openedArchive else { return }
    let engine = self.engine
    let password = archivePassword
    isReading = true
    Task {
      do {
        try await Task.detached { try engine.test(url, password: password) }.value
        message = "完整性检查通过。"
      } catch { self.error = error.localizedDescription }
      isReading = false
    }
  }
  private func saveVerifiedPassword(_ password: String, for url: URL) {
    do { try PasswordStore.save(password, for: url) } catch {
      self.error = "归档操作已完成，但密码未保存：" + error.localizedDescription
    }
  }
  func enqueue(_ operation: JobOperation, savePassword: Bool = false) {
    let job = ArchiveJob(name: operation.name)
    jobs.insert(job, at: 0)
    pending.append(PendingJob(job: job, operation: operation, savePassword: savePassword))
    page = .tasks
    runNext()
  }
  private func runNext() {
    guard !running, !pending.isEmpty, !passwordPresented else { return }
    running = true
    let request = pending.removeFirst()
    let job = request.job
    let engine = self.engine
    let control = job.control
    job.state = .running
    Task {
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          let progress: @Sendable (ArchiveProgress) -> Void = { p in
            Task { @MainActor in
              job.progress = p.fraction
              job.stage = p.stage
            }
          }
          switch request.operation {
          case .create(let sources, let output, let options):
            return try engine.create(
              sources: sources, destination: output, options: options, control: control,
              progress: progress)
          case .extract(let archive, let output, let password, let selected):
            return try engine.extract(
              archive, to: output, password: password, selected: selected, control: control,
              progress: progress)
          }
        }.value
        if request.savePassword {
          switch request.operation {
          case .create(_, let target, let options):
            let key =
              options.volumeMiB > 0
              ? result.appendingPathComponent(target.lastPathComponent + ".001") : result
            saveVerifiedPassword(options.password, for: key)
          case .extract(let archive, _, let password, _):
            saveVerifiedPassword(password, for: archive)
          }
        }
        job.output = result
        job.state = .completed
        job.progress = 1
        job.stage = "完成"
        if ArchiveFormat.canRead(result) { addRecent(result) }
      } catch {
        if case ArchiveFailure.cancelled = error {
          job.state = .cancelled
          job.stage = "已取消"
        } else if let failure = error as? ArchiveFailure, failure.isPasswordFailure,
          case .extract(let archive, let out, _, let selected) = request.operation
        {
          job.state = .failed
          job.stage = "等待密码"
          openedArchive = archive
          archivePassword = ""
          pendingExtract = (archive, out, selected)
          passwordError = failure.errorDescription
          revealMainWindow?()
          passwordPresented = true
          NSApp.activate(ignoringOtherApps: true)
        } else {
          job.state = .failed
          job.stage = "未完成"
          job.failure = error.localizedDescription
        }
      }
      running = false
      runNext()
    }
  }
  func showFloatingTask() {
    if floatingPanel == nil {
      let p = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 290),
        styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
      p.title = "AetherZip"
      p.titlebarAppearsTransparent = true
      p.isReleasedWhenClosed = false
      p.contentView = NSHostingView(rootView: QuickTaskView(model: self))
      p.center()
      floatingPanel = p
    }
    floatingPanel?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
@MainActor @Observable final class ArchiveJob: Identifiable {
  enum State { case queued, running, paused, completed, failed, cancelled }
  let id = UUID(), name: String, control = OperationControl(), started = Date()
  var state: State = .queued
  var progress: Double?
  var stage = "等待处理"
  var output: URL?
  var failure: String?
  init(name: String) { self.name = name }
  func pause() {
    let p = control.togglePause()
    state = p ? .paused : .running
  }
}
struct PendingJob: Sendable {
  let job: ArchiveJob
  let operation: JobOperation
  let savePassword: Bool
}
enum JobOperation: Sendable {
  case create([URL], URL, ArchiveOptions)
  case extract(URL, URL, String, [String])
  var name: String {
    switch self {
    case .create(_, let output, _): output.lastPathComponent
    case .extract(let url, _, _, _): url.lastPathComponent + " · 解压"
    }
  }
}
