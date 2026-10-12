# Aether Native 接入约定

当前 Beta 候选版本与现有网站生态采用以下一致方向：

- 产品名称 AetherZip，品牌署名 Aether Native，bundle ID `com.aethernative.AetherZip`。
- SwiftUI / AppKit 原生客户端；本地处理、隐私优先；macOS 26+，arm64-only。
- 蓝紫色主色、轻盈单窗口、系统玻璃材质；网站用于介绍、下载、版本与支持，客户端不嵌入网页壳。
- 保留原网站工作区已有改动，在独立分支 `codex/aetherzip-beta-1` 接入产品页、版本记录、帮助、隐私、下载统计和反馈归属；[官网 PR #12](https://github.com/bcblr1993/aethernative-site/pull/12) 保持草稿。
- 沿用现有账户及反馈系统，没有新增支付或授权产品；首版手动下载更新，不提供 Sparkle feed。

官网分支预览已经部署，正式域名尚未开放 AetherZip 页面。GitHub 公证安装包保留为发布草稿；安装与 Finder 扩展验收通过后，先开放 GitHub 下载，再合并官网并验证生产下载跳转。

应用官网和支持菜单已指向 `/apps/aetherzip/` 与 `/apps/aetherzip/support/`。完整门槛和顺序见 [发布交接](RELEASE-CHECKLIST.md)；未上线前这些正式域名地址尚不可用。
