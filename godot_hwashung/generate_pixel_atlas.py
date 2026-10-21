import os
import zlib
import struct
import math

def create_image(width, height):
    return bytearray(width * height * 4)

def set_pixel(buf, w, h, x, y, r, g, b, a=255):
    if 0 <= x < w and 0 <= y < h:
        idx = (int(y) * w + int(x)) * 4
        # 알파 블렌딩
        if a < 255:
            oa = buf[idx + 3]
            if oa == 0:
                buf[idx] = r
                buf[idx + 1] = g
                buf[idx + 2] = b
                buf[idx + 3] = a
                return
            alpha = a / 255.0
            inv = 1.0 - alpha
            buf[idx] = int(r * alpha + buf[idx] * inv)
            buf[idx + 1] = int(g * alpha + buf[idx + 1] * inv)
            buf[idx + 2] = int(b * alpha + buf[idx + 2] * inv)
            buf[idx + 3] = min(255, oa + a)
        else:
            buf[idx] = r
            buf[idx + 1] = g
            buf[idx + 2] = b
            buf[idx + 3] = a

def fill_rect(buf, w, h, rx, ry, rw, rh, r, g, b, a=255):
    for y in range(max(0, int(ry)), min(h, int(ry + rh))):
        for x in range(max(0, int(rx)), min(w, int(rx + rw))):
            set_pixel(buf, w, h, x, y, r, g, b, a)

def fill_circle(buf, w, h, cx, cy, radius, r, g, b, a=255):
    r_sq = radius * radius
    for y in range(int(cy - radius), int(cy + radius + 1)):
        for x in range(int(cx - radius), int(cx + radius + 1)):
            if (x - cx)**2 + (y - cy)**2 <= r_sq:
                set_pixel(buf, w, h, x, y, r, g, b, a)

def draw_line(buf, w, h, x0, y0, x1, y1, r, g, b, a=255):
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    curr_x, curr_y = int(x0), int(y0)
    while True:
        set_pixel(buf, w, h, curr_x, curr_y, r, g, b, a)
        if curr_x == int(x1) and curr_y == int(y1):
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            curr_x += sx
        if e2 < dx:
            err += dx
            curr_y += sy

def fill_poly(buf, w, h, pts, r, g, b, a=255):
    if len(pts) < 3:
        return
    min_y = max(0, int(min(p[1] for p in pts)))
    max_y = min(h - 1, int(max(p[1] for p in pts)))
    for y in range(min_y, max_y + 1):
        nodes = []
        j = len(pts) - 1
        for i in range(len(pts)):
            p1 = pts[i]
            p2 = pts[j]
            if (p1[1] < y and p2[1] >= y) or (p2[1] < y and p1[1] >= y):
                nodes.append(p1[0] + (y - p1[1]) / (p2[1] - p1[1]) * (p2[0] - p1[0]))
            j = i
        nodes.sort()
        for k in range(0, len(nodes) - 1, 2):
            x_start = max(0, int(math.ceil(nodes[k])))
            x_end = min(w - 1, int(math.floor(nodes[k + 1])))
            for x in range(x_start, x_end + 1):
                set_pixel(buf, w, h, x, y, r, g, b, a)

def write_png(filename, width, height, rgba_data):
    raw_lines = bytearray()
    for y in range(height):
        raw_lines.append(0)
        line_start = y * width * 4
        raw_lines.extend(rgba_data[line_start:line_start + width * 4])
    compressed = zlib.compress(bytes(raw_lines), 9)
    def chunk(tag, data):
        c = bytearray(tag) + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xffffffff)
        return struct.pack(">I", len(data)) + c + crc
    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
    png.extend(chunk(b"IDAT", compressed))
    png.extend(chunk(b"IEND", b""))
    with open(filename, "wb") as f:
        f.write(png)

# ==============================================================================
# 1. BUILDINGS ATLAS (512x512, 8x8 slots of 64x64)
# ==============================================================================
BW = 512
BH = 512
SLOT_B = 64
b_buf = create_image(BW, BH)

def slot_origin(idx):
    col = idx % 8
    row = idx // 8
    return col * SLOT_B, row * SLOT_B

