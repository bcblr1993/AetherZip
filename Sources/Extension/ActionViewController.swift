import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import AetherZipCore

@MainActor @Observable private final class ExtensionState {
  var count = 0
  var loading = true
  var error: String?
  var selection = ""
  var canOpenArchive = false
}

@MainActor final class ActionViewController: NSViewController {
  private var urls: [URL] = []
  private let state = ExtensionState()
  private var started = false

  override func loadView() {
    view = NSHostingView(rootView: ExtensionView(state: state) { [weak self] action in
      self?.open(action)
    } cancel: { [weak self] in
      self?.extensionContext?.cancelRequest(
        withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    })
    preferredContentSize = NSSize(width: 400, height: 290)
  }

  // beginRequest can arrive on an XPC queue. Read inputs once AppKit presents the view
  // on the main actor, as recommended for action extensions with a user interface.
  override func viewDidAppear() {
    super.viewDidAppear()
    guard !started else { return }
    started = true
    Task {
      guard let context = extensionContext else {
        state.loading = false
        state.error = "无法读取 Finder 选择，请关闭后重试。"
        return
      }
      for case let item as NSExtensionItem in context.inputItems {
        for provider in item.attachments ?? [] {
          var file: URL?
          if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let value = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let url = value as? URL { file = url }
            else if let data = value as? Data {
              file = URL(dataRepresentation: data, relativeTo: nil)
            }
          }
          if file == nil, let type = provider.registeredTypeIdentifiers.first {
            file = await withCheckedContinuation { continuation in
              provider.loadInPlaceFileRepresentation(forTypeIdentifier: type) { url, inPlace, _ in
                // Temporary copies belong to the provider and may disappear before handoff.
                continuation.resume(returning: inPlace ? url : nil)
              }
            }
          }
          guard let file, file.isFileURL else {
            state.error = "部分项目无法读取，请在 Finder 中选择本地文件后重试。"
            state.loading = false
            return
          }
          if !urls.contains(file) { urls.append(file) }
        }
      }
      state.count = urls.count
      state.selection = urls.count == 1 ? urls[0].lastPathComponent : "已选择 \(urls.count) 个项目"
      state.canOpenArchive = urls.count == 1 && ArchiveFormat.canRead(urls[0])
      state.loading = false
      if urls.isEmpty { state.error = "请在 Finder 中选中文件或文件夹。" }
    }
  }

  private func open(_ mode: String) {
    guard !state.loading, state.error == nil, !urls.isEmpty else { return }
    var components = URLComponents()
    components.scheme = "aetherzip"
    components.host = "action"
    components.queryItems = [URLQueryItem(name: "mode", value: mode)]
      + urls.map { URLQueryItem(name: "file", value: $0.path) }
    guard let url = components.url, NSWorkspace.shared.open(url) else {
      state.error = "无法打开 AetherZip，请先从应用程序目录启动一次。"
      return
    }
    // The containing app owns the operation. End Finder's editing transaction without
    // returning replacement items: an empty Editor result can remove the source file.
    extensionContext?.cancelRequest(
      withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
  }
}

private struct ExtensionView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var state: ExtensionState
  var action: (String) -> Void
  var cancel: () -> Void
  var body: some View {
    VStack(spacing: 18) {
      HStack(spacing: 12) {
        Image(systemName: "archivebox.fill")
          .font(.system(size: 32, weight: .light))
          .foregroundStyle(.indigo.gradient)
          .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? 0 : state.count)
        VStack(alignment: .leading, spacing: 4) {
          Text("AetherZip").font(.title3.bold())
          Text(state.loading ? "正在读取所选项目…" : state.selection)
            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        Spacer()
      }
      if let error = state.error {
        Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(spacing: 10) {
          HStack {
            Button("压缩…", systemImage: "archivebox") { action("compress") }
            Button("加密…", systemImage: "lock") { action("encrypt") }
          }
          Button("打开归档 / 解锁…", systemImage: "lock.open") { action("open") }
            .disabled(!state.canOpenArchive)
        }.buttonStyle(.glass).controlSize(.large).disabled(state.loading)
      }
      HStack {
        Text("ZIP · 7z · RAR · TAR").font(.caption2).foregroundStyle(.tertiary)
        Spacer()
        Button("取消", action: cancel).keyboardShortcut(.cancelAction)
      }
    }
    .padding(26).frame(width: 400, height: 290)
    .background(.regularMaterial)
    .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: state.loading)
  }
}
