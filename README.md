# 黄油可颂 · 行测智能体（iOS / 巨魔免签）

接入了「花生十三 × 郭熙」课程蒸馏知识库的 AI 聊天 App。

- **名字**：黄油可颂 🥐
- **图标**：来自你提供的图片（已做锐化提清处理，生成全套 iOS/Android 图标）
- **后端**：`http://38.175.194.43/dify`（服务器 nginx 80 端口反向代理到 Dify 8080）

---

## 一、功能

| 功能 | 说明 |
|---|---|
| 流式对话 | 回答逐字输出，可随时点「停止」中断 |
| **提问记录** | 自动保存到本地，右上角 🕘 查看；点击可回到任意历史会话；长按删除；支持清空 |
| 拍照提问 | 相机 / 相册上传题目图片，由视觉模型识别后作答 |
| 出处引用 | 回答下方显示命中的知识库文档（📖） |
| 复制 / 重新生成 | 每条回答下方可一键复制或重新生成 |
| 多轮上下文 | 同一会话内保持上下文（Dify conversation_id） |
| 深色模式 | 跟随系统自动切换 |
| 快捷提问 | 首页四条常用问题一键发问 |

## 二、目录说明

```
黄油可颂/
├── lib/
│   ├── main.dart           应用入口（主题 + 中文本地化 + 深色模式）
│   ├── theme.dart          奶油金配色（亮/暗两套）
│   ├── api.dart            Dify 客户端（流式 SSE + 图片上传 + 友好报错）
│   ├── models.dart         ChatMessage / ChatSession / Citation
│   ├── store.dart          本地会话持久化（JSON 文件）
│   ├── chat_page.dart      聊天界面（蕾 = 用户头像）
│   └── history_page.dart   提问记录列表
├── assets/icon.png         运行时图标
├── icons/                  全套 iOS/Android 图标
├── setup_and_build.sh      macOS 一键构建（含免签配置）
└── .github/workflows/build-ipa.yml   云端免费构建
```

## 三、怎么拿到 IPA

### 方案 A：云端构建（无需 Mac）

推送到 GitHub 后，工作流会**自动构建**并把 IPA 发布到 `dist/huangyou-kesong.ipa`：

```
https://github.com/hu932/gxl/raw/main/dist/huangyou-kesong.ipa
```

手机上用 Safari 打开这个链接即可直接下载。

### 方案 B：本地 Mac

```bash
bash setup_and_build.sh      # 产物在 build/ios/ipa/*.ipa
```

---

## 四、安装（巨魔 TrollStore）

1. iPhone 已装 **TrollStore（巨魔商店）**
2. 下载 `huangyou-kesong.ipa` 到手机
3. 用巨魔打开该文件 → **Install**
4. 桌面出现「黄油可颂」，点开即用（免签名、重启不失效）

> 若装过旧版本，直接覆盖安装即可，本地提问记录会保留（新版本首次运行才开始记录）。

---

## 五、改配置

| 想改什么 | 改哪里 |
|---|---|
| 后端地址 / API Key | `lib/api.dart` 的 `DifyConfig` |
| 用户头像文字（默认「蕾」） | `lib/chat_page.dart` 里 `Text('蕾')` |
| 应用名 | `setup_and_build.sh` 里 `CFBundleDisplayName` |
| 图标 | 替换 `icons/AppIcon.appiconset/` 下的 PNG |

---

## 六、构建时踩过的坑（供参考）

1. **8080 端口被拦截** —— 服务器 UFW 白名单里没有 8080，手机访问报 `No route to host`。已改用 nginx 80 端口反代 `/dify/`。
2. **`flutter build ipa --no-codesign` 不产 IPA** —— 日志明确 "skipping IPA"。必须用 `flutter build ios --no-codesign` + 手动 zip 打包。
3. **Xcode 自动签名拦截** —— 报 "requires a selected Development Team"。构建脚本会把 `CODE_SIGN_STYLE` 改成 `Manual` 并清空 team。
4. **图片上传 400 unsupported image** —— `MultipartFile` 默认发 `application/octet-stream`，必须显式指定 `image/jpeg` 等 MIME。
5. **输入法切不了中文** —— Info.plist 缺 `CFBundleLocalizations`，已补 zh-Hans/zh-Hant/en。
6. **iOS 默认拦截 http** —— Info.plist 需加 `NSAppTransportSecurity.NSAllowsArbitraryLoads`。
