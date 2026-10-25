# -*- coding: utf-8 -*-
"""건물 그림의 땅 판 옆면(흙·석축 단면)을 지우고 그만큼 내려, 윗면이 게임 땅에 바로 붙게 한다.

제미나이 그림은 건물이 두께 있는 마름모 땅 판 위에 서 있다. 판의 옆면이 그대로 보이면 건물이 땅 위에 떠 보인다.
- 판 두께 t: 판 왼쪽·오른쪽 끝 모서리에서 세로로 이어진 불투명 픽셀 길이(끝 모서리엔 판의 꼭짓점 세로선만 있다). 둘 중 작은 값.
- 윗면 마름모 = 바닥 마름모를 t만큼 올린 것. 윗면 앞쪽 두 변보다 아래(= 옆면)를 투명하게 지운 뒤 그림 전체를 t만큼 내린다.
사용: python tools/flatten_base.py            (assets/sprites/buildings 전부, 원본은 ../_backup_sprites/flatten 에)
      python tools/flatten_base.py --check    (미리보기만 art_inbox/_flatten_preview.png)
"""
import os, sys, shutil
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BDIR = os.path.join(HERE, "..", "assets", "sprites", "buildings")
BACKUP = os.path.join(HERE, "..", "..", "_backup_sprites", "flatten")
SKIP_SUFFIX = ("_winter", "_spring", "_summer", "_autumn")
SKIP = ("haenggung", "seojangdae", "yeonmudae", "yusubu", "workshop", "market_shop", "tile_house", "thatch_house", "well")
# 위 SKIP의 "market_shop"·"tile_house"·"thatch_house"·"workshop"·"well"은 번호 없는 옛 기본 그림만(아래 _skip 참고)


def _skip(stem: str) -> bool:
    if stem.endswith(SKIP_SUFFIX):
        return True
    return stem in SKIP


def measure(im: Image.Image):
    a = im.getchannel("A")
    w, h = im.size
    px = a.load()

    def col(x):
        ys = [y for y in range(h) if px[x, y] > 64]
        return ys

    lx = next((x for x in range(w) if col(x)), None)
    rx = next((x for x in range(w - 1, -1, -1) if col(x)), None)
    if lx is None or rx is None or rx - lx < 8:
        return None

    def span(x):
        ys = col(x)
        if not ys:
            return 0, 0
        bot = ys[-1]
        top = bot
        while top - 1 >= 0 and px[x, top - 1] > 64:
            top -= 1
        return bot, bot - top + 1

    lb, ls = span(min(lx + 1, w - 1))
    rb, rs = span(max(rx - 1, 0))
    bx = (lx + rx) // 2
    bys = col(bx)
    if not bys:
        return None
    bb = bys[-1]
    t = min(ls, rs)
    return {"lx": lx, "rx": rx, "ly": lb, "ry": rb, "bx": bx, "by": bb, "t": t, "w": w, "h": h}


def flatten(im: Image.Image):
    im = im.convert("RGBA")
    m = measure(im)
    if m is None:
        return im, 0
    t = m["t"]
    w, h = im.size
    if t < 3 or t > h * 0.3:
        return im, 0
    out = im.copy()
    po = out.load()
    # 윗면 앞쪽 두 변: (lx, ly-t) → (bx, by-t) → (rx, ry-t)
    L = (m["lx"], m["ly"] - t)
    B = (m["bx"], m["by"] - t)
    R = (m["rx"], m["ry"] - t)
    for x in range(w):
        if x <= B[0]:
            if B[0] == L[0]:
                continue
            yl = L[1] + (B[1] - L[1]) * (x - L[0]) / (B[0] - L[0])
        else:
            if R[0] == B[0]:
                continue
            yl = B[1] + (R[1] - B[1]) * (x - B[0]) / (R[0] - B[0])
        y0 = int(yl) + 2  # 윗면 테두리 1~2px은 남긴다
        for y in range(max(0, y0), h):
            po[x, y] = (0, 0, 0, 0)
    # t만큼 내린다
    shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shifted.alpha_composite(out.crop((0, 0, w, h - t)), (0, t))
    return shifted, t


def main():
    check = "--check" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    files = sorted(f for f in os.listdir(BDIR) if f.endswith(".png"))
    done = []
    prev = []
    for f in files:
        stem = f[:-4]
        if names and stem not in names:
            continue
        if not names and _skip(stem):
            continue
        if not names and os.path.exists(os.path.join(BACKUP, f)):
            continue  # 이미 처리함(두 번 내리지 않게) — 다시 하려면 이름을 직접 적는다
        src = os.path.join(BDIR, f)
        im = Image.open(src).convert("RGBA")
        out, t = flatten(im)
        if t == 0:
            continue
        done.append((stem, t))
        prev.append((im, out))
        if not check:
            os.makedirs(BACKUP, exist_ok=True)
            bk = os.path.join(BACKUP, f)
            if not os.path.exists(bk):
                shutil.copy2(src, bk)
            q = out.quantize(colors=64, method=Image.Quantize.FASTOCTREE).convert("RGBA")
            q.putalpha(out.getchannel("A"))
            q.save(src, optimize=True)
    for s, t in done:
        print("%s: 판 두께 %dpx 지움" % (s, t))
    print("모두 %d장%s" % (len(done), " (미리보기만)" if check else ""))
    if check and prev:
        sc = 2
        W = sum((a.width + 8) * 2 for a, _ in prev[:10]) * sc
        H = max(a.height for a, _ in prev[:10]) * sc
        sheet = Image.new("RGBA", (W, H), (90, 140, 90, 255))
        x = 0
        for a, b in prev[:10]:
            for im2 in (a, b):
                big = im2.resize((im2.width * sc, im2.height * sc), Image.NEAREST)
                sheet.alpha_composite(big, (x, H - big.height))
                x += big.width + 8 * sc
        sheet.save(os.path.join(HERE, "..", "art_inbox", "_flatten_preview.png"))
    if not check and done:
        try:
            sys.path.insert(0, HERE)
            import make_winter
            make_winter.main([s for s, _ in done])
        except Exception as e:
            print("겨울판 못 만듦:", e)


if __name__ == "__main__":
    main()