# 0~15: 삼남대로 도로 오토타일링 (16방향)
for mask in range(16):
    ox, oy = slot_origin(mask)
    cx = ox + 32
    cy = oy + 44 # 타일 바닥 중심
    n = (mask & 1) != 0
    e = (mask & 2) != 0
    s = (mask & 4) != 0
    w = (mask & 8) != 0

    # 도로 기본 황토/박석 채우기
    fill_circle(b_buf, BW, BH, cx, cy, 9, 179, 141, 79)
    if mask == 0:
        fill_circle(b_buf, BW, BH, cx, cy, 14, 179, 141, 79)
    if n:
        fill_poly(b_buf, BW, BH, [(cx - 8, cy), (cx + 8, cy), (cx + 24, cy - 12), (cx + 8, cy - 12)], 179, 141, 79)
        draw_line(b_buf, BW, BH, cx, cy, cx + 16, cy - 8, 140, 98, 48)
    if e:
        fill_poly(b_buf, BW, BH, [(cx - 4, cy - 6), (cx + 4, cy - 6), (cx + 28, cy + 6), (cx + 20, cy + 6)], 179, 141, 79)
        draw_line(b_buf, BW, BH, cx, cy, cx + 24, cy + 6, 140, 98, 48)
    if s:
        fill_poly(b_buf, BW, BH, [(cx - 8, cy), (cx + 8, cy), (cx - 8, cy + 12), (cx - 24, cy + 12)], 179, 141, 79)
        draw_line(b_buf, BW, BH, cx, cy, cx - 16, cy + 8, 140, 98, 48)
    if w:
        fill_poly(b_buf, BW, BH, [(cx - 4, cy - 6), (cx + 4, cy - 6), (cx - 20, cy - 6), (cx - 28, cy - 6)], 179, 141, 79)
        draw_line(b_buf, BW, BH, cx, cy, cx - 24, cy - 6, 140, 98, 48)

    # 박석 도트 텍스처
    for i in range(5):
        px = cx - 8 + (i * 5) % 18
        py = cy - 4 + (i * 3) % 9
        set_pixel(b_buf, BW, BH, px, py, 138, 102, 54)
        set_pixel(b_buf, BW, BH, px + 1, py, 138, 102, 54)

# 16~31: 성곽 16방향 오토타일링 (화강암 기단석 + 전돌 체성 + 여장)
for mask in range(16):
    ox, oy = slot_origin(16 + mask)
    cx = ox + 32
    cy = oy + 42
    n = (mask & 1) != 0
    e = (mask & 2) != 0
    s = (mask & 4) != 0
    w = (mask & 8) != 0

    # 화강암 기단석
    fill_rect(b_buf, BW, BH, cx - 14, cy - 8, 28, 16, 95, 90, 85)
    # 체성 전돌벽
    fill_rect(b_buf, BW, BH, cx - 12, cy - 18, 24, 12, 45, 42, 40)
    # 여장 및 총안
    fill_rect(b_buf, BW, BH, cx - 12, cy - 24, 7, 7, 30, 27, 26)
    fill_rect(b_buf, BW, BH, cx + 5, cy - 24, 7, 7, 30, 27, 26)

    # 연결부
    if n:
        fill_rect(b_buf, BW, BH, cx - 6, cy - 24, 12, 20, 75, 70, 66)
        fill_rect(b_buf, BW, BH, cx - 4, cy - 30, 8, 8, 30, 27, 26)
    if s:
        fill_rect(b_buf, BW, BH, cx - 6, cy + 6, 12, 16, 75, 70, 66)
    if w:
        fill_rect(b_buf, BW, BH, ox, cy - 14, 20, 16, 85, 80, 75)
        fill_rect(b_buf, BW, BH, ox, cy - 22, 18, 10, 40, 37, 35)
        fill_rect(b_buf, BW, BH, ox + 2, cy - 26, 6, 5, 30, 27, 26)
        fill_rect(b_buf, BW, BH, ox + 11, cy - 26, 6, 5, 30, 27, 26)
    if e:
        fill_rect(b_buf, BW, BH, cx + 12, cy - 14, 20, 16, 85, 80, 75)
        fill_rect(b_buf, BW, BH, cx + 14, cy - 22, 18, 10, 40, 37, 35)
        fill_rect(b_buf, BW, BH, cx + 16, cy - 26, 6, 5, 30, 27, 26)
        fill_rect(b_buf, BW, BH, cx + 25, cy - 26, 6, 5, 30, 27, 26)

    # 석축 줄눈
    draw_line(b_buf, BW, BH, cx - 14, cy, cx + 14, cy, 60, 56, 52)
    draw_line(b_buf, BW, BH, cx - 12, cy - 12, cx + 12, cy - 12, 25, 23, 22)

