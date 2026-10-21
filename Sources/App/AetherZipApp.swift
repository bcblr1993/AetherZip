import AetherZipCore
import AppKit
import SwiftUI

@main struct AetherZipApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  private var model: AppModel { delegate.model }
  private var updater: Updater { delegate.updater }
  private var launchAtLogin: LaunchAtLogin { delegate.launchAtLogin }
  var body: some Scene {
    Window("AetherZip", id: "main") {
      MainView(model: model).frame(minWidth: 760, minHeight: 600).onAppear {
        NSApp.servicesProvider = delegate
        NSUpdateDynamicServices()
      }.onOpenURL { delegate.handleURL($0) }
    }
    .defaultSize(width: 980, height: 700)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(after: .appInfo) {
        Button(L10n.checkUpdatesNow) { updater.checkForUpdates() }
          .disabled(!updater.canCheckForUpdates)
      }
      CommandGroup(replacing: .newItem) {
        Button(L10n.isEnglish ? "New Archive…" : "新建归档…") { model.pickFiles(preset: "share") }
          .keyboardShortcut("n", modifiers: [.command])
        Button(L10n.isEnglish ? "New Encrypted Archive…" : "新建加密归档…") { model.pickFiles(preset: "secure") }
          .keyboardShortcut("n", modifiers: [.command, .shift])
        Button(L10n.isEnglish ? "Open Archive…" : "打开归档…") { model.pickFiles() }
          .keyboardShortcut("o", modifiers: [.command])
        Divider()
        Button(L10n.closeArchive) {
          if model.openedArchive != nil {
            model.closeArchive()
          } else {
            NSApp.keyWindow?.performClose(nil)
          }
        }
        .keyboardShortcut("w", modifiers: [.command])
      }
      CommandMenu(L10n.archive) {
        Button(L10n.extractAll) {
          model.extractAllOpened()
        }
        .keyboardShortcut("e", modifiers: [.command])
        .disabled(model.openedArchive == nil || model.isReading || model.entries.isEmpty)

        Button(L10n.extractSelected) {
          model.extractOpened()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(model.openedArchive == nil || model.selection.isEmpty || model.isReading)

        Divider()

        Button(L10n.checkIntegrity) {
          model.testOpened()
        }
        .keyboardShortcut("t", modifiers: [.command, .option])
        .disabled(model.openedArchive == nil || model.isReading)
      }
      CommandGroup(after: .help) {
        Link(L10n.isEnglish ? "AetherZip Website" : "AetherZip 官网", destination: URL(string: "https://aethernative.com/apps/aetherzip/")!)
        Link(L10n.isEnglish ? "Feedback & Support" : "反馈与支持", destination: URL(string: "https://aethernative.com/apps/aetherzip/support/")!)
      }
    }
    Settings { SettingsView(model: model, updater: updater, launchAtLogin: launchAtLogin) }
  }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = AppModel()
  let updater = Updater()
  let launchAtLogin = LaunchAtLogin()
  static var launchedAtLogin = false
  static var shouldHideOnLogin = false

  func applicationWillFinishLaunching(_ notification: Notification) {
    if LaunchAtLogin.wasLaunchedAtLogin {
      AppDelegate.launchedAtLogin = true
      AppDelegate.shouldHideOnLogin =
        UserDefaults.standard.object(forKey: "hideOnLoginLaunch") as? Bool ?? true
    }
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    if AppDelegate.launchedAtLogin && AppDelegate.shouldHideOnLogin {
      DispatchQueue.main.async {
        NSApp.windows.first(where: { $0.canBecomeMain })?.orderOut(nil)
        NSApp.hide(nil)
      }
    }
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      model.revealMainWindow?()
    }
    return true
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    model.prepareToTerminate { sender.reply(toApplicationShouldTerminate: true) }
      ? .terminateLater : .terminateNow
  }
  func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let urls = filenames.map { URL(fileURLWithPath: $0) }
    model.accept(urls)
    NSApp.reply(toOpenOrPrint: .success)
  }
  func application(_ application: NSApplication, open urls: [URL]) {
    let files = urls.filter(\.isFileURL)
    if !files.isEmpty { model.accept(files) }
    for url in urls where !url.isFileURL { handleURL(url) }
  }
  private func urls(_ p: NSPasteboard) -> [URL] {
    if let values = p.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !values.isEmpty
    {
      return values
    }
    return
      (p.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String]
      ?? []).map { URL(fileURLWithPath: $0) }
  }
  @objc func quickZip(
    _ p: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) { model.quickCreate(urls(p), format: .zip) }
  @objc func quick7z(
    _ p: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) { model.quickCreate(urls(p), format: .sevenZip) }
  @objc func encryptFiles(
    _ p: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) { model.accept(urls(p), preset: "secure") }
  @objc func extractHere(
    _ p: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) { model.quickExtract(urls(p)) }
  @objc func extractTo(
    _ p: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) { model.quickExtract(urls(p), choose: true) }
  func handleURL(_ url: URL) {
    // SwiftUI also delivers Finder document opens through onOpenURL.
    if url.isFileURL {
      model.accept([url])
      return
    }
    guard url.scheme == "aetherzip", url.host == "action",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return }
    let paths = (components.queryItems ?? []).filter { $0.name == "file" }.compactMap(\.value)
    guard paths.count <= 1000, paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else {
      return
    }
    let files = paths.map { URL(fileURLWithPath: $0) }
    // External app requests always show UI before starting a file operation.
    let action = components.queryItems?.first { $0.name == "mode" }?.value
    model.accept(
      files, preset: action == "encrypt" ? "secure" : action == "compress" ? "share" : nil)
  }
}
