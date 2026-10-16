import AetherZipCore
import Security
import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
  @Bindable var model: AppModel
  @State private var showPassword = false
  @State private var isTargeted = false
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        FileBadge(symbol: "shippingbox", size: 32)
        VStack(alignment: .leading, spacing: 4) {
          Text("创建归档").font(.system(size: 18, weight: .medium))
          Text("打包好，再轻松出发。").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          model.composePresented = false
        } label: {
          Image(systemName: "xmark")
        }.buttonStyle(.plain).foregroundStyle(.secondary)
      }.padding(24)
      Divider()
      VStack(alignment: .leading, spacing: 15) {
        HStack(spacing: 10) {
          Image(systemName: "folder").foregroundStyle(AZ.accent)
          VStack(alignment: .leading, spacing: 3) {
            Text(
              model.sources.count == 1
                ? model.sources[0].lastPathComponent : "\(model.sources.count) 个项目"
            ).lineLimit(1)
            Text("源文件保持不变").font(.system(size: 10)).foregroundStyle(.secondary)
          }
          Spacer()
          Button("添加") { addFiles() }.buttonStyle(.borderless)
        }.font(.system(size: 12)).padding(12).background(
          .quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9)
        ).overlay(
          RoundedRectangle(cornerRadius: 9).strokeBorder(isTargeted ? AZ.accent : Color.clear, lineWidth: 1.5)
        )
        VStack(alignment: .leading, spacing: 7) {
          Text("归档名称").font(.system(size: 11)).foregroundStyle(.secondary)
          HStack {
            TextField("归档名称", text: $model.archiveName).textFieldStyle(.plain)
            Text("." + model.options.format.rawValue).foregroundStyle(.secondary)
          }.padding(9).background(.background, in: RoundedRectangle(cornerRadius: 7)).overlay(
            RoundedRectangle(cornerRadius: 7).strokeBorder(.separator.opacity(0.5)))
        }
        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("格式").font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("格式", selection: $model.options.format) {
              ForEach(ArchiveFormat.allCases) { f in Text(f.title).tag(f) }
            }.labelsHidden().frame(maxWidth: .infinity)
          }
          VStack(alignment: .leading, spacing: 6) {
            Text("压缩等级").font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("压缩等级", selection: $model.options.level) {
              Text("均衡").tag(5)
              Text("快速").tag(1)
              Text("高压缩率").tag(9)
              Text("不压缩，仅封装").tag(0)
            }.labelsHidden()
          }
        }
        Toggle(isOn: $model.encrypted) { Label("密码保护", systemImage: "lock") }.toggleStyle(.switch)
          .controlSize(.mini).disabled(!model.options.format.supportsEncryption)
        if model.encrypted && model.options.format.supportsEncryption {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Group {
                if showPassword {
                  TextField("归档密码", text: $model.options.password)
                } else {
                  SecureField("归档密码", text: $model.options.password)
                }
              }.textFieldStyle(.plain)
              Button {
                showPassword.toggle()
              } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
              }.buttonStyle(.plain)
              Button("生成") {
                var bytes = [UInt8](repeating: 0, count: 18)
                if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
                  model.options.password = Data(bytes).base64EncodedString()
                }
              }.buttonStyle(.borderless)
            }.padding(10).background(.background, in: RoundedRectangle(cornerRadius: 7)).overlay(
              RoundedRectangle(cornerRadius: 7).strokeBorder(.separator.opacity(0.5)))
            Toggle("同时加密文件名", isOn: $model.options.hideNames).disabled(
              model.options.format != .sevenZip)
            Text(
              model.options.format == .sevenZip
                ? "开启后，没有密码便无法查看包内目录。" : "ZIP AES 保护内容，文件名仍可见；密码仅支持英文、数字和符号。"
            ).font(.system(size: 10)).foregroundStyle(.secondary)
            Toggle("保存到本机钥匙串", isOn: $model.rememberPassword)
          }.font(.system(size: 11)).transition(.opacity.combined(with: .move(edge: .top)))
        }
        Divider()
        Toggle(isOn: $model.options.cleanMetadata) {
          HStack {
            Label("干净分享", systemImage: "sparkles")
            Text("过滤 Mac 附属文件").font(.system(size: 10)).foregroundStyle(.secondary)
          }
        }.toggleStyle(.switch).controlSize(.mini)
        if model.options.format == .sevenZip {
          Picker("分卷", selection: $model.options.volumeMiB) {
            Text("不分卷").tag(0)
            Text("100 MB / 卷").tag(100)
            Text("500 MB / 卷").tag(500)
            Text("1 GB / 卷").tag(1024)
          }.font(.system(size: 11))
        }
        if let error = model.composeError {
          Text(error).font(.caption).foregroundStyle(.red).fixedSize(
            horizontal: false, vertical: true)
        }
        HStack {
          Label("保存到", systemImage: "folder").foregroundStyle(.secondary)
          Spacer()
          Button(model.destination.lastPathComponent) { model.chooseDestination() }.buttonStyle(
            .borderless
          ).lineLimit(1)
        }.font(.system(size: 11))
      }.padding(.horizontal, 24).padding(.vertical, 18).font(.system(size: 12))
      Divider()
      HStack {
        Button("取消") { model.composePresented = false }.keyboardShortcut(.cancelAction).buttonStyle(
          .plain)
        Spacer()
        Button {
          model.create()
        } label: {
          Label(model.encrypted ? "加密并创建" : "创建压缩包", systemImage: "arrow.right")
        }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
      }.padding(.horizontal, 24).padding(.vertical, 15)
    }.frame(width: 445).background(.regularMaterial).animation(
      reducedMotion ? nil : AZ.motion, value: model.encrypted
    ).animation(reducedMotion ? nil : AZ.motion, value: model.options.format).onChange(
      of: model.options.format
    ) { _, new in
      if !new.supportsEncryption { model.encrypted = false }
      if new != .sevenZip { model.options.volumeMiB = 0 }
    }.onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
      Task { @MainActor in
        for provider in providers {
          if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
            let url = (item as? URL) ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) })
          {
            if !model.sources.contains(url) {
              model.sources.append(url)
            }
          }
        }
      }
      return true
    }
  }
  func addFiles() {
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.allowsMultipleSelection = true
    if p.runModal() == .OK {
      for url in p.urls where !model.sources.contains(url) { model.sources.append(url) }
    }
  }
}
struct PasswordView: View {
  @Bindable var model: AppModel
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock").font(.system(size: 31, weight: .light)).foregroundStyle(AZ.accent)
        .frame(width: 66, height: 70).glassEffect(
          .regular.tint(AZ.accent.opacity(0.15)), in: .rect(cornerRadius: 18)
        ).padding(.top, 10)
      Text("只向你，打开。").font(.system(size: 24, weight: .medium))
      Text(model.openedArchive?.lastPathComponent ?? "加密归档").font(.system(size: 12))
        .foregroundStyle(.secondary)
      SecureField("归档密码", text: $model.archivePassword).textFieldStyle(.roundedBorder).padding(
        .top, 8
      ).onSubmit { model.unlock() }
      if let error = model.passwordError { Text(error).font(.caption).foregroundStyle(.red) }
      Toggle("保存到本机钥匙串", isOn: $model.rememberPassword).font(.system(size: 11))
      Button {
        model.unlock()
      } label: {
        Label("解锁归档", systemImage: "lock.open").frame(maxWidth: .infinity)
      }.buttonStyle(PrimaryButton()).keyboardShortcut(.defaultAction)
      Button("使用已保存的密码", systemImage: "touchid") { model.useSavedPassword() }.buttonStyle(
        .borderless)
      Button("取消") {
        model.cancelUnlock()
      }.buttonStyle(.plain).foregroundStyle(.secondary).keyboardShortcut(.cancelAction)
      Text("密码仅在本机使用，不会上传。").font(.system(size: 10)).foregroundStyle(.tertiary)
    }.padding(30).frame(width: 360).background(.regularMaterial)
  }
}
struct SettingsView: View {
  @Bindable var model: AppModel
  @ObservedObject var updater: Updater
  @Bindable var launchAtLogin: LaunchAtLogin
  var body: some View {
    Form {
      Section(L10n.appearance) {
        Picker(L10n.theme, selection: $model.appearance) {
          Text(L10n.systemTheme).tag("system")
          Text(L10n.lightTheme).tag("light")
          Text(L10n.darkTheme).tag("dark")
        }
        Picker(L10n.language, selection: $model.appLanguage) {
          ForEach(AppLanguage.allCases) { lang in
            Text(lang.title).tag(lang.rawValue)
          }
        }
      }
      Section(L10n.startupSection) {
        Toggle(L10n.launchAtLogin, isOn: Binding(
          get: { launchAtLogin.isEnabled },
          set: { launchAtLogin.setEnabled($0) }
        ))
        if launchAtLogin.requiresApproval {
          HStack {
            Text(L10n.loginItemDisabledNote)
              .font(.caption)
              .foregroundStyle(.orange)
            Spacer()
            Button(L10n.openSettingsBtn) {
              launchAtLogin.openSystemSettings()
            }
          }
        }
        if launchAtLogin.isEnabled {
          Toggle(L10n.hideOnLogin, isOn: $model.hideOnLoginLaunch)
            .font(.system(size: 11))
          Text(L10n.hideOnLoginNote)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let err = launchAtLogin.lastError {
          Text(err).font(.caption).foregroundStyle(.red)
        }
      }
      Section(L10n.unarchiveSection) {
        Picker(L10n.openMode, selection: $model.openMode) {
          Text(L10n.openModeBrowse).tag("browse")
          Text(L10n.openModeDirect).tag("directExtract")
        }
        Toggle(L10n.revealInFinder, isOn: $model.revealAfterExtract)
        Toggle(L10n.trashArchive, isOn: $model.trashAfterExtract)
        Toggle(L10n.flattenSingle, isOn: $model.flattenSingleFolder)
        Picker(L10n.encodingTitle, selection: $model.defaultEncodingRaw) {
          ForEach(ArchiveEncoding.allCases) { enc in
            Text(enc.title).tag(enc.rawValue)
          }
        }
        Text(L10n.encodingNote).font(.caption).foregroundStyle(.secondary)
      }
      Section(L10n.isEnglish ? "Archiving" : "归档") {
        Toggle(L10n.cleanDefault, isOn: $model.cleanDefault)
        Text(L10n.cleanDefaultNote).font(.caption).foregroundStyle(.secondary)
      }
      Section(L10n.softwareUpdate) {
        Toggle(L10n.autoCheckUpdates, isOn: $updater.automaticallyChecksForUpdates)
        HStack {
          Text("Sparkle 安全更新服务")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Button(L10n.checkUpdatesNow) {
            updater.checkForUpdates()
          }.disabled(!updater.canCheckForUpdates)
        }
      }
      Section(L10n.isEnglish ? "Finder Integration" : "Finder 集成") {
        Text(L10n.isEnglish ? "Use quick ZIP / 7z compression, encryption, and extraction in Finder Services." : "在 Finder 右键菜单的「服务」中使用快速 ZIP / 7z 压缩、加密压缩和解压。").font(.caption)
        Text(L10n.isEnglish ? "Please place AetherZip in Applications. Finder loads services after first launch." : "请将应用放在「应用程序」目录。首次打开后，Finder 会加载服务菜单。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section(L10n.isEnglish ? "About" : "关于") {
        LabeledContent("AetherZip", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") · Official Release")
        LabeledContent(L10n.isEnglish ? "Requirements" : "运行要求", value: "macOS 26+ · Apple Silicon")
        Link("Aether Native", destination: URL(string: "https://aethernative.com/")!)
        Button(L10n.isEnglish ? "Open Source Licenses" : "第三方开源许可") {
          if let u = Bundle.main.url(forResource: "7zip-License", withExtension: "txt") {
            NSWorkspace.shared.open(u)
          }
        }
      }
    }.formStyle(.grouped).frame(width: 500, height: 720)
  }
}