# 32: 동헌 (office)
ox, oy = slot_origin(32)
cx, cy = ox + 32, oy + 48
# 화강암 기단
fill_rect(b_buf, BW, BH, cx - 22, cy - 6, 44, 8, 120, 115, 110)
# 붉은 기둥과 대청
fill_rect(b_buf, BW, BH, cx - 20, cy - 22, 40, 16, 245, 238, 220)
fill_rect(b_buf, BW, BH, cx - 20, cy - 22, 4, 16, 180, 40, 35)
fill_rect(b_buf, BW, BH, cx - 7, cy - 22, 3, 16, 180, 40, 35)
fill_rect(b_buf, BW, BH, cx + 4, cy - 22, 3, 16, 180, 40, 35)
fill_rect(b_buf, BW, BH, cx + 16, cy - 22, 4, 16, 180, 40, 35)
# 태극 문양
fill_circle(b_buf, BW, BH, cx, cy - 14, 4, 220, 35, 35)
fill_circle(b_buf, BW, BH, cx, cy - 12, 3, 35, 75, 200)
# 단청
fill_rect(b_buf, BW, BH, cx - 22, cy - 24, 44, 3, 5, 150, 105)
fill_rect(b_buf, BW, BH, cx - 22, cy - 26, 44, 2, 195, 30, 30)
# 웅장한 팔작 기와지붕
fill_poly(b_buf, BW, BH, [(cx - 28, cy - 26), (cx + 28, cy - 26), (cx + 22, cy - 38), (cx - 22, cy - 38)], 40, 45, 55)
fill_poly(b_buf, BW, BH, [(cx - 22, cy - 38), (cx + 22, cy - 38), (cx, cy - 44)], 30, 35, 42)
draw_line(b_buf, BW, BH, cx - 28, cy - 26, cx, cy - 44, 200, 200, 210)
draw_line(b_buf, BW, BH, cx + 28, cy - 26, cx, cy - 44, 200, 200, 210)

# 33: 서장대 (seojangdae)
ox, oy = slot_origin(33)
cx, cy = ox + 32, oy + 50
# 석축 돈대
fill_rect(b_buf, BW, BH, cx - 18, cy - 10, 36, 12, 100, 95, 90)
# 1층 누각
fill_rect(b_buf, BW, BH, cx - 16, cy - 22, 32, 12, 240, 230, 210)
fill_rect(b_buf, BW, BH, cx - 16, cy - 22, 3, 12, 160, 40, 35)
fill_rect(b_buf, BW, BH, cx + 13, cy - 22, 3, 12, 160, 40, 35)
# 1층 처마
fill_poly(b_buf, BW, BH, [(cx - 20, cy - 22), (cx + 20, cy - 22), (cx + 15, cy - 28), (cx - 15, cy - 28)], 45, 50, 60)
# 2층 누각
fill_rect(b_buf, BW, BH, cx - 12, cy - 36, 24, 9, 240, 230, 210)
fill_rect(b_buf, BW, BH, cx - 12, cy - 36, 3, 9, 160, 40, 35)
fill_rect(b_buf, BW, BH, cx + 9, cy - 36, 3, 9, 160, 40, 35)
# 2층 사모지붕
fill_poly(b_buf, BW, BH, [(cx - 16, cy - 36), (cx + 16, cy - 36), (cx, cy - 46)], 35, 40, 48)
# 총지휘 깃발 (황룡기/군기)
draw_line(b_buf, BW, BH, cx + 8, cy - 36, cx + 8, cy - 54, 70, 45, 20)
fill_poly(b_buf, BW, BH, [(cx + 8, cy - 54), (cx + 19, cy - 50), (cx + 8, cy - 46)], 235, 180, 20)

# 34: 봉돈 (bongdon)
ox, oy = slot_origin(34)
cx, cy = ox + 32, oy + 50
# 전돌 기단
fill_rect(b_buf, BW, BH, cx - 18, cy - 8, 36, 10, 80, 75, 70)
# 5연 굴뚝
for i in range(5):
    fx = cx - 16 + i * 7
    fill_rect(b_buf, BW, BH, fx, cy - 28, 5, 20, 110, 105, 100)
    fill_rect(b_buf, BW, BH, fx - 1, cy - 31, 7, 3, 140, 135, 130)
    # 연기 도트
    fill_circle(b_buf, BW, BH, fx + 2, cy - 36 - (i % 2) * 3, 2, 220, 220, 220, 180)

