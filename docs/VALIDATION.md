# 开发版验收记录

日期：2026-10-12。设备环境：Apple Silicon、macOS 27、Xcode 27.0。

## 自动验证

`swift test`：10 组 XCTest 通过（最近一次完整运行 13.7 秒）。

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

六种创建格式均覆盖目录浏览和内部单文件提取，压缩 TAR 直接展示内部内容，不把中间 TAR 当成最终文件列表。XZ/BZIP2/Zstandard 没有目录文件名时从流名称推导；未知原始大小在界面显示为未知。

元数据测试检查 `.DS_Store` 和 AppleDouble 附属文件不进入包内，而 `.env` 与真实 `._real.txt` 保留；源目录没有修改。

`xcodebuild` Debug 和 Release 构建均通过；最终 Release 版本 `0.1.0 (2026101208)`，含扩展和引擎约 6.1 MiB。`codesign --verify --deep --strict` 签名检查通过。
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

这是开发版验收，不代表公开发布验收。macOS 26、跨平台接收端、全部引擎支持格式、大文件长期运行、公证下载安装和自动更新尚未完成。
Finder 快速操作和 NSServices 两类右键入口均已通过上述实测；首次安装仍需在系统设置中允许该 Finder 扩展。

参考 Apple 官方：[系统服务](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html)、[Finder Action Extensions](https://developer.apple.com/documentation/appkit/add-functionality-to-finder-with-action-extensions)。

## 后续多 GB 性能验收

2026-10-12 新增 4 GiB 随机数据（ZIP64 / 加密 7z）、8 GiB 高重复数据（7z / TAR.XZ）和 10,000 文件共 2.44 GiB 的往返与 SHA-256 验证，五组通过。原生 UI 的 4 GiB 任务暂停/继续/取消亦通过。

发现默认 7z 大包压缩/解压峰值 RSS 约 2.6 GiB，应在正式发布前补资源预算及低内存机型验收；限制解压线程的测试副本已显示明显降内存效果，但未合入。详细口径和原始汇总见 [性能报告](PERFORMANCE-2026-10-12.md)。
