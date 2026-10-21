import os
import zlib
import struct

TILE_W = 64
TILE_H = 32
COLS = 4
ROWS = 5 # PORT-TRACE P23: 성곽 밖 미편입지(index16) 추가로 5행 필요
WIDTH = TILE_W * COLS   # 256
HEIGHT = TILE_H * ROWS  # 128

# RGBA 버퍼 초기화
buffer = bytearray(WIDTH * HEIGHT * 4)

def set_pixel(x, y, r, g, b, a):
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        idx = (y * WIDTH + x) * 4
        buffer[idx] = r
        buffer[idx + 1] = g
        buffer[idx + 2] = b
        buffer[idx + 3] = a

def draw_iso_diamond(ox, oy, fill, border):
    cx = ox + TILE_W // 2
    cy = oy + TILE_H // 2
    for y in range(TILE_H):
        py = oy + y
        dy = abs(y - TILE_H // 2)
        # 다이아몬드 가로 폭: y 중심에서 멀어질수록 폭이 줄어듬
        half_span = int((1.0 - (dy / (TILE_H / 2.0))) * (TILE_W / 2.0))
        for dx in range(-half_span, half_span + 1):
            px = cx + dx
            if dx == -half_span or dx == half_span or dy == (TILE_H // 2) - 1:
                set_pixel(px, py, *border)
            else:
                set_pixel(px, py, *fill)

tiles = [
    None, # 0
    ((67, 160, 71, 255), (46, 125, 50, 255)),   # 1: 평지 잔디
    ((141, 110, 99, 255), (109, 76, 65, 255)),  # 2: 황토 평지
    ((30, 136, 229, 255), (21, 101, 192, 255)), # 3: 수원천 물
    ((215, 204, 200, 255), (161, 136, 127, 255)), # 4: 모래톱
    ((46, 125, 50, 255), (27, 94, 32, 255)),    # 5: 팔달산 완경사
    ((120, 144, 156, 255), (84, 110, 122, 255)),# 6: 팔달산 절벽/바위
    ((188, 138, 92, 255), (141, 95, 54, 255)),  # 7: 삼남대로 도로
    ((158, 158, 158, 255), (97, 97, 97, 255)),  # 8: 화성 성곽
    ((117, 117, 117, 255), (66, 66, 66, 255)),  # 9: 석축 제방
    ((0, 150, 136, 255), (0, 105, 92, 255)),    # 10: 만석거
    ((197, 160, 89, 255), (138, 109, 59, 255)), # 11: 초가집
    ((55, 71, 79, 255), (38, 50, 56, 255)),     # 12: 기와집
    ((183, 28, 28, 255), (136, 14, 79, 255)),   # 13: 동헌
    ((255, 179, 0, 255), (255, 143, 0, 255)),   # 14: 서장대
    ((161, 136, 127, 255), (109, 76, 65, 255)), # 15: 공사비계
    ((120, 118, 108, 255), (90, 88, 80, 255)),  # 16: 성저(城底) 미편입지 - 성곽 밖, 건설 불가
]

for idx, t in enumerate(tiles):
    if not t:
        continue
    col = idx % COLS
    row = idx // COLS
    ox = col * TILE_W
    oy = row * TILE_H
    draw_iso_diamond(ox, oy, t[0], t[1])

def write_png(filename, width, height, rgba_data):
    raw_lines = bytearray()
    for y in range(height):
        raw_lines.append(0)  # filter type 0 (None)
        line_start = y * width * 4
        raw_lines.extend(rgba_data[line_start:line_start + width * 4])
    
    compressed = zlib.compress(bytes(raw_lines), 9)
    
    def chunk(tag, data):
        c = bytearray(tag) + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xffffffff)
        return struct.pack(">I", len(data)) + c + crc

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    # IHDR
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png.extend(chunk(b"IHDR", ihdr))
    # IDAT
    png.extend(chunk(b"IDAT", compressed))
    # IEND
    png.extend(chunk(b"IEND", b""))

    with open(filename, "wb") as f:
        f.write(png)

out_dir = r"c:\myapp\hwashung city\godot_hwashung\assets"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "terrain_tileset.png")
write_png(out_path, WIDTH, HEIGHT, buffer)
print(f"PNG Generated successfully: {out_path} ({len(buffer)} bytes)")