# 35: 장안문/팔달문 홍예성문 (gate)
ox, oy = slot_origin(35)
cx, cy = ox + 32, oy + 48
# 거대 석축 성벽
fill_rect(b_buf, BW, BH, cx - 24, cy - 14, 48, 16, 90, 85, 80)
# 무지개형 홍예문 (아치)
fill_circle(b_buf, BW, BH, cx, cy - 2, 7, 20, 20, 20)
fill_rect(b_buf, BW, BH, cx - 7, cy - 2, 14, 4, 20, 20, 20)
# 문루 기둥 및 회벽
fill_rect(b_buf, BW, BH, cx - 18, cy - 26, 36, 12, 240, 230, 215)
fill_rect(b_buf, BW, BH, cx - 18, cy - 26, 3, 12, 170, 35, 30)
fill_rect(b_buf, BW, BH, cx + 15, cy - 26, 3, 12, 170, 35, 30)
# 웅장한 2층 우진각 지붕
fill_poly(b_buf, BW, BH, [(cx - 24, cy - 26), (cx + 24, cy - 26), (cx + 16, cy - 36), (cx - 16, cy - 36)], 42, 48, 58)
fill_poly(b_buf, BW, BH, [(cx - 16, cy - 36), (cx + 16, cy - 36), (cx, cy - 42)], 32, 38, 48)

# 36: 초가삼간 (res_1)
ox, oy = slot_origin(36)
cx, cy = ox + 32, oy + 48
# 토담 및 흙마당
fill_rect(b_buf, BW, BH, cx - 16, cy - 8, 32, 10, 180, 145, 95)
# 나무 기둥과 봉창문
fill_rect(b_buf, BW, BH, cx - 14, cy - 18, 28, 12, 248, 242, 225)
fill_rect(b_buf, BW, BH, cx - 14, cy - 18, 2, 12, 120, 75, 40)
fill_rect(b_buf, BW, BH, cx + 12, cy - 18, 2, 12, 120, 75, 40)
fill_rect(b_buf, BW, BH, cx - 6, cy - 14, 5, 6, 255, 250, 240) # 창문
fill_rect(b_buf, BW, BH, cx + 2, cy - 12, 8, 6, 180, 95, 30) # 마루
# 볏짚 둥근 지붕
fill_poly(b_buf, BW, BH, [(cx - 20, cy - 18), (cx + 20, cy - 18), (cx + 14, cy - 28), (cx - 14, cy - 28)], 185, 105, 35)
fill_poly(b_buf, BW, BH, [(cx - 14, cy - 28), (cx + 14, cy - 28), (cx, cy - 32)], 160, 90, 28)
# 장독대 2개
fill_circle(b_buf, BW, BH, cx + 15, cy - 2, 3, 65, 55, 50)
fill_circle(b_buf, BW, BH, cx + 19, cy - 3, 2, 60, 50, 45)

# 37: 대감 기와집 (res_2)
ox, oy = slot_origin(37)
cx, cy = ox + 32, oy + 48
# 기단
fill_rect(b_buf, BW, BH, cx - 20, cy - 6, 40, 8, 115, 110, 105)
# 본채 회벽과 대청마루
fill_rect(b_buf, BW, BH, cx - 18, cy - 20, 36, 14, 245, 238, 225)
fill_rect(b_buf, BW, BH, cx - 18, cy - 20, 3, 14, 125, 65, 30)
fill_rect(b_buf, BW, BH, cx - 2, cy - 20, 3, 14, 125, 65, 30)
fill_rect(b_buf, BW, BH, cx + 15, cy - 20, 3, 14, 125, 65, 30)
fill_rect(b_buf, BW, BH, cx - 12, cy - 14, 8, 7, 180, 95, 35)
# 솟을대문과 팔작지붕
fill_poly(b_buf, BW, BH, [(cx - 24, cy - 20), (cx + 24, cy - 20), (cx + 18, cy - 32), (cx - 18, cy - 32)], 45, 50, 60)
fill_poly(b_buf, BW, BH, [(cx - 18, cy - 32), (cx + 18, cy - 32), (cx, cy - 38)], 35, 40, 48)

