# 0.1.0 Beta 1 发布交接

当前状态：安装验收已恢复并修复 Finder 文件打开及钥匙串签名问题。Build 13 公证、安装、密码保存和取消认证通过，系统认证后读取仍待用户配合；GitHub Release 和官网 PR 保持草稿。未完成下面的安装验收前，不公开安装包、不合并官网。

## 固定候选包

- 版本 `0.1.0 Beta 1`，构建 `2026101213`，仅 arm64，最低 macOS 26.0。
- 文件 `AetherZip-0.1.0-beta.1-arm64.dmg`，3,418,033 字节。
- SHA-256 `92eff256df0b110a1c8d2220e1405385b58d1a0b88c4c669ae21a6bd812e5f06`。
- 本地保留于 `.build/releases/0.1.0-beta.1-2026101213/`。请勿清空整个 `.build`：其中还保存验收记录、安装回退包和独立的官网 Git worktree。
- GitHub 草稿：`bcblr1993/AetherZip`，标签 `v0.1.0-beta.1`。草稿 URL 可能随编辑变化，使用 `gh release view v0.1.0-beta.1 --repo bcblr1993/AetherZip` 定位。
- 应用代码对应提交 `6e9ce1ffa2f5ae2b54e3b41386a05e2ed1ca1a30`；随后提交只涉及测试及文档。正式发布时固定已核对的提交，不依赖未来会移动的 main。
- [官网草稿 PR #12](https://github.com/bcblr1993/aethernative-site/pull/12)，[分支预览](https://145f7f82.aethernative.pages.dev/apps/aetherzip/)。分支预览已验证 302 下载跳转；草稿资产尚不能公开下载。

## 已有证据

- [macOS 26 CI](https://github.com/bcblr1993/AetherZip/actions/runs/38219295320)：12 组核心测试、7 GiB M1 虚拟机的 2 GiB 加密归档往返及资源检查、应用与扩展构建均通过。
- [Windows / Linux CI](https://github.com/bcblr1993/AetherZip/actions/runs/38219295997)：Windows ZIP/7z/分卷及反向加密，Linux GNU tar 四种 TAR 格式的双向互通均通过。
- 应用、DMG 的 Apple 公证、stapler 和签名验证通过；实查卷名、Applications 链接和三个可执行文件的 arm64 架构。
- 官网 192 项测试、381 个页面构建和全部本地链接检查通过，Cloudflare 分支预览部署成功。
- 详细的多 GB、正常退出、低磁盘空间与历史 Finder UI 测试见 [VALIDATION.md](VALIDATION.md)。这些结果不替代当前候选包的首次安装验收。

## 待用户配合的验收

只使用生成的测试文件与测试密码；不得接管其他产品正在显示的系统授权弹窗。

1. 在用户允许使用的干净 Mac / VM 上记录系统版本与芯片。保持系统安全保护启用，下载或传入上述同一 DMG，核对 SHA-256；不能通过关闭 Gatekeeper 或删除 quarantine 来获得通过。
2. 从 DMG 拖入 Applications，再启动安装副本。确认没有“损坏”或无法验证开发者提示，设置显示 `0.1.0 · Beta 1`；从包内 Info.plist 确认 build `2026101213`。
3. 使用者在系统设置启用 AetherZip Finder 扩展。验证单文件、多文件和文件夹右键压缩，以及加密归档解锁、解压；原始文件与同名目录不被覆盖。
4. 使用小型中英文测试目录完成普通 ZIP 和隐藏文件名的加密 7z；错误密码应失败，正确密码可恢复。关闭主窗口后，从 Finder 再次唤起主程序。
5. 使用者明确选择保存公开测试密码后，验证 Keychain 保存与重新读取、认证取消及重新认证。Touch ID 需要支持它的真实设备；VM 验证不能冒充 Touch ID 验收。使用者自行完成系统认证，不记录系统密码。
6. 确认退出后没有活动引擎、未发布的输出或本次 staging；清理本次生成的文件，并由使用者移除测试用钥匙串条目。将结果追加到 VALIDATION.md，保留必要截图和哈希证据。

8 GiB 真机整机体验、macOS 26 原生 UI 尚无完整验收证据；如使用 macOS 27 VM 验收，必须继续保留这一限制，不把 CI 构建通过表述为 macOS 26 UI 已验收。

## 验收通过后的上线顺序

1. 核对候选包未变、GitHub 资产 digest 与官网 SHA 一致、远程提交正确。若产品代码或二进制变动，更新构建号并重签名、公证、验证，不覆盖已有验收证据。
2. 公开 GitHub prerelease。以未登录请求验证正式资产下载；下载一份 DMG 核对 SHA-256、公证与挂载内容，检查对应源码及许可证附件可用。
3. 重新检查官网 PR 与当时 main 的差异和检查结果，再合并。等待生产部署；实查中英文产品页、版本/帮助/隐私页、反馈产品预选与正式域名下载 302，最终目标必须是已公开资产。
4. 下载与挂载验证结束后卸载测试镜像、删除本次下载副本；保留唯一候选包、验收证据和必要回退包。停止临时服务，清理本次构建缓存。不要将删除缓存描述成可以保证 SSD 不损坏。

出现安装、签名或数据完整性失败时继续保留草稿，修复后重新验收；不能把生成安装包或绿色 CI 当作发布完成。
