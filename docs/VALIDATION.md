# AetherZip 验收记录

日期：2026-10-12。设备环境：Apple Silicon、macOS 27、Xcode 27.0。

## 自动验证

`swift test`：12 组 XCTest 通过；资源预算改动后的本机完整运行约 14.3 秒，macOS 26 CI 亦通过。

1. ZIP、7z、TAR、TAR.GZ、TAR.XZ、TAR.BZ2 往返；中文和 emoji 文件夹；实际内容一致。
2. ZIP ASCII 密码与 7z 中文密码加解密；错误密码失败；7z 隐藏目录。
3. 已存在输出不覆盖；取消后不发布半成品。
4. 实际恶意 ZIP 中的 `../` 路径被拒绝。
5. 按指定文件选择性解压。
6. RAR、RAR5 样例解压；两种 RAR 加密样例的指定文件密码解压。
7. TAR 内部合法软链接保留；越界软链接归档被拒绝。
8. 7z 三分卷重组内容一致；文件名中的 `*` 按字面选择，不扩大解压范围。
9. 独立 GZIP / XZ / BZIP2 浏览和指定文件提取；空 ZIP 浏览及解压。
10. Zstandard 单文件流和 TAR.ZST 的逻辑浏览、指定文件提取及内容一致性。

11. 8 GiB 资源策略的线程/字典参数，以及 7z / TAR.XZ 的 0、1、9 压缩等级实际往返。
12. 正在压缩时取消，确认源文件不变、输出与 staging 均不存在。

六种创建格式均覆盖目录浏览和内部单文件提取，压缩 TAR 直接展示内部内容，不把中间 TAR 当成最终文件列表。XZ/BZIP2/Zstandard 没有目录文件名时从流名称推导；未知原始大小在界面显示为未知。

元数据测试检查 `.DS_Store` 和 AppleDouble 附属文件不进入包内，而 `.env` 与真实 `._real.txt` 保留；源目录没有修改。

`xcodebuild` Debug 和 Release 构建均通过；初次 Finder UI 验收的 Release 版本 `0.1.0 (2026101208)`，含扩展和引擎约 6.1 MiB。`codesign --verify --deep --strict` 签名检查通过。
最低部署目标 macOS 26.0；实际交付的主程序、Finder 扩展和压缩引擎仅 arm64。Release 未携带 `get-task-allow` 调试权限。

## 真实 UI 操作

- 原生选择文件 → 创建 ZIP → 任务完成 → Finder 显示生成文件。
- Finder 右键「服务」出现全部 5 个 AetherZip 操作。
- 实际点击右键解压，生成独立 `Input (2)` 文件夹，原 `Input` 保持不变；读取解压结果验证内容。
- 实际点击右键 7z 压缩，轻量任务浮窗显示完成，生成真实 `.7z`。
- 实际点击右键加密，创建隐藏文件名的 7z，打开时要求密码；输入测试密码后显示归档内容。
- 错误密码在面板内提示；再次输入正确密码后恢复浏览。
- 浅色/深色窗口完成截图检查；关闭主窗口后，Finder 加密服务可以重新打开设置面板。

- Release 版创建 128 MiB 随机数据的高压缩率任务，实际暂停/继续/取消均正常；暂停时 `7zz` 进程状态为 `T`，CPU 为 0；取消后输出不存在，私有 staging 目录为 0，源文件仍为 134217728 字节。这是响应与取消验收，不是跨设备性能基准。

## Finder 快速操作验收

- 快速操作菜单和 Finder 预览栏均显示 AetherZip；接受文件、文件夹和混合多选。
- 右键 PNG → 操作面板 → 创建 ZIP，UI 显示完成；用 Python `zipfile` 独立读取并逐字节对比，源文件仍在。
- 加密 7z → 面板 → 解锁 → 显示 `说明.txt` → 解压完成；输出与原文一致，原加密包仍在。
- 最终构建右键未预先选中的加密 7z，面板准确显示被右键文件名，进入相同文件的密码面板。
- 最终构建同时选择 PNG 和文件夹 → 面板显示 2 个项目 → TAR.XZ → 完成；用 Python `tarfile` 独立读取两项并逐字节对比，两个来源仍在。
- 采用 AppKit 主线程视图生命周期读取 extensionContext，修复后台 XPC 调用 MainActor 的崩溃。
- 扩展交接主程序后用用户取消语义结束 Finder 编辑事务，不返回空替换结果，不让 Finder 删除或替换原文件。
- 排查期间安装的 Apple 示例应用已移出 Applications，示例扩展已注销。

## 验收限制

早期 UI 验收发生在 macOS 27，本记录不代表所有发布门槛已经通过。macOS 26 原生界面、全部引擎支持格式、8 GiB 真机、公证包首次安装及 Keychain / Touch ID 验收仍待完成。首版不包含自动更新。
Finder 快速操作和 NSServices 两类右键入口均已通过上述实测；首次安装仍需在系统设置中允许该 Finder 扩展。