# 38: 주막 (com_1)
ox, oy = slot_origin(38)
cx, cy = ox + 32, oy + 48
# 주막 본체
fill_rect(b_buf, BW, BH, cx - 18, cy - 16, 22, 14, 195, 155, 105)
fill_poly(b_buf, BW, BH, [(cx - 22, cy - 16), (cx + 6, cy - 16), (cx - 8, cy - 26)], 175, 100, 30)
# 평상
fill_rect(b_buf, BW, BH, cx + 5, cy - 10, 14, 8, 145, 80, 25)
# 삼색 포목 차양막
fill_rect(b_buf, BW, BH, cx + 4, cy - 18, 5, 5, 225, 55, 55)
fill_rect(b_buf, BW, BH, cx + 9, cy - 18, 5, 5, 55, 120, 225)
fill_rect(b_buf, BW, BH, cx + 14, cy - 18, 5, 5, 235, 190, 45)
# 주(酒) 깃발
draw_line(b_buf, BW, BH, cx + 22, cy - 24, cx + 22, cy - 4, 120, 75, 35)
fill_rect(b_buf, BW, BH, cx + 14, cy - 24, 8, 6, 255, 240, 140)
set_pixel(b_buf, BW, BH, cx + 17, cy - 22, 200, 30, 30)

# 39: 육의전 대형 시전 상가 (com_2)
ox, oy = slot_origin(39)
cx, cy = ox + 32, oy + 48
# 1층 상가
fill_rect(b_buf, BW, BH, cx - 18, cy - 16, 36, 14, 245, 235, 215)
# 2층 누각
fill_rect(b_buf, BW, BH, cx - 14, cy - 28, 28, 12, 240, 225, 205)
fill_poly(b_buf, BW, BH, [(cx - 22, cy - 28), (cx + 22, cy - 28), (cx, cy - 38)], 45, 50, 60)
# 청사초롱 2개 (홍/청)
fill_circle(b_buf, BW, BH, cx - 12, cy - 14, 3, 220, 40, 40)
fill_circle(b_buf, BW, BH, cx + 12, cy - 14, 3, 40, 90, 220)

# 40: 벼농사 논 및 물레방아 (agr_1)
ox, oy = slot_origin(40)
cx, cy = ox + 32, oy + 48
# 논두렁과 벼이삭
fill_rect(b_buf, BW, BH, cx - 18, cy - 12, 36, 16, 75, 150, 65)
for i in range(8):
    px = cx - 15 + i * 4
    draw_line(b_buf, BW, BH, px, cy - 2, px, cy - 8, 160, 200, 50)
# 물레방아 (회전 바퀴)
fill_circle(b_buf, BW, BH, cx + 14, cy - 8, 6, 130, 85, 45)
fill_circle(b_buf, BW, BH, cx + 14, cy - 8, 2, 70, 45, 20)

# 41: 대유둔전 관개 농지 (agr_2)
ox, oy = slot_origin(41)
cx, cy = ox + 32, oy + 48
fill_rect(b_buf, BW, BH, cx - 20, cy - 14, 40, 18, 90, 175, 75)
# 관개 수로 물길
draw_line(b_buf, BW, BH, cx - 18, cy - 4, cx + 18, cy - 4, 50, 140, 220)
# 풍성한 황금 벼이삭
for i in range(10):
    px = cx - 18 + i * 4
    draw_line(b_buf, BW, BH, px, cy - 8, px + 1, cy - 14, 235, 195, 45)

# 42: 공동 우물 (well)
ox, oy = slot_origin(42)
cx, cy = ox + 32, oy + 48
# 돌 우물
fill_circle(b_buf, BW, BH, cx, cy - 6, 9, 130, 130, 130)
fill_circle(b_buf, BW, BH, cx, cy - 6, 6, 40, 120, 200) # 물
# 두레박 지지대
draw_line(b_buf, BW, BH, cx - 6, cy - 6, cx - 6, cy - 18, 120, 75, 35)
draw_line(b_buf, BW, BH, cx + 6, cy - 6, cx + 6, cy - 18, 120, 75, 35)
draw_line(b_buf, BW, BH, cx - 6, cy - 18, cx + 6, cy - 18, 120, 75, 35)
fill_circle(b_buf, BW, BH, cx, cy - 12, 2, 160, 95, 40) # 두레박

