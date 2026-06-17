#!/bin/bash

echo "=== 小日历更新功能测试 ==="
echo ""

# 检查Info.plist配置
echo "1. 检查Info.plist配置："
echo "   - SUEnableAutomaticChecks: $(defaults read $(pwd)/CalendarX/Info.plist SUEnableAutomaticChecks 2>/dev/null || echo '未设置')"
echo "   - SUFeedURL: $(defaults read $(pwd)/CalendarX/Info.plist SUFeedURL 2>/dev/null || echo '未设置')"
echo "   - CFBundleDisplayName: $(defaults read $(pwd)/CalendarX/Info.plist CFBundleDisplayName 2>/dev/null || echo '未设置')"
echo ""

# 检查Sparkle框架
echo "2. 检查Sparkle框架集成："
if grep -q "Sparkle" CalendarX.xcodeproj/project.pbxproj; then
    echo "   ✅ Sparkle框架已集成"
else
    echo "   ❌ Sparkle框架未找到"
fi
echo ""

# 检查更新相关文件
echo "3. 检查更新相关文件："
files=(
    "CalendarX/Utility/Updater.swift"
    "CalendarX/Module/Settings/UpdateScreen.swift"
    "appcast.xml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file 存在"
    else
        echo "   ❌ $file 不存在"
    fi
done
echo ""

# 检查本地化文件
echo "4. 检查本地化文件："
if grep -q "updater.title" CalendarX/zh-Hans.lproj/Localizable.strings; then
    echo "   ✅ 中文本地化已添加"
else
    echo "   ❌ 中文本地化缺失"
fi

if grep -q "updater.title" CalendarX/en.lproj/Localizable.strings; then
    echo "   ✅ 英文本地化已添加"
else
    echo "   ❌ 英文本地化缺失"
fi
echo ""

echo "=== 下一步操作建议 ==="
echo "1. 运行 ./generate_keys.sh 生成Sparkle密钥对"
echo "2. 将生成的公钥更新到Info.plist的SUPublicEDKey"
echo "3. 修改Info.plist中的SUFeedURL为你的实际appcast.xml地址"
echo "4. 构建并测试应用"
echo "5. 右键点击菜单栏图标测试右键菜单"
echo "6. 在设置中测试更新功能"
echo ""