#!/usr/bin/env bash
# 黄油可颂 · 构建 TrollStore 免签 IPA（macOS）
set -uo pipefail

echo "==> 环境"
command -v flutter >/dev/null 2>&1 || { echo "未找到 flutter"; exit 1; }
flutter --version || true
xcodebuild -version || true

# 1) 脚手架
if [ ! -d "ios" ]; then
  echo "==> 生成 iOS/Android 脚手架"
  flutter create . \
    --org com.buttercroissant \
    --project-name huangyou_kesong \
    --platforms ios,android || exit 1
fi

# 2) 图标
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
$P -c "Set :CFBundleDisplayName 黄油可颂" "$INFO" 2>/dev/null \
  || $P -c "Add :CFBundleDisplayName string 黄油可颂" "$INFO" || true
$P -c "Add :NSAppTransportSecurity dict" "$INFO" 2>/dev/null || true
$P -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$INFO" 2>/dev/null || true
$P -c "Add :NSCameraUsageDescription string 用于拍照提问" "$INFO" 2>/dev/null || true
$P -c "Add :NSPhotoLibraryUsageDescription string 用于选择题目图片" "$INFO" 2>/dev/null || true

# 4) 【关键】关闭 Xcode 自动签名，否则免签构建会被"缺少 Development Team"拦住
echo "==> 关闭 Xcode 自动签名"
PBX="ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PBX" ]; then
  sed -i '' 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g' "$PBX"
  sed -i '' 's/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = "";/g' "$PBX"
  sed -i '' 's/PROVISIONING_PROFILE_SPECIFIER = [^;]*;/PROVISIONING_PROFILE_SPECIFIER = "";/g' "$PBX"
  echo "--- 签名相关设置 ---"
  grep -n 'CODE_SIGN_STYLE\|DEVELOPMENT_TEAM\|PROVISIONING_PROFILE_SPECIFIER' "$PBX" | head -20
fi

# 5) 依赖
echo "==> flutter pub get"
flutter pub get || exit 1

IPA=""

# 6) 方式1：flutter build ipa
echo "==> 方式1：flutter build ipa --release --no-codesign"
flutter build ipa --release --no-codesign
echo "方式1 退出码: $?"
if ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
  IPA=$(ls build/ios/ipa/*.ipa | head -1)
  echo "方式1 产出 IPA: $IPA"
fi

# 7) 方式2：flutter build ios + 手动打包
if [ -z "$IPA" ]; then
  echo "==> 方式2：flutter build ios --release --no-codesign + 手动打包"
  flutter build ios --release --no-codesign
  echo "方式2 退出码: $?"
  APP="build/ios/iphoneos/Runner.app"
  if [ -d "$APP" ]; then
    rm -rf Payload build/ios/ipa
    mkdir -p Payload build/ios/ipa
    cp -r "$APP" Payload/
    zip -qr build/ios/ipa/Runner.ipa Payload
    rm -rf Payload
    IPA="build/ios/ipa/Runner.ipa"
    echo "方式2 产出 IPA: $IPA"
  else
    echo "未找到 $APP"
  fi
fi

# 8) 方式3：xcodebuild 直连（显式禁用签名）
if [ -z "$IPA" ] && [ -d "ios/Runner.xcworkspace" ]; then
  echo "==> 方式3：xcodebuild 直接 archive"
  if [ -f "ios/Podfile" ]; then
    (cd ios && pod install) || echo "pod install 失败，继续尝试"
  fi
  rm -rf build/ios/Runner.xcarchive
  (cd ios && xcodebuild \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Release \
      -sdk iphoneos \
      -destination 'generic/platform=iOS' \
      -archivePath "$PWD/../build/ios/Runner.xcarchive" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGN_ENTITLEMENTS="" \
      PROVISIONING_PROFILE_SPECIFIER="" \
      archive)
  echo "方式3 退出码: $?"
  APP="build/ios/Runner.xcarchive/Products/Applications/Runner.app"
  if [ -d "$APP" ]; then
    rm -rf Payload build/ios/ipa
    mkdir -p Payload build/ios/ipa
    cp -r "$APP" Payload/
    zip -qr build/ios/ipa/Runner.ipa Payload
    rm -rf Payload
    IPA="build/ios/ipa/Runner.ipa"
    echo "方式3 产出 IPA: $IPA"
  else
    echo "未找到 $APP"
  fi
fi

echo ""
echo "==> 产物检查"
ls -la build/ios/ipa/ 2>/dev/null || echo "build/ios/ipa 目录不存在"
if [ -z "$IPA" ] || [ ! -f "$IPA" ]; then
  echo "❌ 未能产出 IPA"
  exit 1
fi
echo "✅ 完成：$IPA"
