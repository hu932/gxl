# -*- coding: utf-8 -*-
"""生成标准 Xcode 单尺寸 AppIcon.appiconset（含正确的 Contents.json）"""
import json
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC = r"D:\BaiduNetdiskDownload\蒸馏\微信图片_2026-10-09_020959_960.jpg"
ROOT = r"D:\BaiduNetdiskDownload\蒸馏\黄油可颂"
ICONS = os.path.join(ROOT, "icons")
APPICONSET = os.path.join(ICONS, "AppIcon.appiconset")
ANDROID = os.path.join(ICONS, "android")

# (文件名, 像素, idiom)
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

img = Image.open(SRC).convert("RGBA")

images = []
for fname, px, idiom in IOS:
    out = os.path.join(APPICONSET, fname)
    img.resize((px, px), Image.LANCZOS).save(out, "PNG")
    entry = {"filename": fname, "idiom": idiom, "size": f"{px}x{px}"}
    if idiom in ("universal", "ios-marketing"):
        entry["platform"] = "ios"
    # 从文件名提取 scale
    if "@3x" in fname:
        entry["scale"] = "3x"
    elif "@2x" in fname:
        entry["scale"] = "2x"
    else:
        entry["scale"] = "1x"
    images.append(entry)

contents = {"images": images, "info": {"author": "xcode", "version": 1}}
with open(os.path.join(APPICONSET, "Contents.json"), "w", encoding="utf-8") as f:
    json.dump(contents, f, ensure_ascii=False, indent=2)

# 通用 1024 运行时图标
img.resize((1024, 1024), Image.LANCZOS).save(os.path.join(ICONS, "icon.png"), "PNG")

# Android mipmap
AMAP = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for dpi, px in AMAP.items():
    d = os.path.join(ANDROID, f"mipmap-{dpi}")
    os.makedirs(d, exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"), "PNG")

print(f"[OK] 标准 AppIcon.appiconset：{len(images)} 个尺寸 + Android {len(AMAP)} 个")
print("Contents.json 已按 Xcode 单尺寸格式生成")
