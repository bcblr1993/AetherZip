import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case system = "system"
  case zhHans = "zh-Hans"
  case en = "en"

  var id: String { rawValue }
  var title: String {
    switch self {
    case .system: return "跟随系统 (System)"
    case .zhHans: return "简体中文"
    case .en: return "English"
    }
  }
}

enum L10n {
  private static var currentLocale: String {
    let pref = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    if pref == "system" {
      return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
    }
    return pref
  }

  static var isEnglish: Bool { currentLocale == "en" }

  static func text(zh: String, en: String) -> String {
    isEnglish ? en : zh
  }

  // Navigation & Tabs
  static var home: String { text(zh: "开始", en: "Home") }
  static var archive: String { text(zh: "浏览归档", en: "Archive") }
  static var tasks: String { text(zh: "任务", en: "Tasks") }
  static var settings: String { text(zh: "偏好设置", en: "Settings") }
  static var quickActions: String { text(zh: "快捷操作", en: "Quick Actions") }

  // Home Page
  static var homeTitle: String { text(zh: "轻一点，安心一点。", en: "Lightweight, secure, native.") }
  static var homeSubtitle: String { text(zh: "把文件拖到这里，压缩、加密，或解压。", en: "Drag files here to compress, encrypt, or extract.") }
  static var chooseFiles: String { text(zh: "选择文件", en: "Choose Files") }
  static var supportedFormats: String { text(zh: "ZIP · 7z · RAR · TAR 及更多格式", en: "ZIP · 7z · RAR · TAR and more") }
  static var recentArchives: String { text(zh: "最近使用", en: "Recent") }
  static var local: String { text(zh: "本机", en: "Local") }
  static var recentEmpty: String { text(zh: "最近打开和创建的归档会显示在这里。", en: "Recently opened and created archives will appear here.") }

  // Presets
  static var presetShareTitle: String { text(zh: "通用分享", en: "Universal ZIP") }
  static var presetShareNote: String { text(zh: "标准 ZIP，干净无杂项", en: "Standard ZIP without metadata junk") }
  static var presetSecureTitle: String { text(zh: "加密分享", en: "Encrypted") }
  static var presetSecureNote: String { text(zh: "保护内容与文件名", en: "Hide contents and filenames with AES") }
  static var presetCompactTitle: String { text(zh: "更小体积", en: "High Compression") }
  static var presetCompactNote: String { text(zh: "7z，高压缩率归档", en: "7z with high LZMA2 ratio") }

  // Archive Browser
  static var newArchive: String { text(zh: "新建归档", en: "New Archive") }
  static var extractAll: String { text(zh: "全部解压", en: "Extract All") }
  static var extractSelected: String { text(zh: "解压所选", en: "Extract Selected") }
  static var archiveContents: String { text(zh: "归档内容", en: "Contents") }
  static var checkIntegrity: String { text(zh: "检查完整性", en: "Verify Integrity") }
  static var searchArchive: String { text(zh: "搜索归档", en: "Search archive") }
  static var readingArchive: String { text(zh: "正在读取归档…", en: "Reading archive…") }
  static var preparingPreview: String { text(zh: "正在准备预览…", en: "Preparing preview…") }
  static var name: String { text(zh: "名称", en: "Name") }
  static var size: String { text(zh: "大小", en: "Size") }
  static var modified: String { text(zh: "修改时间", en: "Modified") }
  static var protection: String { text(zh: "保护", en: "Security") }
  static var previewOpen: String { text(zh: "预览 / 打开", en: "Preview / Open") }
  static var extractSelectedEllipsis: String { text(zh: "解压所选项目…", en: "Extract Selected…") }
  static var dragHint: String { text(zh: "双击或按空格预览，拖拽至访达直接导出", en: "Double-click or press Space to preview, drag to Finder to export") }

  // Tasks
  static var tasksTitle: String { text(zh: "每一步，清楚可见。", en: "Every step, fully transparent.") }
  static var tasksSubtitle: String { text(zh: "扫描、压缩、加密与校验，有条不紊。", en: "Scanning, compressing, encrypting, and auditing.") }
  static var allDone: String { text(zh: "一切就绪", en: "All clear") }
  static var tasksEmpty: String { text(zh: "创建一个归档，所有任务都会显示在这里。", en: "Create an archive, and ongoing jobs will show here.") }
  static var privacyFootnote: String { text(zh: "本地处理 · 密码不上传 · 原文件不覆盖", en: "Processed locally · Passwords never leave your Mac · Never overwrites originals") }
  static var clearCompleted: String { text(zh: "清空记录", en: "Clear Completed") }
  static var removeFromList: String { text(zh: "从列表中移除", en: "Remove from list") }

  // Settings
  static var appearance: String { text(zh: "外观", en: "Appearance") }
  static var theme: String { text(zh: "界面主题", en: "Theme") }
  static var language: String { text(zh: "语言", en: "Language") }
  static var systemTheme: String { text(zh: "跟随系统", en: "System") }
  static var lightTheme: String { text(zh: "浅色", en: "Light") }
  static var darkTheme: String { text(zh: "深色", en: "Dark") }
  static var startupSection: String { text(zh: "系统与启动", en: "System & Startup") }
  static var launchAtLogin: String { text(zh: "开机自动启动", en: "Open at Login") }
  static var hideOnLogin: String { text(zh: "开机启动时保持后台运行", en: "Launch silently in background") }
  static var hideOnLoginNote: String { text(zh: "系统登录后在后台提供 Finder 快速服务，不弹出主窗口。", en: "Provide instant Finder services at login without showing the main window.") }
  static var loginItemDisabledNote: String { text(zh: "登录项已被系统禁用，请在系统设置中允许。", en: "Login item disabled by macOS. Please enable it in System Settings.") }
  static var openSettingsBtn: String { text(zh: "打开系统设置…", en: "Open System Settings…") }
  static var unarchiveSection: String { text(zh: "解压与行为", en: "Extraction & Behavior") }
  static var openMode: String { text(zh: "默认打开动作", en: "Default Open Action") }
  static var openModeBrowse: String { text(zh: "打开浏览归档清单", en: "Browse archive contents") }
  static var openModeDirect: String { text(zh: "直接解压出文件夹", en: "Directly extract to folder") }
  static var revealInFinder: String { text(zh: "解压完成后在访达中显示", en: "Reveal in Finder after extraction") }
  static var trashArchive: String { text(zh: "解压成功后将原归档移至废纸篓", en: "Move archive to Trash after extraction") }
  static var flattenSingle: String { text(zh: "自动消除同名单层文件夹嵌套", en: "Eliminate redundant single root folder") }
  static var encodingTitle: String { text(zh: "默认文件名编码", en: "Default Filename Encoding") }
  static var encodingNote: String { text(zh: "遇到来自 Windows 的中文旧 ZIP 乱码时，请选择 GBK 编码。", en: "Select GBK if filenames from legacy Windows ZIP archives appear garbled.") }
  static var cleanDefault: String { text(zh: "默认干净分享", en: "Clean sharing by default") }
  static var cleanDefaultNote: String { text(zh: "过滤 __MACOSX、.DS_Store 与 AppleDouble 元数据，保留真实隐藏文件。", en: "Filter __MACOSX, .DS_Store, and AppleDouble metadata, while keeping real hidden files.") }
  static var softwareUpdate: String { text(zh: "软件更新", en: "Software Update") }
  static var autoCheckUpdates: String { text(zh: "自动检查更新", en: "Automatically check for updates") }
  static var checkUpdatesNow: String { text(zh: "立即检查更新…", en: "Check for Updates…") }
}
