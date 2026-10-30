# 外接屏下拉日历红字清晰度后续

作者：wwj

## 目标

- 继续处理外接屏上红字比白字发虚的问题。
- 保留已完成的面板透明度与每次打开回到今天的修改。
- 构建并运行 Debug 版，等待实际外接屏视觉确认后再考虑发布。

## TODO

- [x] 核对上次会话、工作区改动和实际渲染路径。
- [x] 检查原始截图与当前显示器数据。
- [x] 做应用侧最小调整。
- [x] 完成 Debug 构建与改动检查。
- [x] 启动更新后的 Debug 应用。
- [x] Debug 运行后，用户明确授权发布。

## 证据与边界

- 上次会话最后没有落地红字修复；当前月份/年份标题由 `AppMenuControl` 自绘，展开选项仍使用原生 `NSMenu`。
- `/tmp/calendarx-popover-1129.png` 为 2026-10-30 18:47 的原始截图；它呈现的是整个日历面板，没有展开月份/年份选项，不能据此认定原生子菜单是根因。
- 当前 IORegistry 显示 `U27U2G6R4B` 为 3840×2160、DP 连接，支持多种 `PixelEncoding`。未读取到当前有效的色彩编码，不能确认色度抽样。
- UI 工具连接菜单栏 Debug 应用连续超时；Finder 可以读取，但这不能证明 CalendarX 的视觉结果。

## 实现

- 深色主题红色由 `#FF7770` 调整为 `#FFABA4`，增加亮度并降低饱和度，以改善半透明背景上的红字对比度。
- 浅色主题红色保留；不修改系统显示设置、菜单结构或字体平滑全局开关。
- 这是应用侧对比度改善，是否消除外接屏发虚仍需实际屏幕确认。

## 验证

- `xcodebuild -project CalendarX.xcodeproj -scheme CalendarX -configuration Debug -derivedDataPath /tmp/CalendarX-DerivedData CODE_SIGNING_ALLOWED=NO build` 成功。
- 首次沙箱构建被 SwiftPM 缓存写入权限阻止；经授权在沙箱外重试成功。
- `CODE_SIGNING_ALLOWED=NO` 仅用于本地 Debug 编译；未进行发布签名、版本升级或发布。
- `git diff --check` 通过。
- 按 sRGB 线性化计算，旧深色红色相对亮度为 0.3562，新色为 0.5307，提高约 49%；这不是屏幕清晰度测量。
- 已停止旧 Debug 进程 15551，通过 UI 工具启动更新后的同一路径应用。
- `pgrep` 确认新 Debug 进程为 28198，路径为 `/private/tmp/CalendarX-DerivedData/Build/Products/Debug/小日历.app/Contents/MacOS/小日历`。
- UI 工具在启动后的界面读取仍超时，未获取更新后的 CalendarX 截图，未完成工具侧实屏和重复打开验证。
- 用户后续要求重新编译并运行 Debug，构建成功，确认新进程为 31003。
- 用户随后明确要求发布新版本并提交代码；本次修改已随 `v3.0.2` 发布，验证记录见 `tasks/release-3.0.2-2026-10-30.md`。
