# -*- coding: utf-8 -*-
"""건물 그림마다 겨울판(<이름>_winter.png)을 만든다 — 지붕·마당에 눈이 덮인 모습.

게임은 겨울이면 <이름>_winter.png가 있을 때 그것을 쓴다(SpriteCacheManager.get_seasonal_or_base_texture).
건물 그림을 새로 넣거나 바꾼 뒤 다시 실행하면 된다:  python tools/make_winter.py
"""
import colorsys, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BDIR = os.path.join(HERE, "..", "assets", "sprites", "buildings")
SKIP = ("children_play_yard", "women_play_yard", "manseokgeo", "chukmanje", "haenggung", "seojangdae", "yeonmudae", "yusubu")
SNOW = (236, 242, 250)
SNOW_SHADE = (196, 210, 228)


def mix(c, t, k):
    return tuple(int(round(c[i] * (1 - k) + t[i] * k)) for i in range(3))


def snow_of(rgb, k):
    # 밝기 무늬(기와골·이엉결)를 살려서 하얗게
    lum = (rgb[0] * 0.3 + rgb[1] * 0.59 + rgb[2] * 0.11) / 255.0
    tone = mix(SNOW_SHADE, SNOW, min(1.0, 0.35 + lum * 1.4))
    return mix(rgb, tone, k)


def winterize(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    out = im.copy()
    po = out.load()
    # 바닥 마름모 높이: 캔버스 가로 = (가로칸+세로칸)*32 → 마름모 높이 = 가로/2
    base_h = w // 2
    base_top = h - base_h
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            deg = hh * 360.0
            up = px[x, y - 1] if y > 0 else (0, 0, 0, 0)
            top_edge = up[3] < 40  # 위가 비어 있으면 윗면(눈이 가장 두껍게)
            k = 0.0
            if s < 0.22 and v < 0.40 and y < base_top + base_h * 0.8:
                k = 0.78  # 기와지붕
            elif 25 <= deg <= 58 and 0.30 <= s <= 0.80 and v > 0.50 and y < base_top + base_h * 0.25:
                k = 0.70  # 초가 이엉(바닥 마당 위쪽만)
            elif 70 <= deg <= 170 and s > 0.25 and v < 0.75:
                k = 0.55  # 풀·나무 잎
            elif y >= base_top and 20 <= deg <= 50 and s > 0.20 and v > 0.45:
                k = 0.42  # 마당 흙
            if top_edge and k > 0:
                k = min(0.95, k + 0.15)
            if k > 0:
                po[x, y] = snow_of((r, g, b), k) + (a,)
    return out


def main(names=None):
    files = sorted(f for f in os.listdir(BDIR) if f.endswith(".png"))
    n = 0
    for f in files:
        stem = f[:-4]
        if stem.endswith(("_winter", "_spring", "_summer", "_autumn")) or stem.startswith(SKIP):
            continue
        if names and stem not in names:
            continue
        src = os.path.join(BDIR, f)
        dst = os.path.join(BDIR, stem + "_winter.png")
        img = winterize(Image.open(src))
        q = img.quantize(colors=64, method=Image.Quantize.FASTOCTREE).convert("RGBA")
        # 투명도는 원본 그대로
        q.putalpha(img.getchannel("A"))
        q.save(dst, optimize=True)
        n += 1
    print("겨울판 %d개 만듦" % n)


if __name__ == "__main__":
    main(sys.argv[1:] or None)
