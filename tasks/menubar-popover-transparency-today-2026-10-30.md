# 菜单栏下拉面板透明度与今日重置

作者：wwj

## 目标

- 菜单栏下拉面板增加一点透明度。
- 每次打开菜单栏下拉面板时，将日历选择同步重置到今天。

## TODO

- [x] 确认下拉面板背景与日期状态入口。
- [x] 调整 macOS 26 下拉面板背景透明度。
- [x] 在面板每次展示前重置日历日期。
- [x] 完成定向编译与改动范围检查。

## 实现

- 下拉面板背景填充透明度由 `0.6` 调整为 `0.5`。
- `MenubarPopover` 展示前发送 `.menubarPopoverWillShow` 通知。
- `RootScreen` 收到通知后同步设置 `mainVM.date = Date()`，不播放月份切换动画。

## 验证

- Debug 主应用构建成功：`xcodebuild -project CalendarX.xcodeproj -scheme CalendarX -configuration Debug -derivedDataPath /tmp/CalendarX-DerivedData CODE_SIGNING_ALLOWED=NO build`。
- `git diff --check` 通过。
- 修改的 Swift 文件有效行数均低于 300：`RootScreen.swift` 177、`MenubarPopover.swift` 93、`Constant.swift` 139。