# 43: 석축 제방 (levee)
ox, oy = slot_origin(43)
cx, cy = ox + 32, oy + 48
fill_rect(b_buf, BW, BH, cx - 22, cy - 12, 44, 16, 120, 125, 130)
for y in range(cy - 10, cy + 4, 3):
    draw_line(b_buf, BW, BH, cx - 22, y, cx + 22, y, 75, 80, 85)

# 44: 만석거 수문 저수지 (reservoir)
ox, oy = slot_origin(44)
cx, cy = ox + 32, oy + 48
# 푸른 저수지 물
fill_circle(b_buf, BW, BH, cx, cy - 6, 16, 45, 130, 195)
# 화강암 수문 옹벽
fill_rect(b_buf, BW, BH, cx - 18, cy - 18, 36, 8, 135, 140, 145)
draw_line(b_buf, BW, BH, cx - 8, cy - 18, cx - 8, cy - 6, 80, 85, 90)
draw_line(b_buf, BW, BH, cx + 8, cy - 18, cx + 8, cy - 6, 80, 85, 90)

# 45: 화산 현륭원 (hyoryungwon)
ox, oy = slot_origin(45)
cx, cy = ox + 32, oy + 48
# 잔디 능침 언덕
fill_circle(b_buf, BW, BH, cx, cy - 10, 16, 100, 170, 75)
# 사도세자 홍살문
draw_line(b_buf, BW, BH, cx - 12, cy, cx - 12, cy - 18, 200, 45, 40)
draw_line(b_buf, BW, BH, cx + 12, cy, cx + 12, cy - 18, 200, 45, 40)
draw_line(b_buf, BW, BH, cx - 14, cy - 16, cx + 14, cy - 16, 200, 45, 40)
draw_line(b_buf, BW, BH, cx - 14, cy - 14, cx + 14, cy - 14, 200, 45, 40)
# 태극 창살
fill_circle(b_buf, BW, BH, cx, cy - 20, 3, 220, 40, 40)

# 46: 객주 (guesthouse)
ox, oy = slot_origin(46)
cx, cy = ox + 32, oy + 48
fill_rect(b_buf, BW, BH, cx - 18, cy - 18, 36, 14, 235, 215, 185)
fill_poly(b_buf, BW, BH, [(cx - 22, cy - 18), (cx + 22, cy - 18), (cx, cy - 30)], 115, 80, 45)
fill_rect(b_buf, BW, BH, cx - 10, cy - 12, 20, 8, 160, 110, 60)

# 47: 화성 공방 (factory)
ox, oy = slot_origin(47)
cx, cy = ox + 32, oy + 48
fill_rect(b_buf, BW, BH, cx - 18, cy - 16, 36, 14, 140, 110, 90)
fill_poly(b_buf, BW, BH, [(cx - 20, cy - 16), (cx + 20, cy - 16), (cx, cy - 26)], 90, 70, 55)
# 벽돌 굴뚝
fill_rect(b_buf, BW, BH, cx + 10, cy - 34, 6, 18, 90, 60, 50)
fill_circle(b_buf, BW, BH, cx + 13, cy - 38, 3, 200, 200, 200, 180)

# 48: 공사 비계 및 거중기 (scaffold)
ox, oy = slot_origin(48)
cx, cy = ox + 32, oy + 48
# 나무 비계 격자
for y in range(cy - 28, cy, 6):
    draw_line(b_buf, BW, BH, cx - 18, y, cx + 18, y, 140, 90, 45)
draw_line(b_buf, BW, BH, cx - 14, cy, cx - 14, cy - 30, 140, 90, 45)
draw_line(b_buf, BW, BH, cx + 14, cy, cx + 14, cy - 30, 140, 90, 45)
draw_line(b_buf, BW, BH, cx - 14, cy - 30, cx + 14, cy, 120, 75, 35)
# 거중기 도르래 및 밧줄
draw_line(b_buf, BW, BH, cx, cy - 30, cx + 12, cy - 42, 90, 55, 25)
draw_line(b_buf, BW, BH, cx + 12, cy - 42, cx + 12, cy - 24, 40, 40, 40)
fill_rect(b_buf, BW, BH, cx + 9, cy - 24, 6, 6, 150, 150, 150) # 들어올려지는 성돌

# ==============================================================================
# 2. CHARACTERS ATLAS (256x256, 8x8 slots of 32x32)
# ==============================================================================
CW = 256
CH = 256
SLOT_C = 32
c_buf = create_image(CW, CH)

