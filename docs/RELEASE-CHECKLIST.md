# 正式版发布检查单

1. 同步远程状态，确认版本号、构建号与本次代码一致；保留已有本地改动和回退包。
2. 运行核心及应用状态测试、macOS 26 CI、Windows / Linux 格式互通；记录当前候选包 UI 验收，历史结果不替代本轮验证。
3. 使用自动签名执行 Archive，再以 Developer ID 导出；核对 arm64、macOS 26.0、应用与扩展权限和 provisioning profile。
4. 执行 `Scripts/package-release.sh`，验证应用和 DMG 公证、签名、卷名与 Applications 链接。脚本拒绝覆盖同版本候选目录。
5. Sparkle 签名使用本机钥匙串账号 `AetherZip`，工具 `sign_update --account AetherZip`；不要导出私钥到仓库或日志。核对包内公钥、官网公钥和资产签名一致。
6. 官网加入版本记录、签名 appcast 和当前实机截图；检查中英文页面、图片和下载跳转。
7. 发布后下载公开 DMG 比对 SHA-256，实测旧安装版检查更新、安装和重启后的版本。若轮换 EdDSA 密钥，必须保持原 Developer ID 证书并验证更新路径。
8. 保留唯一候选包、测试证据和必要回退包，清理本轮构建缓存与临时样本；不得清空整个 `.build`。

macOS 26 原生 UI、Touch ID 和 8 GiB 真机体验仅在实机验证后才可标记完成。

---

以下为历史 Beta 发布记录，不代表当前候选版本的验收状态。

# 0.1.0 Beta 1 发布交接

当前状态：**0.1.0 Beta 1 已于 2026-10-13 公开发布，官网已上线，发布与清理检查完成。** Build 13 的安装、Finder 单文件/多文件、钥匙串系统认证及解压校验通过；公开下载哈希、公证和签名验证通过。Touch ID、macOS 26 原生 UI 与 8 GiB 真机体验仍待补充。测试 VM 的公开测试密码钥匙串条目保留，需使用者另行移除。

## 固定候选包

- 版本 `0.1.0 Beta 1`，构建 `2026101213`，仅 arm64，最低 macOS 26.0。
- 文件 `AetherZip-0.1.0-beta.1-arm64.dmg`，3,418,033 字节。
- SHA-256 `92eff256df0b110a1c8d2220e1405385b58d1a0b88c4c669ae21a6bd812e5f06`。
- 本地保留于 `.build/releases/0.1.0-beta.1-2026101213/`。请勿清空整个 `.build`：其中还保存验收记录、安装回退包。官网独立 Git worktree 已在合并后移除。
- [GitHub 公开 Beta](https://github.com/bcblr1993/AetherZip/releases/tag/v0.1.0-beta.1)，标签固定在 `f0e9c77`，应用代码与验收版本一致。
- 应用代码对应提交 `6e9ce1ffa2f5ae2b54e3b41386a05e2ed1ca1a30`；随后提交只涉及测试及文档。正式发布时固定已核对的提交，不依赖未来会移动的 main。
- [官网 PR #12](https://github.com/bcblr1993/aethernative-site/pull/12) 已合并，生产提交 `ed748bd44ff86c177eb96b539e4b3aa7baa6943c`；[AetherZip 官网](https://aethernative.com/apps/aetherzip/) 已验证正式下载 302。

## 已有证据

- [macOS 26 CI](https://github.com/bcblr1993/AetherZip/actions/runs/38231769829)：12 组核心测试、7 GiB M1 虚拟机的 2 GiB 加密归档往返及资源检查、应用与扩展构建均通过。
- [Windows / Linux CI](https://github.com/bcblr1993/AetherZip/actions/runs/38219295997)：Windows ZIP/7z/分卷及反向加密，Linux GNU tar 四种 TAR 格式的双向互通均通过。
- 应用、DMG 的 Apple 公证、stapler 和签名验证通过；实查卷名、Applications 链接和三个可执行文件的 arm64 架构。
- 官网最终生产构建：213 项测试、413 个页面、13,500 个站内链接、3 个签名清单、549 个数据接口本站地址检查全部通过。
- 详细的多 GB、正常退出、低磁盘空间与历史 Finder UI 测试见 [VALIDATION.md](VALIDATION.md)。这些结果不替代当前候选包的首次安装验收。

## 安装验收流程（已完成，真机限制另列）

只使用生成的测试文件与测试密码；不得接管其他产品正在显示的系统授权弹窗。

1. 在用户允许使用的干净 Mac / VM 上记录系统版本与芯片。保持系统安全保护启用，下载或传入上述同一 DMG，核对 SHA-256；不能通过关闭 Gatekeeper 或删除 quarantine 来获得通过。
2. 从 DMG 拖入 Applications，再启动安装副本。确认没有“损坏”或无法验证开发者提示，设置显示 `0.1.0 · Beta 1`；从包内 Info.plist 确认 build `2026101213`。
3. 使用者在系统设置启用 AetherZip Finder 扩展。验证单文件、多文件和文件夹右键压缩，以及加密归档解锁、解压；原始文件与同名目录不被覆盖。
4. 使用小型中英文测试目录完成普通 ZIP 和隐藏文件名的加密 7z；错误密码应失败，正确密码可恢复。关闭主窗口后，从 Finder 再次唤起主程序。
5. 使用者明确选择保存公开测试密码后，验证 Keychain 保存与重新读取、认证取消及重新认证。Touch ID 需要支持它的真实设备；VM 验证不能冒充 Touch ID 验收。使用者自行完成系统认证，不记录系统密码。
6. 确认退出后没有活动引擎、未发布的输出或本次 staging；清理本次生成的文件，并由使用者移除测试用钥匙串条目。将结果追加到 VALIDATION.md，保留必要截图和哈希证据。

8 GiB 真机整机体验、macOS 26 原生 UI 尚无完整验收证据；如使用 macOS 27 VM 验收，必须继续保留这一限制，不把 CI 构建通过表述为 macOS 26 UI 已验收。

## 本次已完成的上线顺序

1. 核对候选包未变、GitHub 资产 digest 与官网 SHA 一致、远程提交正确。若产品代码或二进制变动，更新构建号并重签名、公证、验证，不覆盖已有验收证据。
2. 公开 GitHub prerelease。以未登录请求验证正式资产下载；下载一份 DMG 核对 SHA-256、公证与挂载内容，检查对应源码及许可证附件可用。
3. 重新检查官网 PR 与当时 main 的差异和检查结果，再合并。等待生产部署；实查中英文产品页、版本/帮助/隐私页、反馈产品预选与正式域名下载 302，最终目标必须是已公开资产。
4. 下载与挂载验证结束后卸载测试镜像、删除本次下载副本；保留唯一候选包、验收证据和必要回退包。停止临时服务，清理本次构建缓存。不要将删除缓存描述成可以保证 SSD 不损坏。

出现安装、签名或数据完整性失败时继续保留草稿，修复后重新验收；不能把生成安装包或绿色 CI 当作发布完成。
