# 小日历 3.0.1 发布

作者：wwj

## 目标

发布包含红色文字清晰度优化的小日历 3.0.1 通用 DMG，并更新 Sparkle 自动更新源。

## TODO

- [x] 核对本地版本、远程发布、证书和 Sparkle 签名公钥。
- [x] 更新主应用和扩展版本为 3.0.1，构建号设为 73。
- [x] 完成 Release 通用构建和代码签名检查。
- [x] 打包 DMG，并生成和校验 Sparkle EdDSA 签名。
- [x] 发布 GitHub Release v3.0.1。
- [ ] 更新自动更新源并核对远程附件及 appcast。

## 发布边界

- 发布仓库：`dzfly/CalendarX`，分支：`master`。
- 使用本机现有 Apple Development 证书，不宣称 Developer ID 公证。
- 使用现有 Sparkle 密钥；不导出私钥。
- 保留旧版 Release 和本地旧版 DMG，便于回退。
- 显示链路色度抽样尚未确认；本次提供应用侧文字观感优化。

## 构建验证

- Xcode Release 构建成功，`x86_64 arm64` 通用架构。
- 主应用与两个扩展的版本、构建号均为 `3.0.1 (73)`，最低 macOS 12.0。
- `codesign --verify --deep --strict` 通过。
- 构建日志：`/tmp/calendarx-3.0.1-build.log`。

## 安装包验证

- 文件：`build/release-3.0.1/CalendarX.dmg`，7,511,430 字节。
- SHA-256：`8923e805776425f6a3b738c0bb31677fdc0744768f4f83d9d5a38544e9770eac`。
- DMG 代码签名、镜像校验、Sparkle EdDSA 验签均通过。
- 只读挂载后确认应用为 `3.0.1 (73)`，包含 Applications 安装快捷入口。

## 在线发布验证

- Release：`https://github.com/dzfly/CalendarX/releases/tag/v3.0.1`，正式发布。
- 标签提交：`f482cb6c29b991c3fbd6849bd7c51597d67682f1`。
- 下载：`https://github.com/dzfly/CalendarX/releases/download/v3.0.1/CalendarX.dmg`。
- 从公开下载地址取回 DMG，大小和 SHA-256 与本地安装包一致。
- 自动更新条目已完成 XML 检查，构建号、版本、最低系统、下载大小和签名均与安装包匹配。