def char_slot(col, row):
    return col * SLOT_C, row * SLOT_C

# 행 0 (0~3): 지게꾼 (carrier) 4프레임
for f in range(4):
    ox, oy = char_slot(f, 0)
    cx, cy = ox + 16, oy + 24
    bob = int(math.sin(f * math.pi / 2.0) * 1.5)
    # 그림자
    fill_circle(c_buf, CW, CH, cx, cy + 1, 4, 0, 0, 0, 80)
    # 흰 바지저고리
    fill_rect(c_buf, CW, CH, cx - 3, cy - 10 + bob, 6, 7, 245, 245, 245)
    # 다리 걸음
    leg_off = int((f % 2) * 2 - 1)
    draw_line(c_buf, CW, CH, cx - 2, cy - 3 + bob, cx - 2 - leg_off, cy + 1, 230, 230, 230)
    draw_line(c_buf, CW, CH, cx + 2, cy - 3 + bob, cx + 2 + leg_off, cy + 1, 230, 230, 230)
    # 얼굴/상투
    fill_circle(c_buf, CW, CH, cx, cy - 13 + bob, 3, 240, 205, 165)
    set_pixel(c_buf, CW, CH, cx, cy - 17 + bob, 40, 30, 20)
    # 나무 지게와 가마니 짐
    draw_line(c_buf, CW, CH, cx + 4, cy - 18 + bob, cx + 4, cy - 1 + bob, 140, 90, 45)
    fill_rect(c_buf, CW, CH, cx + 2, cy - 16 + bob, 6, 8, 195, 145, 75)

# 행 1 (0~3): 보부상 (merchant) 4프레임
for f in range(4):
    ox, oy = char_slot(f, 1)
    cx, cy = ox + 16, oy + 24
    bob = int(math.sin(f * math.pi / 2.0) * 1.5)
    fill_circle(c_buf, CW, CH, cx, cy + 1, 4, 0, 0, 0, 80)
    # 청색 한복
    fill_rect(c_buf, CW, CH, cx - 3, cy - 10 + bob, 6, 7, 60, 120, 185)
    leg_off = int((f % 2) * 2 - 1)
    draw_line(c_buf, CW, CH, cx - 2, cy - 3 + bob, cx - 2 - leg_off, cy + 1, 220, 220, 220)
    draw_line(c_buf, CW, CH, cx + 2, cy - 3 + bob, cx + 2 + leg_off, cy + 1, 220, 220, 220)
    # 얼굴과 패랭이 모자
    fill_circle(c_buf, CW, CH, cx, cy - 13 + bob, 3, 240, 205, 165)
    fill_rect(c_buf, CW, CH, cx - 5, cy - 16 + bob, 10, 2, 110, 75, 45)
    # 등 뒤 봇짐과 지팡이
    fill_circle(c_buf, CW, CH, cx + 4, cy - 10 + bob, 4, 235, 235, 235)
    draw_line(c_buf, CW, CH, cx - 4, cy - 10 + bob, cx - 4, cy + 1, 130, 85, 40)

# 행 2 (0~3): 장용영 군사 (guard) 4프레임
for f in range(4):
    ox, oy = char_slot(f, 2)
    cx, cy = ox + 16, oy + 24
    bob = int(math.sin(f * math.pi / 2.0) * 1.5)
    fill_circle(c_buf, CW, CH, cx, cy + 1, 4, 0, 0, 0, 80)
    # 붉은 철릭 군복
    fill_rect(c_buf, CW, CH, cx - 3, cy - 10 + bob, 6, 7, 180, 45, 35)
    leg_off = int((f % 2) * 2 - 1)
    draw_line(c_buf, CW, CH, cx - 2, cy - 3 + bob, cx - 2 - leg_off, cy + 1, 40, 40, 40)
    draw_line(c_buf, CW, CH, cx + 2, cy - 3 + bob, cx + 2 + leg_off, cy + 1, 40, 40, 40)
    # 벙거지 군모
    fill_circle(c_buf, CW, CH, cx, cy - 13 + bob, 3, 240, 205, 165)
    fill_rect(c_buf, CW, CH, cx - 4, cy - 16 + bob, 8, 2, 35, 35, 35)
    # 삼지창/환도
    draw_line(c_buf, CW, CH, cx + 4, cy - 20 + bob, cx + 4, cy + 1, 200, 200, 200)

