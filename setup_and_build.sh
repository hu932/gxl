#!/usr/bin/env bash
# 黄油可颂 · 一键构建 TrollStore 免签 IPA（在 macOS 上运行）
set -euo pipefail

echo "==> 检查 Flutter"
command -v flutter >/dev/null 2>&1 || { echo "未找到 flutter，请先安装 Flutter SDK"; exit 1; }

# 1) 若还没有 ios/ 脚手架，用 flutter create 生成（保留我们写好的 lib/ 与 pubspec.yaml）
if [ ! -d "ios" ]; then
  echo "==> 生成 iOS/Android 脚手架"
  flutter create . \
    --org com.buttercroissant \
    --project-name huangyou_kesong \
    --platforms ios,android
fi

# 2) 图标：替换 iOS AppIcon
echo "==> 写入图标"
rm -rf ios/Runner/Assets.xcassets/AppIcon.appiconset
cp -r icons/AppIcon.appiconset ios/Runner/Assets.xcassets/AppIcon.appiconset
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  cp -f "icons/android/mipmap-$d/ic_launcher.png" "android/app/src/main/res/mipmap-$d/ic_launcher.png"
done

# 3) Info.plist：显示名 + 允许 http + 相机/相册权限
echo "==> 配置 Info.plist"
INFO="ios/Runner/Info.plist"
P="/usr/libexec/PlistBuddy"
$P -c "Set :CFBundleDisplayName 黄油可颂" "$INFO" 2>/dev/null || \
  $P -c "Add :CFBundleDisplayName string 黄油可颂" "$INFO"
$P -c "Add :NSAppTransportSecurity dict" "$INFO" 2>/dev/null || true
$P -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$INFO" 2>/dev/null || true
$P -c "Add :NSCameraUsageDescription string 用于拍照提问" "$INFO" 2>/dev/null || true
$P -c "Add :NSPhotoLibraryUsageDescription string 用于选择题目图片" "$INFO" 2>/dev/null || true

# 4) 构建无签名 IPA（TrollStore 可直接安装）
echo "==> 拉取依赖"
flutter pub get
echo "==> 构建 IPA（--no-codesign）"
flutter build ipa --release --no-codesign

echo ""
echo "✅ 完成！IPA 在：build/ios/ipa/*.ipa"
echo "   把它传到 iPhone，用「巨魔 TrollStore」打开即可安装（免签名）。"
