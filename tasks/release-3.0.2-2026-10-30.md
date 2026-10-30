# 小日历 3.0.2 发布

作者：wwj

## 目标

提交本次面板透明度、日期重置和深色红字对比度修改，发布小日历 3.0.2 通用 DMG，并更新 Sparkle 自动更新源。

## TODO

- [x] 核对改动、现有发布、版本、签名和更新源。
- [x] 主应用和两个扩展统一更新为 3.0.2 (74)，更新中英文 changelog。
- [x] 提交并推送源码。
- [x] 完成 Release 通用构建、版本和代码签名检查。
- [x] 创建 DMG，挂载检查并校验 Sparkle EdDSA 签名。
- [x] 创建 GitHub 草稿 Release，验证目标提交、附件大小及摘要。
- [x] 更新 Sparkle appcast 并正式发布。
- [x] 验证公开下载和线上更新源，提交发布记录。

## 发布边界

- 仓库：`dzfly/CalendarX`；分支：`master`；标签：`v3.0.2`。
- 用户要求运行 Debug 后，已明确要求发布新版本并提交代码；本次执行该发布授权。
- 沿用既有 Apple Development 证书与 Sparkle Keychain 密钥，不导出私钥；不宣称 Developer ID 公证。
- 使用独立 `build/release-3.0.2/` 目录，保留旧版安装包和更新条目。
- 发虚原因中的显示链路因素尚未确认；发布说明只描述实际对比度调整。
- UI 工具未取得新版外接屏截图，Debug 启动和编译检查不等同于工具完成实屏验收。

## 构建和安装包验证

- 源码提交：`b445a871672a98bc8f6db89df13608eb4640a43c`，已推送到 `master`，Release 标签指向该提交。
- Release 构建成功；主应用、Widget 和 Intent Extension 均为 `3.0.2 (74)`、最低 macOS 12.0，均含 `x86_64 arm64` 架构。
- 主应用 `codesign --verify --deep --strict` 通过。
- 构建日志：`/tmp/calendarx-3.0.2-build.log`。
- 安装包：`build/release-3.0.2/CalendarX.dmg`，6,547,155 字节。
- SHA-256：`640fc4ce6b4e0e0a89930a4cc1a38721d34201264f4180046b8f52cc794d225c`。
- DMG 代码签名和镜像完整性验证通过。
- 只读挂载后验证主应用和扩展版本、应用签名及 `/Applications` 安装快捷入口；验证后已卸载镜像。
- 使用现有 Keychain 密钥生成 Sparkle EdDSA 签名，以应用 `SUPublicEDKey` 独立验签通过。

## 在线验证

- Release：`https://github.com/dzfly/CalendarX/releases/tag/v3.0.2`，非草稿、非预发布，GitHub latest 已指向该版本。
- 下载：`https://github.com/dzfly/CalendarX/releases/download/v3.0.2/CalendarX.dmg`。
- 草稿阶段验证远程目标提交、附件大小和摘要，并下载远程附件完成摘要与 EdDSA 校验。
- 正式发布后从公开地址重新下载，大小、SHA-256 与本地包一致。
- 自动更新提交：`f957ab9`，已推送至 `master`。
- 从应用配置的公开 appcast URL 读取线上 XML，确认 `3.0.2 (74)`、最低 macOS 12.0、附件 URL、大小和更新签名正确；以线上签名对公开下载包验签通过。
- 旧版 Release、更新条目和本地 DMG 保留。
