# -*- coding: utf-8 -*-
"""
生成高清图标：
原图偏软（锐度 3.53）且 JPEG 压缩重，这里做 unsharp 锐化 + 轻微提饱和/对比，
再按 Xcode 标准单尺寸格式输出全套 AppIcon。
"""
import json
import os
import sys

from PIL import Image, ImageEnhance, ImageFilter

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC = r"D:\BaiduNetdiskDownload\蒸馏\微信图片_2026-10-09_020959_960.jpg"
ROOT = r"D:\BaiduNetdiskDownload\蒸馏\黄油可颂"
ICONS = os.path.join(ROOT, "icons")
APPICONSET = os.path.join(ICONS, "AppIcon.appiconset")
ANDROID = os.path.join(ICONS, "android")

IOS = [
    ("Icon-App-20x20@1x.png", 20, "universal"),
    ("Icon-App-20x20@2x.png", 40, "universal"),
    ("Icon-App-20x20@3x.png", 60, "universal"),
    ("Icon-App-29x29@1x.png", 29, "universal"),
    ("Icon-App-29x29@2x.png", 58, "universal"),
    ("Icon-App-29x29@3x.png", 87, "universal"),
    ("Icon-App-40x40@1x.png", 40, "universal"),
    ("Icon-App-40x40@2x.png", 80, "universal"),
    ("Icon-App-40x40@3x.png", 120, "universal"),
    ("Icon-App-60x60@2x.png", 120, "universal"),
    ("Icon-App-60x60@3x.png", 180, "universal"),
    ("Icon-App-76x76@1x.png", 76, "ipad"),
    ("Icon-App-76x76@2x.png", 152, "ipad"),
    ("Icon-App-83.5x83.5@2x.png", 167, "ipad"),
    ("Icon-App-1024x1024@1x.png", 1024, "ios-marketing"),
]

os.makedirs(APPICONSET, exist_ok=True)
os.makedirs(ANDROID, exist_ok=True)

# ---- 1) 先放大到 2048 再锐化，减少放大伪影；然后处理 ----
base = Image.open(SRC).convert("RGB")
UP = 2048
big = base.resize((UP, UP), Image.LANCZOS)

# 锐化（两轮轻量，比一轮重手更自然）
big = big.filter(ImageFilter.UnsharpMask(radius=3, percent=110, threshold=3))
big = big.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
# 轻微提饱和与对比，让小尺寸下更醒目
big = ImageEnhance.Color(big).enhance(1.10)
big = ImageEnhance.Contrast(big).enhance(1.05)

master = big.convert("RGBA")

images = []
for fname, px, idiom in IOS:
    # 小尺寸额外加一点锐化，抵消缩放发虚
    img = master.resize((px, px), Image.LANCZOS)
    if px <= 60:
        img = img.filter(ImageFilter.UnsharpMask(radius=0.8, percent=70, threshold=1))
    entry = {"filename": fname, "idiom": idiom, "size": f"{px}x{px}"}
    if idiom in ("universal", "ios-marketing"):
        entry["platform"] = "ios"
    entry["scale"] = "3x" if "@3x" in fname else ("2x" if "@2x" in fname else "1x")
    images.append(entry)
    img.save(os.path.join(APPICONSET, fname), "PNG", optimize=True)

with open(os.path.join(APPICONSET, "Contents.json"), "w", encoding="utf-8") as f:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f,
              ensure_ascii=False, indent=2)

# 运行时图标
master.resize((1024, 1024), Image.LANCZOS).save(os.path.join(ICONS, "icon.png"), "PNG", optimize=True)

# Android
for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    d = os.path.join(ANDROID, f"mipmap-{dpi}")
    os.makedirs(d, exist_ok=True)
    master.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"), "PNG", optimize=True)

print(f"[OK] 高清图标已生成：{len(images)} 个 iOS 尺寸")
print(f"     处理链：2048 上采样 -> 两轮 unsharp -> 饱和+10% 对比+5% -> LANCZOS 缩放")
