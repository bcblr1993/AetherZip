import AetherZipCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
  @Bindable var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  @Environment(\.openWindow) private var openWindow
  @State private var dropTarget = false
  @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.path)]
  private var sortedEntries: [ArchiveEntry] {
    model.filteredEntries.sorted(using: sortOrder)
  }
  var body: some View {
    HStack(spacing: 0) {
      sidebar
      VStack(spacing: 0) {
        toolbar
        Group {
          switch model.page {
          case .home: home
          case .archive: archive
          case .tasks: tasks
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).animation(
          reducedMotion ? nil : AZ.motion, value: model.page)
        statusbar
      }
    }
    .background(Color(nsColor: .windowBackgroundColor)).tint(AZ.accent)
    .sheet(isPresented: $model.composePresented) { ComposeView(model: model) }
    .sheet(isPresented: $model.passwordPresented) { PasswordView(model: model) }
    .alert(
      "操作未完成",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("好", role: .cancel) { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
    .alert(
      "AetherZip",
      isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })
    ) {
      Button("好", role: .cancel) { model.message = nil }
    } message: {
      Text(model.message ?? "")
    }
    .onAppear {
      model.revealMainWindow = {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    .onDrop(of: [.fileURL], isTargeted: $dropTarget) { providers in receive(providers) }
  }
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 10) {
        Image(systemName: "archivebox").font(.system(size: 23, weight: .light)).foregroundStyle(
          .white
        ).frame(width: 36, height: 38).background(
          AZ.gradient, in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 3) {
          Text("AetherZip").font(.system(size: 15, weight: .medium))
          Text("AETHER NATIVE").font(.system(size: 8, weight: .medium)).tracking(1.4)
            .foregroundStyle(.secondary)
        }
      }.padding(.horizontal, 10).padding(.top, 54).padding(.bottom, 30)
      ForEach(AppModel.Page.allCases, id: \.self) { p in
        Button {
          withAnimation(reducedMotion ? nil : AZ.motion) { model.page = p }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: icon(p)).frame(width: 17)
            Text(pageTitle(p))
            Spacer()
            if p == .tasks, model.activeJobs > 0 {
              Text("\(model.activeJobs)").font(.caption2).foregroundStyle(.secondary)
            }
          }
        }.buttonStyle(SidebarButton(selected: model.page == p))
      }
      Text(L10n.quickActions).font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 25).padding(
        .leading, 12
      ).padding(.bottom, 7)
      sideAction(L10n.presetShareTitle, "shippingbox", preset: "share")
      sideAction(L10n.presetSecureTitle, "lock.shield", preset: "secure")
      Button {
        model.pickFiles()
      } label: {
        Label(L10n.isEnglish ? "Extract & Decrypt" : "解密与解压", systemImage: "lock.open")
      }.buttonStyle(SidebarButton())
      Spacer()
      Label(L10n.isEnglish ? "Files stay on your Mac" : "文件始终留在本机", systemImage: "shield").font(.system(size: 10)).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.bottom, 13)
      SettingsLink { Label(L10n.settings, systemImage: "slider.horizontal.3") }.buttonStyle(
        SidebarButton())
    }.padding(.horizontal, 12).padding(.bottom, 15).frame(width: 182).frame(maxHeight: .infinity)
      .background(.regularMaterial).overlay(alignment: .trailing) {
        Rectangle().fill(.separator).frame(width: 0.5)
      }
  }
  func pageTitle(_ p: AppModel.Page) -> String {
    switch p {
    case .home: return L10n.home
    case .archive: return L10n.archive
    case .tasks: return L10n.tasks
    }
  }
  func icon(_ p: AppModel.Page) -> String {
    switch p {
    case .home: "square.stack.3d.up"
    case .archive: "folder"
    case .tasks: "checklist"
    }
  }
  func sideAction(_ name: String, _ symbol: String, preset: String) -> some View {
    Button {
      model.pickFiles(preset: preset)
    } label: {
      Label(name, systemImage: symbol)
    }.buttonStyle(SidebarButton())
  }
  private var toolbar: some View {
    HStack(spacing: 15) {
      Text(pageTitle(model.page)).font(.system(size: 13, weight: .medium))
      Text(model.page == .home ? (L10n.isEnglish ? "Your files, light and ready." : "你的文件，轻装出发。") : model.page == .archive ? (L10n.isEnglish ? "Inspect clearly before extracting." : "先看清，再解压。") : (L10n.isEnglish ? "All progress under your control." : "所有进度，尽在掌握。"))
        .font(.system(size: 11)).foregroundStyle(.secondary)
      Spacer()
      Button {
        model.pickFiles(preset: "share")
      } label: {
        Label(L10n.newArchive, systemImage: "plus").font(.system(size: 11))
      }.buttonStyle(.glass)
    }.padding(.horizontal, 25).frame(height: 59).background(.bar).overlay(alignment: .bottom) {
      Divider()
    }
  }
  private var home: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 0) {
          ArchiveArtwork().padding(.bottom, 24)
          Text(L10n.homeTitle).font(.system(size: 29, weight: .medium))
          Text(L10n.homeSubtitle).font(.system(size: 12)).foregroundStyle(.secondary).padding(
            .top, 11
          ).padding(.bottom, 23)
          Button {
            model.pickFiles()
          } label: {
            HStack {
              Image(systemName: "plus")
              Text(L10n.chooseFiles)
              Text("⌘ O").font(.system(size: 10)).opacity(0.6).padding(.leading, 9)
            }
          }.buttonStyle(PrimaryButton())
          Text(L10n.supportedFormats).font(.system(size: 10)).foregroundStyle(.tertiary)
            .padding(.top, 14)
        }.frame(maxWidth: .infinity).padding(.top, 45).padding(.bottom, 36).background(
          dropTarget ? AZ.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 18)
        ).animation(AZ.motion, value: dropTarget)
        HStack(spacing: 12) {
          preset(L10n.presetShareTitle, L10n.presetShareNote, "paperplane", "share")
          preset(L10n.presetSecureTitle, L10n.presetSecureNote, "lock", "secure")
          preset(L10n.presetCompactTitle, L10n.presetCompactNote, "arrow.down.right.and.arrow.up.left", "compact")
        }.padding(.bottom, 28)
        HStack {
          Text(L10n.recentArchives)
          Spacer()
          Text(L10n.local)
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.bottom, 7)
        if model.recent.isEmpty {
          HStack {
            Image(systemName: "clock").foregroundStyle(.tertiary)
            Text(L10n.recentEmpty).foregroundStyle(.secondary)
            Spacer()
          }.font(.system(size: 12)).padding(.vertical, 20)
        } else {
          ForEach(Array(model.recent.prefix(4)), id: \.path) { url in
            Button {
              model.openArchive(url)
            } label: {
              HStack(spacing: 12) {
                FileBadge()
                VStack(alignment: .leading, spacing: 3) {
                  Text(url.lastPathComponent).font(.system(size: 12))
                  Text(url.deletingLastPathComponent().lastPathComponent).font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(
                  .tertiary)
              }.padding(.vertical, 10)
            }.buttonStyle(.plain)
            Divider()
          }
        }
      }.padding(.horizontal, 32).padding(.bottom, 25)
    }
  }
  func preset(_ title: String, _ note: String, _ symbol: String, _ id: String) -> some View {
    Button {
      model.pickFiles(preset: id)
    } label: {
      VStack(alignment: .leading, spacing: 7) {
        Image(systemName: symbol).font(.system(size: 17, weight: .light)).foregroundStyle(AZ.accent)
          .padding(.bottom, 8)
        Text(title).font(.system(size: 12, weight: .medium))
        Text(note).font(.system(size: 10)).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(
        .background, in: RoundedRectangle(cornerRadius: 12)
      ).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.55)))
    }.buttonStyle(HoverLiftButton())
  }
  private var archive: some View {
    VStack(spacing: 0) {
      if let url = model.openedArchive {
        HStack(spacing: 12) {
          FileBadge(size: 43)
          VStack(alignment: .leading, spacing: 4) {
            Text(url.lastPathComponent).font(.system(size: 19, weight: .medium))
            Text(
              L10n.isEnglish
                ? "\(model.entries.count) items · \(model.archiveSizeDescription)"
                : "\(model.entries.count) 个项目 · \(model.archiveSizeDescription)"
            ).font(.system(size: 11)).foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            model.extractOpened()
          } label: {
            Label(
              model.selection.isEmpty ? L10n.extractAll : L10n.extractSelected,
              systemImage: "folder.badge.arrow.down")
          }.buttonStyle(PrimaryButton()).disabled(model.isReading || model.entries.isEmpty)
        }.padding(.vertical, 30)
        HStack(spacing: 8) {
          Label(L10n.archiveContents, systemImage: "folder").font(.caption).foregroundStyle(.secondary)
          if model.isPreviewing {
            ProgressView().controlSize(.small).padding(.leading, 6)
            Text(L10n.preparingPreview).font(.caption2).foregroundStyle(.secondary)
          }
          Spacer()
          Menu {
            ForEach(ArchiveEncoding.allCases) { enc in
              Button {
                model.changeEncoding(enc)
              } label: {
                HStack {
                  Text(enc.title)
                  if model.currentEncoding == enc {
                    Image(systemName: "checkmark")
                  }
                }
              }
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "character.book.closed")
              Text(model.currentEncoding.title)
                .font(.caption)
            }
          }
          .menuStyle(.borderedButton)
          .controlSize(.small)
          .help("切换文件名字符编码 (解决乱码)")

          Button {
            model.testOpened()
          } label: {
            Image(systemName: "checkmark.shield")
          }.help(L10n.checkIntegrity).buttonStyle(.borderless)
          TextField(L10n.searchArchive, text: $model.search).textFieldStyle(.roundedBorder).frame(width: 170)
        }.padding(.bottom, 16)
        if model.isReading {
          Spacer()
          ProgressView(L10n.readingArchive)
          Spacer()
        } else {
          Table(sortedEntries, selection: $model.selection, sortOrder: $sortOrder) {
            TableColumn(L10n.name, value: \.path) { entry in
              HStack {
                Label(entry.path, systemImage: entry.directory ? "folder" : "doc").font(
                  .system(size: 12))
                Spacer()
              }
              .contentShape(Rectangle())
              .onTapGesture(count: 2) {
                model.previewEntry(entry)
              }
              .draggable(
                model.exportItem(for: entry) ?? ArchiveItemExport(
                  archive: model.openedArchive ?? URL(fileURLWithPath: "/"),
                  entryPath: entry.path,
                  password: model.archivePassword,
                  executable: model.engine.executable
                )
              )
            }.width(min: 180, ideal: 300)
            TableColumn(L10n.size, value: \.size) { entry in
              Text(
                entry.directory || entry.size < 0
                  ? "—" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
              ).font(.system(size: 11)).foregroundStyle(.secondary)
            }.width(90)
            TableColumn(L10n.modified, value: \.modified) { entry in
              Text(entry.modified.isEmpty ? "—" : entry.modified)
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }.width(130)
            TableColumn(L10n.protection) { entry in
              if entry.encrypted { Image(systemName: "lock.fill").foregroundStyle(AZ.accent) }
            }.width(45)
          }
          .alternatingRowBackgrounds()
          .contextMenu(forSelectionType: String.self) { items in
            if let first = items.first, let entry = model.entries.first(where: { $0.path == first }), !entry.directory {
              Button(L10n.previewOpen) {
                model.previewEntry(entry)
              }
            }
            Button(L10n.extractSelectedEllipsis) { model.extractOpened() }
          }
          .onKeyPress(.space) {
            if let first = model.selection.first, let entry = model.entries.first(where: { $0.path == first }), !entry.directory {
              model.previewEntry(entry)
              return .handled
            }
            return .ignored
          }
          .onKeyPress(.return) {
            if let first = model.selection.first, let entry = model.entries.first(where: { $0.path == first }), !entry.directory {
              model.previewEntry(entry)
              return .handled
            }
            return .ignored
          }
          .frame(minHeight: 240)
        }
        HStack {
          Text(L10n.isEnglish ? "\(model.filteredEntries.count) items" : "\(model.filteredEntries.count) 个项目")
          Spacer()
          if !model.selection.isEmpty {
            Text(
              L10n.isEnglish
                ? "Selected \(model.selection.count) items · \(L10n.dragHint)"
                : "已选择 \(model.selection.count) 项 · \(L10n.dragHint)"
            )
          }
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.vertical, 14)
      } else {
        Spacer()
        ContentUnavailableView(
          L10n.isEnglish ? "Open an Archive" : "打开一个归档",
          systemImage: "archivebox",
          description: Text(L10n.isEnglish ? "Supports ZIP, 7z, RAR, TAR and more." : "支持 ZIP、7z、RAR、TAR 及更多格式。"))
        Button(L10n.isEnglish ? "Choose Archive…" : "选择归档…") { model.pickFiles() }.buttonStyle(PrimaryButton())
        Spacer()
      }
    }.padding(.horizontal, 30)
  }
  private var tasks: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 10) {
          Text(L10n.tasksTitle).font(.system(size: 27, weight: .medium))
          Text(L10n.tasksSubtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }.padding(.top, 36).padding(.bottom, 9)
        if model.jobs.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "checkmark.circle").font(.system(size: 40, weight: .ultraLight))
              .foregroundStyle(AZ.accent)
            Text(L10n.allDone).font(.title3)
            Text(L10n.tasksEmpty).font(.caption).foregroundStyle(.secondary)
            Button(L10n.isEnglish ? "Create Archive…" : "创建归档…") { model.pickFiles(preset: "share") }.buttonStyle(.glass)
          }.frame(maxWidth: .infinity).padding(.vertical, 65)
        } else {
          ForEach(model.jobs) { job in TaskCard(job: job) }
        }
        Label(L10n.privacyFootnote, systemImage: "checkmark.shield").font(.system(size: 10))
          .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 20)
      }.padding(.horizontal, 30)
    }
  }
  private var statusbar: some View {
    HStack(spacing: 6) {
      Circle().fill(.green.opacity(0.7)).frame(width: 5, height: 5)
      Text(model.activeJobs > 0 ? (L10n.isEnglish ? "\(model.activeJobs) jobs" : "\(model.activeJobs) 个任务") : (L10n.isEnglish ? "Ready" : "就绪"))
      Spacer()
      Text("Apple Silicon · macOS 26+")
    }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 22).frame(height: 29)
      .overlay(alignment: .top) { Divider() }
  }
  private func receive(_ providers: [NSItemProvider]) -> Bool {
    Task { @MainActor in
      var urls = [URL]()
      for provider in providers {
        if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
          let url = (item as? URL)
            ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) })
        {
          urls.append(url)
        }
      }
      model.accept(urls)
    }
    return true
  }
}
struct SidebarButton: ButtonStyle {
  var selected = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12)).foregroundStyle(
      selected ? Color.primary : Color.secondary
    ).padding(.horizontal, 11).padding(.vertical, 10).frame(
      maxWidth: .infinity, alignment: .leading
    ).background(
      selected
        ? Color(nsColor: .controlBackgroundColor).opacity(0.7)
        : configuration.isPressed ? AZ.accent.opacity(0.08) : .clear,
      in: RoundedRectangle(cornerRadius: 8))
  }
}
struct HoverLiftButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.scaleEffect(configuration.isPressed ? 0.98 : 1).animation(
      .easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct TaskCard: View {
  @Bindable var job: ArchiveJob
  var compact = false
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  var body: some View {
    VStack(spacing: 18) {
      HStack(spacing: 12) {
        FileBadge(
          symbol: job.state == .completed ? "checkmark.seal" : "doc.zipper", size: compact ? 32 : 39
        )
        VStack(alignment: .leading, spacing: 4) {
          Text(job.name).font(.system(size: 14, weight: .medium)).lineLimit(2)
          Text(job.stage).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        Spacer()
        if job.state == .completed {
          Text("已完成").font(.system(size: 10)).foregroundStyle(.green).padding(.horizontal, 9)
            .padding(.vertical, 4).background(.green.opacity(0.08), in: Capsule())
        }
      }
      if job.state == .running || job.state == .paused || job.state == .completed {
        HStack(alignment: .firstTextBaseline) {
          Text(job.state == .paused ? "任务已暂停" : job.stage).font(.system(size: 12))
          Spacer()
          if let p = job.progress {
            Text(p, format: .percent.precision(.fractionLength(0))).font(
              .system(size: compact ? 28 : 37, weight: .light, design: .rounded)
            ).monospacedDigit().contentTransition(.numericText())
          }
        }
        if let p = job.progress {
          ProgressView(value: p).tint(AZ.accent).animation(
            reducedMotion ? nil : .linear(duration: 0.2), value: p)
        } else {
          ProgressView().controlSize(.small).frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      if let failure = job.failure {
        Text(failure).font(.system(size: 11)).foregroundStyle(.red).textSelection(.enabled).frame(
          maxWidth: .infinity, alignment: .leading)
      }
      HStack {
        Text(job.state == .completed ? "已校验输出" : "原文件保持不变").font(.system(size: 10)).foregroundStyle(
          .secondary)
        Spacer()
        if job.state == .running || job.state == .paused {
          Button("取消") { job.control.cancel() }.buttonStyle(.borderless)
          Button(
            job.state == .paused ? "继续" : "暂停", systemImage: job.state == .paused ? "play" : "pause"
          ) { job.pause() }.buttonStyle(.glass)
        }
        if let output = job.output {
          Button("显示文件", systemImage: "arrow.up.right") {
            NSWorkspace.shared.activateFileViewerSelecting([output])
          }.buttonStyle(.glassProminent)
        }
      }.font(.system(size: 11))
    }.padding(compact ? 19 : 24).background(.background, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator.opacity(0.5))).animation(
        reducedMotion ? nil : AZ.motion, value: job.state)
  }
}
struct QuickTaskView: View {
  var model: AppModel
  var body: some View {
    VStack {
      if let job = model.jobs.first { TaskCard(job: job, compact: true) } else { Text("就绪") }
    }.padding(17).frame(width: 440).background(.regularMaterial)
  }
}
