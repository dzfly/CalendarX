# 小日历 - Sparkle 自动更新配置指南

## 概述
小日历已集成 Sparkle 框架来实现自动更新功能。用户可以通过以下方式检查和安装更新：

1. **自动检查**：每24小时自动检查一次更新
2. **手动检查**：在设置页面点击"检查更新"按钮
3. **右键菜单**：右键点击菜单栏图标，选择"检查更新"

## 配置步骤

### 1. 生成 Sparkle 密钥对
```bash
./generate_keys.sh
```
这将下载 Sparkle 工具并生成 EdDSA 密钥对。

### 2. 更新 Info.plist
将生成的公钥添加到 `CalendarX/Info.plist`：
```xml
<key>SUPublicEDKey</key>
<string>你的公钥</string>
```

修改 appcast URL：
```xml
<key>SUFeedURL</key>
<string>https://你的用户名.github.io/CalendarX/appcast.xml</string>
```

### 3. 配置 GitHub Pages
1. 在 GitHub 仓库设置中启用 GitHub Pages
2. 将 `appcast.xml` 文件放在仓库根目录
3. 确保 GitHub Pages 可以访问该文件

### 4. 发布新版本
1. 创建新的 Git tag：`git tag v2.4.0`
2. 推送 tag：`git push origin v2.4.0`
3. GitHub Actions 将自动构建并发布 DMG
4. 使用私钥签名 DMG 文件
5. 更新 appcast.xml 文件

## 功能特性

### 用户界面
- ✅ 设置页面中的更新选项
- ✅ 自动检查更新开关
- ✅ 包含测试版本选项
- ✅ 手动检查更新按钮
- ✅ 版本信息显示
- ✅ 上次检查时间显示

### 菜单栏集成
- ✅ 右键菜单包含"检查更新"选项
- ✅ 应用名称显示为"小日历"
- ✅ 退出选项显示为"退出小日历"

### 通知系统
- ✅ 发现更新时显示系统通知
- ✅ 点击通知可打开更新对话框
- ✅ 自动请求通知权限

### 本地化支持
- ✅ 中文界面文本
- ✅ 英文界面文本
- ✅ 日期格式本地化

## 测试更新功能

运行测试脚本检查配置：
```bash
./test_update.sh
```

### 手动测试步骤
1. 构建并运行应用
2. 右键点击菜单栏图标，验证右键菜单
3. 打开设置 → 更新，测试各项功能
4. 检查通知权限是否正确请求
5. 验证版本信息显示正确

## 文件结构
```
CalendarX/
├── Info.plist                          # 应用配置，包含Sparkle设置
├── Utility/Updater.swift               # 更新管理器
├── Module/Settings/UpdateScreen.swift  # 更新设置界面
├── Module/MenuBar/MenuBarController.swift # 菜单栏控制器（含右键菜单）
├── zh-Hans.lproj/Localizable.strings   # 中文本地化
├── en.lproj/Localizable.strings        # 英文本地化
└── ...

根目录/
├── appcast.xml                         # Sparkle appcast 文件
├── generate_keys.sh                    # 密钥生成脚本
├── test_update.sh                      # 测试脚本
└── scripts/create_dmg.sh               # DMG 创建脚本
```

## 注意事项

1. **安全性**：私钥必须安全保存，不要提交到版本控制
2. **签名**：每个发布的 DMG 都必须用私钥签名
3. **测试**：在发布前务必测试更新流程
4. **备份**：保存好密钥对的备份

## 故障排除

### 更新检查失败
- 检查网络连接
- 验证 appcast.xml URL 是否可访问
- 确认 appcast.xml 格式正确

### 通知不显示
- 检查系统通知权限
- 验证 `SUEnableAutomaticChecks` 设置
- 确认应用有通知权限

### 签名验证失败
- 检查公钥是否正确配置
- 验证 DMG 签名是否正确
- 确认私钥与公钥匹配