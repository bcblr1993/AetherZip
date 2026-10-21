# AetherZip

面向 macOS 26+ 和 Apple Silicon 的原生归档工具，属于 Aether Native 产品家族。
[正式版本下载](https://github.com/bcblr1993/AetherZip/releases/latest)。Developer ID 签名并通过 Apple 公证，支持中英双语。[产品官网与帮助](https://aethernative.com/apps/aetherzip/)。

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
- 登录项与开机自启动：通过 macOS 原生 ServiceManagement (`SMAppService`) 接入开机启动与后台静默就绪，提供即时的访达服务响应与系统登录项设置联动。
- 归档内即时预览与拖拽导出：支持双击文件或按空格键调用系统查看器预览单项，支持直接将归档条目拖拽至访达按需解压。
- Sparkle 2 自动更新：集成 Sparkle 2 升级通道、EdDSA (Ed25519) 签名防篡改校验与静默后台检查。
- 解压行为模式与后处理：支持默认浏览清单或一键直接解压（The Unarchiver 模式）；解压后自动访达高亮、原包安全移入废纸篓、以及自动消除同名单层冗余文件夹嵌套。
- 字符编码防乱码：支持自动识别、UTF-8、Windows GBK (CP936) 与日文 Shift-JIS (CP932)，提供界面即时切换。
- 原生 Liquid Glass 多列排列表格：支持按名称、文件大小、修改时间点击表头正序/倒序排列。
- 完整类型安全中英双语国际化 (`L10n`)：支持「跟随系统」、「简体中文」与「English」切换。

## 本地开发

要求 Xcode 26+（当前实际构建使用 Xcode 27）、Swift 6.2+、XcodeGen。引擎为官方 7-Zip 26.04 的 arm64 切片。

```sh
swift test
xcodegen generate
xcodebuild -project AetherZip.xcodeproj -scheme AetherZip \
  -configuration Debug -derivedDataPath .build/xcode build
```

`project.yml` 是工程配置来源。默认签名使用本机 Aether Native 的 Developer ID，其他开发机需替换签名团队，或使用 `CODE_SIGNING_ALLOWED=NO` 进行仅编译检查。

钥匙串使用 Data Protection Keychain 和用户在场认证。可分发版本必须包含匹配应用标识的 Developer ID provisioning profile；仅用证书重签名不足以启用钥匙串权限。发布构建先以 `CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Development'` 执行 `archive -allowProvisioningUpdates`，再通过 `xcodebuild -exportArchive -allowProvisioningUpdates` 导出（ExportOptions 使用 `method=developer-id`、`signingStyle=automatic` 和本项目 team ID）。导出后核对 `com.apple.application-identifier`、`keychain-access-groups` 及 `Contents/embedded.provisionprofile`，再交给 `Scripts/package-release.sh` 公证打包。

开发构建位于 `.build/xcode/Build/Products/Debug/AetherZip.app`。Finder 服务需要应用安装到 Applications 目录，最终候选包在干净 VM 中安装于 `/Applications/AetherZip.app`。不会更改已有压缩软件的默认文件关联。

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
加密不包含密码破解。修改密码、删除归档内项目、归档修复不属于本次能力范围。

## Finder 扩展

主应用嵌入 `AetherZipFinderActions`。第一次使用时，在系统设置 → 通用 → 登录项与扩展 → 访达中启用「AetherZip 压缩与解压」。本机已启用并完成实际点击验收。

快速操作面板展示所选文件名或项目数量；文件准备完成前禁用操作，单个受支持归档才启用“打开归档 / 解锁”。一键执行由「服务」菜单提供，完整格式和加密选项由快速操作面板进入主程序。

开发时更改扩展激活规则后 Finder 可能缓存旧规则；退出空闲测试请求、重新注册本机安装包并重启 Finder 后再验收。不要把构建目录中的副本作为正式安装入口。

## 验证范围与后续工作

- 最终安装包已在启用 Gatekeeper 的 macOS 27 干净 VM 完成安装、Finder 单文件/多文件、加密解锁与解压验收；macOS 26 原生 UI 仍待补充。
- 多 GB 完整性及资源预算已复测，4 GiB 加密压缩峰值约 669 MiB、解压约 281 MiB；macOS 26 / 14 GiB 与 7 GiB CI 均已通过，8 GiB 真机体验仍待验证。见 [复测报告](docs/PERFORMANCE-RESOURCE-BUDGET.md)。
- 持续扩展恶意归档与跨工具兼容样本；已有覆盖及低磁盘空间结果见验收记录。
- 提取进程当前使用系统 `sandbox-exec` 收紧文件写入范围；需验证后续系统兼容性并评估专用沙盒 worker。
- Keychain 保存、重启后系统认证读取、取消认证与解压已在 macOS 27 VM 验证；Touch ID 仍待支持指纹的真机验收。
- 公开下载已用未登录请求验证，DMG SHA-256、公证、深度签名与挂载内容均通过。
- 更新签名与发布验收步骤见 [发布检查单](docs/RELEASE-CHECKLIST.md)，各版本的验证范围以对应记录为准。

详细验证记录见 [docs/VALIDATION.md](docs/VALIDATION.md)，第三方来源见 [THIRD_PARTY.md](THIRD_PARTY.md)。
