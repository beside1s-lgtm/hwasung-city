# -*- coding: utf-8 -*-
"""만석거·축만제 호수 그림 손질 — 움직이는 배와 겨울 빙판을 위해.

1. 그림 속 나룻배를 따로 떼어 <이름>_boat.png로 저장하고(게임이 물결 따라 흔들며 그린다),
   원래 자리는 둘레 물빛으로 메운다.
2. 물빛 픽셀을 얼음빛으로 바꾸고(make_winter로 나무·지붕엔 눈) <이름>_winter.png를 만든다.
원본은 ../_backup_sprites/lake_fx 에 한 번만 보관하고, 다시 돌릴 땐 늘 그 원본에서 시작한다.
사용: python tools/lake_fx.py
"""
import colorsys, os, shutil, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BDIR = os.path.join(HERE, "..", "assets", "sprites", "buildings")
BACKUP = os.path.join(HERE, "..", "..", "_backup_sprites", "lake_fx")
# 배가 들어 있는 네모(그림 448x320 좌표)
BOATS = {"manseokgeo": (209, 171, 242, 194), "chukmanje": (259, 193, 292, 216)}


def is_water(rgb):
    r, g, b = rgb[:3]
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    deg = h * 360.0
    if s < 0.12 and v > 0.75:
        return True  # 윤슬(흰 반짝임)
    return 165 <= deg <= 245 and s > 0.30 and b > r + 25


def cut_boat(im, box):
    px = im.load()
    x0, y0, x1, y1 = box
    boat = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
    bp = boat.load()
    hole = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = px[x, y]
            if c[3] > 40 and (not is_water(c) or max(c[:3]) < 105):  # 배 + 짙은 외곽선
                bp[x - x0, y - y0] = c
                hole.append((x, y))
    # 배에서 떨어진 낱점(물 위 윤슬)은 배가 아니다 — 가장 큰 덩어리만 남긴다
    hs0 = set(hole)
    seen, best = set(), []
    for st in hole:
        if st in seen:
            continue
        comp, stack = [], [st]
        seen.add(st)
        while stack:
            q = stack.pop()
            comp.append(q)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nq = (q[0] + dx, q[1] + dy)
                    if nq in hs0 and nq not in seen:
                        seen.add(nq)
                        stack.append(nq)
        if len(comp) > len(best):
            best = comp
    keep = set(best)
    for (x, y) in hole:
        if (x, y) not in keep:
            bp[x - x0, y - y0] = (0, 0, 0, 0)
    hole = best
    # 배 둘레 2px(물 위 그늘·외곽선)까지 함께 메운다
    hs = set(hole)
    for _ in range(2):
        for (x, y) in list(hs):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                hs.add((x + dx, y + dy))
    # 물결 무늬가 가로로 길어서, 같은 줄의 네모 밖 물빛을 옮겨 온다(윗줄에서 가져오면 물빛이 달라 얼룩진다)
    w = x1 - x0
    for (x, y) in hs:
        for off in (-w, w, -2 * w, 2 * w):
            sx = x + off
            if 0 <= sx < im.width and is_water(px[sx, y]) and max(px[sx, y][:3]) >= 105:
                px[x, y] = px[sx, y]
                break
    return boat


ICE_DARK = (150, 182, 202)
ICE_LITE = (226, 238, 246)


def freeze(im):
    out = im.copy()
    po = out.load()
    src = im.load()
    W, H = im.size
    wm = [[src[x, y][3] > 40 and is_water(src[x, y]) for x in range(W)] for y in range(H)]
    # 물 위 햇빛 윤슬(노란 반짝임)도 물로: 둘레 8칸 중 5칸 이상이 물인 밝은 점
    # 윤슬 띠는 넓어서 한 번에 안 잡힌다 — 물 쪽에서부터 여러 번 번져 들어간다
    for _ in range(8):
        grow = []
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if not wm[y][x] and src[x, y][3] > 40 and max(src[x, y][:3]) > 150:
                    n = sum(1 for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy) and wm[y + dy][x + dx])
                    if n >= 3:
                        grow.append((x, y))
        if not grow:
            break
        for (x, y) in grow:
            wm[y][x] = True
    for y in range(H):
        for x in range(W):
            c = po[x, y]
            if wm[y][x]:
                lum = (c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11) / 255.0
                k = min(1.0, 0.45 + lum * 0.9)  # 무늬는 살리되 얼음판이 지저분하지 않게 대비를 낮춤
                po[x, y] = tuple(int(ICE_DARK[i] * (1 - k) + ICE_LITE[i] * k) for i in range(3)) + (c[3],)
    return out


def save_q(img, path, colors=96):
    q = img.quantize(colors=colors, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    q.putalpha(img.getchannel("A"))
    q.save(path, optimize=True)


def main():
    sys.path.insert(0, HERE)
    import make_winter
    os.makedirs(BACKUP, exist_ok=True)
    for name, box in BOATS.items():
        src = os.path.join(BDIR, name + ".png")
        bk = os.path.join(BACKUP, name + ".png")
        if not os.path.exists(bk):
            shutil.copy2(src, bk)
        im = Image.open(bk).convert("RGBA")
        boat = cut_boat(im, box)
        boat.save(os.path.join(BDIR, name + "_boat.png"), optimize=True)
        save_q(im, src)
        win = make_winter.winterize(freeze(im))
        save_q(win, os.path.join(BDIR, name + "_winter.png"))
        print("%s: 배 떼어 냄(%dx%d, 위치 %d,%d), 겨울 빙판판 만듦" % (name, boat.width, boat.height, box[0], box[1]))


if __name__ == "__main__":
    main()