# 행 3 (0~3): 농민 (farmer) 4프레임
for f in range(4):
    ox, oy = char_slot(f, 3)
    cx, cy = ox + 16, oy + 24
    bob = int(math.sin(f * math.pi / 2.0) * 1.5)
    fill_circle(c_buf, CW, CH, cx, cy + 1, 4, 0, 0, 0, 80)
    # 소박한 베옷
    fill_rect(c_buf, CW, CH, cx - 3, cy - 10 + bob, 6, 7, 215, 205, 185)
    leg_off = int((f % 2) * 2 - 1)
    draw_line(c_buf, CW, CH, cx - 2, cy - 3 + bob, cx - 2 - leg_off, cy + 1, 200, 190, 170)
    draw_line(c_buf, CW, CH, cx + 2, cy - 3 + bob, cx + 2 + leg_off, cy + 1, 200, 190, 170)
    # 밀짚 삿갓
    fill_circle(c_buf, CW, CH, cx, cy - 13 + bob, 3, 240, 205, 165)
    fill_poly(c_buf, CW, CH, [(cx - 5, cy - 15 + bob), (cx + 5, cy - 15 + bob), (cx, cy - 19 + bob)], 190, 150, 75)
    # 괭이
    draw_line(c_buf, CW, CH, cx + 4, cy - 14 + bob, cx + 4, cy + 1, 140, 95, 45)
    draw_line(c_buf, CW, CH, cx + 4, cy - 14 + bob, cx + 8, cy - 12 + bob, 150, 150, 150)

# 행 4 (0~3): 팔달산 맹호 (tiger) 4프레임
for f in range(4):
    ox, oy = char_slot(f, 4)
    cx, cy = ox + 16, oy + 24
    bob = int(math.sin(f * math.pi / 2.0) * 1.5)
    fill_circle(c_buf, CW, CH, cx, cy + 1, 6, 0, 0, 0, 90)
    # 호랑이 몸통 (황금빛)
    fill_rect(c_buf, CW, CH, cx - 7, cy - 8 + bob, 14, 6, 230, 150, 25)
    # 검은 줄무늬
    draw_line(c_buf, CW, CH, cx - 4, cy - 8 + bob, cx - 4, cy - 3 + bob, 30, 20, 10)
    draw_line(c_buf, CW, CH, cx, cy - 8 + bob, cx, cy - 3 + bob, 30, 20, 10)
    draw_line(c_buf, CW, CH, cx + 4, cy - 8 + bob, cx + 4, cy - 3 + bob, 30, 20, 10)
    # 4발 걸음
    leg_off = int((f % 2) * 2 - 1)
    fill_rect(c_buf, CW, CH, cx - 6 - leg_off, cy - 2, 2, 3, 220, 140, 20)
    fill_rect(c_buf, CW, CH, cx - 2 + leg_off, cy - 2, 2, 3, 220, 140, 20)
    fill_rect(c_buf, CW, CH, cx + 2 - leg_off, cy - 2, 2, 3, 220, 140, 20)
    fill_rect(c_buf, CW, CH, cx + 6 + leg_off, cy - 2, 2, 3, 220, 140, 20)
    # 머리와 귀
    fill_circle(c_buf, CW, CH, cx - 8, cy - 8 + bob, 4, 235, 155, 30)
    set_pixel(c_buf, CW, CH, cx - 10, cy - 12 + bob, 30, 20, 10)
    set_pixel(c_buf, CW, CH, cx - 7, cy - 12 + bob, 30, 20, 10)
    # 백호 수염과 백색 턱
    fill_rect(c_buf, CW, CH, cx - 11, cy - 6 + bob, 3, 2, 255, 255, 255)
    # 꼬리 살랑살랑
    tail_y = cy - 8 + bob - int(math.sin(f * math.pi) * 3)
    draw_line(c_buf, CW, CH, cx + 7, cy - 6 + bob, cx + 12, tail_y, 220, 140, 20)

out_dir = r"c:\myapp\hwashung city\godot_hwashung\assets"
os.makedirs(out_dir, exist_ok=True)
b_path = os.path.join(out_dir, "buildings_atlas.png")
c_path = os.path.join(out_dir, "characters_atlas.png")
write_png(b_path, BW, BH, b_buf)
write_png(c_path, CW, CH, c_buf)
print("SUCCESS: Generated buildings_atlas.png (512x512) and characters_atlas.png (256x256)")
