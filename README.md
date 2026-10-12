# AetherZip

面向 macOS 26+ 和 Apple Silicon 的原生归档工具，属于 Aether Native 产品家族。
当前为可本地体验的 0.1.0 开发版，尚未公证或公开发布。

## 已实现

- SwiftUI / AppKit 原生窗口、Liquid Glass 控件、蓝紫品牌色、浅色/深色主题、弹簧转场与任务浮窗。
- ZIP、7z、TAR、TAR.GZ、TAR.XZ、TAR.BZ2 创建和解压；RAR/RAR5 解压。
- ZIP AES 和 7z 密码保护；7z 文件名加密；密码通过标准输入交给引擎，不写入进程参数。
- 7z 分卷、归档浏览与搜索、选择性解压、完整性检查、任务队列、暂停/继续/取消。
- 默认过滤 `__MACOSX`、`.DS_Store`、具有 AppleDouble 标识的 `._` 文件；保留 `.env` 和真实 `._` 文件。
- Finder「服务」菜单中的快速 ZIP / 7z 压缩、加密压缩、解压到当前目录和指定位置。
- Finder「快速操作 → AetherZip 压缩与解压」玻璃面板，支持文件/文件夹多选、压缩、加密和归档解锁。
- 输出先写入私有临时目录，校验后发布；同名输出另取名称，不覆盖源文件。
- 路径穿越检查、解压进程写入隔离、符号链接边界检查、下载隔离标记传递。

## 本地开发

要求 Xcode 26+（当前实际构建使用 Xcode 27）、Swift 6.2+、XcodeGen。引擎为官方 7-Zip 26.04 的 arm64 切片。

```sh
swift test
xcodegen generate
xcodebuild -project AetherZip.xcodeproj -scheme AetherZip \
  -configuration Debug -derivedDataPath .build/xcode build
```

`project.yml` 是工程配置来源。默认签名使用本机 Aether Native 的 Developer ID，其他开发机需替换签名团队，或使用 `CODE_SIGNING_ALLOWED=NO` 进行仅编译检查。

开发构建位于 `.build/xcode/Build/Products/Debug/AetherZip.app`。Finder 服务需要应用安装到 Applications 目录，本次验收安装于 `~/Applications/AetherZip.app`。不会更改已有压缩软件的默认文件关联。

## 格式与边界

| 格式 | 创建 | 解压 | 密码 |
| --- | --- | --- | --- |
| ZIP | 是 | 是 | AES；文件名可见，创建密码使用 ASCII |
| 7z | 是 | 是 | AES；可隐藏文件名，支持中文密码 |
| TAR / TAR.GZ / TAR.XZ / TAR.BZ2 | 是 | 是 | 格式本身无密码保护 |
| RAR / RAR5 | 否 | 是 | 支持密码解压，已用上游样例测试 |
| GZIP / XZ / BZIP2 / Zstandard 单文件流与 TAR.ZST | 否 | 是，已测 | 无 |
| CAB / ISO / DMG / WIM / CPIO / XAR 等 | 否 | 引擎具备读取能力 | 尚未逐格式验收 |

跨平台“干净分享”针对普通文件分发，不是保留所有 macOS 资源叉和扩展属性的备份格式。
解压到当前目录会创建独立子目录，避免与现有文件混写。
加密不包含密码破解。修改密码、删除归档内项目、归档修复、Finder Quick Look 预览和完整中英双语不属于本次已完成能力。

## Finder 扩展

主应用嵌入 `AetherZipFinderActions`。第一次使用时，在系统设置 → 通用 → 登录项与扩展 → 访达中启用「AetherZip 压缩与解压」。本机已启用并完成实际点击验收。

快速操作面板展示所选文件名或项目数量；文件准备完成前禁用操作，单个受支持归档才启用“打开归档 / 解锁”。一键执行由「服务」菜单提供，完整格式和加密选项由快速操作面板进入主程序。

开发时更改扩展激活规则后 Finder 可能缓存旧规则；退出空闲测试请求、重新注册本机安装包并重启 Finder 后再验收。不要把构建目录中的副本作为正式安装入口。

## 发布前待办

- macOS 26 真机或干净虚拟机验收；当前 UI 验收宿主机为 macOS 27。
- 多 GB 完整性及资源预算已复测，4 GiB 加密压缩峰值约 669 MiB、解压约 281 MiB；macOS 26 / 14 GiB CI 已通过，8 GiB 真机体验仍待验证。见 [复测报告](docs/PERFORMANCE-RESOURCE-BUDGET.md)。
- 更多恶意归档、跨工具密码兼容性及低磁盘空间测试。
- 提取进程当前使用系统 `sandbox-exec` 收紧文件写入范围；需验证后续系统兼容性并评估专用沙盒 worker。
- Keychain / Touch ID 流程未进行真实凭据保存验收。
- Developer ID 公证、DMG、Sparkle 更新、网站产品目录/版本 feed/反馈表单接入。

详细验证记录见 [docs/VALIDATION.md](docs/VALIDATION.md)，第三方来源见 [THIRD_PARTY.md](THIRD_PARTY.md)。
