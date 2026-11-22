#!/usr/bin/env python3
"""Glimpse 图标：一只「瞥见」的眼睛 + 光圈感，iOS 蓝渐变。"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

import os
BASE = os.path.join(os.path.dirname(__file__), "..", "android/app/src/main/res")
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

TOP = (10, 132, 255)      # #0A84FF
BOTTOM = (0, 64, 200)     # #0040C8


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        c = lerp(TOP, BOTTOM, (y / max(1, size - 1)) ** 0.9)
        for x in range(size):
            px[x, y] = c
    return img


def _lens_points(cx, cy, w, h, n=96):
    """杏仁形（眼睛）轮廓采样点"""
    left, right = (cx - w / 2, cy), (cx + w / 2, cy)
    top, bot = (cx, cy - h / 2), (cx, cy + h / 2)
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(quad(left, top, right, t))
    for i in range(n + 1):
        t = i / n
        pts.append(quad(right, bot, left, t))
    return pts


def draw_eye(img, S, scale=1.0):
    """外轮廓填充 + 内轮廓挖空，得到干净等宽描边"""
    w = S * 0.70 * scale
    h = S * 0.44 * scale
    lw = S * 0.050 * scale
    cx, cy = S / 2, S / 2

    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    d.polygon(_lens_points(cx, cy, w, h), fill=255)
    d.polygon(_lens_points(cx, cy, w - lw * 2, h - lw * 2.2), fill=0)

    pr = S * 0.060 * scale
    d.ellipse([cx - pr, cy - pr, cx + pr, cy + pr], fill=255)

    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(mask)
    img.alpha_composite(white)

def quad(p0, p1, p2, t):
    x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
    y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
    return (x, y)


def legacy_icon(size):
    S = size * 8
    img = gradient(S).convert("RGBA")
    draw_eye(img, S)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1],
                                           radius=int(S * 0.235), fill=255)
    img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


def foreground(size):
    S = size * 8
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_eye(img, S, scale=0.62)
    return img.resize((size, size), Image.LANCZOS)


for dpi, px in LEGACY.items():
    d = os.path.join(BASE, f"mipmap-{dpi}")
    os.makedirs(d, exist_ok=True)
    legacy_icon(px).save(os.path.join(d, "ic_launcher.png"))
    foreground(ADAPTIVE[dpi]).save(os.path.join(d, "ic_launcher_foreground.png"))
    print(f"{dpi} ok")

# 自适应图标背景色
vdir = os.path.join(BASE, "values")
os.makedirs(vdir, exist_ok=True)
with open(os.path.join(vdir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
    f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0A84FF</color>
</resources>
""")
print("done")
