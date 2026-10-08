# 黄油可颂 · 行测智能体（iOS / 巨魔免签）

一个接入了「花生十三 × 郭熙」课程蒸馏知识库的 AI 聊天 App。

- **名字**：黄油可颂 🥐
- **图标**：来自你提供的图片（已生成全套 iOS/Android 图标）
- **能力**：文字问答 + 拍照提问（OCR 由后端视觉模型处理）
- **后端**：`http://38.175.194.43:8080/v1/chat-messages`（Dify 知识库应用）

---

## 一、目录说明

```
黄油可颂/
├── lib/                    # Flutter 源码
│   ├── main.dart           # 入口
│   ├── theme.dart          # 奶油金色主题
│   ├── api.dart            # Dify API 客户端（流式 + 图片上传）
│   └── chat_page.dart      # 聊天界面
├── assets/icon.png         # 运行时用的图标（欢迎页）
├── icons/                  # 已生成的全套 iOS/Android 图标
├── pubspec.yaml
├── setup_and_build.sh      # macOS 一键构建脚本
├── .github/workflows/build-ipa.yml   # 云端免费构建
└── 本文件
```

---

## 二、怎么拿到 IPA（二选一）

### 方案 A：有 Mac（最快）

```bash
# 1. 装 Flutter：https://docs.flutter.dev/get-started/install/macos
# 2. 进入本目录，执行：
bash setup_and_build.sh
# 3. 产物在 build/ios/ipa/*.ipa
```

脚本会自动做：生成 iOS 脚手架 → 写图标 → 配置 Info.plist（应用名 + 允许 http + 相机/相册权限）→ 构建**无签名** IPA。

### 方案 B：没有 Mac（云端免费编译）

1. 把「黄油可颂」整个文件夹推到一个 **GitHub 公开仓库**
2. 在仓库页面点 **Actions** → 左侧「构建黄油可颂 IPA（免签）」→ **Run workflow**
3. 等约 5 分钟，构建完成后在 Actions 详情页下载 **Artifacts** 里的 `黄油可颂-免签IPA`
4. 解压得到 `huangyou_kesong.ipa`

> GitHub 公开仓库的 macOS 编译是免费的（私有仓库需付费）。

---

## 三、安装（巨魔 TrollStore）

1. iPhone 已安装 **TrollStore（巨魔商店）**
2. 把 `.ipa` 文件传到手机（AirDrop / 微信文件 / 网页均可）
3. 用「巨魔」App 打开这个 `.ipa` → **Install**
4. 桌面出现「黄油可颂」图标，点开即用（免签名、永久有效）

> 提示：若个别系统提示未受信任，用巨魔安装的应用无需处理证书，重启后依然可用。

---

## 四、改配置

- **后端地址 / API Key**：改 `lib/api.dart` 里的 `DifyConfig` 即可。
- **应用名 / 图标**：图标改 `icons/AppIcon.appiconset/`，名字在 `setup_and_build.sh` 的 `CFBundleDisplayName`。

---

## 五、界面效果

- 奶油背景 + 黄油金主色（贴合「黄油可颂」）
- 欢迎页带图标 + 快捷提问
- 气泡式对话，AI 回答用 Markdown 渲染（公式、列表、表格）
- 底部显示「📖 出处」引用（来自知识库检索命中）
- 打字中的三点动画
- 支持拍照 / 相册上传题目图片