参考 Apple 官方：[系统服务](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html)、[Finder Action Extensions](https://developer.apple.com/documentation/appkit/add-functionality-to-finder-with-action-extensions)。

## 后续多 GB 性能验收

2026-10-12 新增 4 GiB 随机数据（ZIP64 / 加密 7z）、8 GiB 高重复数据（7z / TAR.XZ）和 10,000 文件共 2.44 GiB 的往返与 SHA-256 验证，五组通过。原生 UI 的 4 GiB 任务暂停/继续/取消亦通过。

初测默认 7z 大包峰值 RSS 约 2.6 GiB。资源预算现已合入并复测：4 GiB 加密 7z 压缩约 669 MiB、解压约 281 MiB；压缩耗时由约 64 秒增加到约 119 秒。完整口径见 [资源预算复测](PERFORMANCE-RESOURCE-BUDGET.md)，初测留档见 [性能报告](PERFORMANCE-2026-10-12.md)。

## 正常退出与磁盘不足

- build 2026101209 的真实 4 GiB 最高等级压缩在暂停时执行 Cmd-Q：主进程与引擎结束，输出和 staging 不存在，源文件 SHA-256 不变。正常退出会等待清理；强制结束或断电不在这一保证内。
- 在单独的 64 MiB HFS+ 稀疏镜像内解压 128 MiB 文件：返回磁盘空间不足，无最终输出、无 staging，输入归档 SHA-256 不变。镜像已卸载，测试源文件及镜像已清理；未填满宿主磁盘。
- 多 GB 基准每组完成后删除输出，全部结束后删除输入，只保留小型校验清单、日志和汇总。


## Windows 双向互通

[CI 38218887777](https://github.com/bcblr1993/AetherZip/actions/runs/38218887777) 三阶段全部通过：macOS 26 产品核心创建 → Windows Server 2025 / 7-Zip 26.03 验证 → macOS 26 产品核心解压 Windows 创建的加密包。

- 普通 ZIP、AES ZIP、隐藏文件名的加密 7z、三分卷 7z：Windows 7-Zip 解压后路径与 SHA-256 全部一致。
- Windows PowerShell `Expand-Archive` 解压普通 ZIP，通过同样校验。
- Windows 7-Zip 创建 AES ZIP 与隐藏文件名的 7z，产品核心反向解压与原始目录逐文件一致。
- 样本包含中文、emoji、`.env`、真实 `._` 文件；Mac 附属文件未进入输出。
- 不代表 WinRAR GUI、所有 Windows 版本或所有第三方工具都已经测试。仅传递自动生成的公开测试数据，CI 附件保留一天。

## Beta 1 候选安装包

- `0.1.0 (2026101211)`，产品代码提交 `df89f3f3d1964ba2c87fa57b111a89b0067abe86`，之后仅新增互通测试和文档。
- 应用公证 Accepted：`0bf7acac-08f8-4a28-93f9-32766e10d794`；DMG 公证 Accepted：`28a1f1a0-6fa1-49a4-9a20-e8769a2d7aa6`。
- DMG SHA-256：`55e64dc07c52664b68ef2879d1025c349583ca1fbcd30eda729c630b69b8aac5`。
- 实际挂载卷名 `AetherZip 0.1.0 Beta 1`，仅包含应用、指向 `/Applications` 的链接和安装说明。应用及 DMG stapler 验证通过，三种可执行文件均为 arm64，深度签名验证通过，测试后已卸载镜像。
- 修正了图标染色覆盖为白色方块的问题，实查生成图标和官网预览。
- GitHub 保持草稿；首次安装、系统安全检查、Finder 扩展启用与 Keychain / Touch ID 需要后续用户配合。宿主已关闭 Gatekeeper，不能用宿主启动替代干净环境验收。官网上线等待该门槛。


## Linux TAR 双向互通

[CI 38219295997](https://github.com/bcblr1993/AetherZip/actions/runs/38219295997) 在 Ubuntu 24.04 与 macOS 26 之间全部通过，同时重跑 Windows 互通通过。

| 格式 | AetherZip 创建 → Linux GNU tar 解压 | Linux GNU tar 创建 → AetherZip 浏览和解压 |
| --- | --- | --- |
| TAR | 通过 | 通过 |
| TAR.GZ | 通过 | 通过 |
| TAR.XZ | 通过 | 通过 |
| TAR.BZ2 | 通过 | 通过 |

正向检查中文、emoji、空格与隐藏文件路径、内容 SHA-256，以及 Mac 杂项过滤。反向使用 GNU tar PAX 格式，额外验证超过 100 字符的路径、空目录、可执行文件权限、安全相对软链接目标，并确认解压后临时目录清理。互通数据约 2 MiB，属于格式兼容性测试；多 GB 性能结论来自另列的大文件基准，不混为同一次测试。


## 最终 macOS 26 回归

[运行 38219295320](https://github.com/bcblr1993/AetherZip/actions/runs/38219295320) 的最终回归分配到 **M1 Virtual / 7 GiB RAM / macOS 26.6.2**：12 组核心测试、主程序和 Finder 扩展 Release 构建通过；2 GiB+64 KiB 随机加密 7z 压缩 188.145 秒、解压 2.849 秒，峰值 RSS 206.34 / 99.16 MiB，路径与 SHA-256 校验通过，生成数据清理通过。该结果实际触发了 8 GiB 及以下的双线程策略；虚拟机耗时不能直接作为消费级真机速度承诺。
