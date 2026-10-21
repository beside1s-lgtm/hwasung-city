#!/usr/bin/env python3
"""
만석거 및 축만제 이미지를 투명 PNG(448x320)로 정밀 변환하여
assets/sprites/buildings/ 에 저장하는 스크립트
"""
from PIL import Image
import os, sys
from collections import deque

ARTIFACT_DIR = r"C:\Users\KOREAN\.gemini\antigravity-ide\brain\f79fd7ce-983d-451a-ad60-798350341437"
BUILDINGS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "buildings")

# 6x6 그리드 표준 대형 건물 캔버스 크기
TARGET_W = 448
TARGET_H = 320


def is_checkerboard_or_gray(r, g, b):
    # R, G, B 편차가 매우 작고(무채색) 밝기가 170 이상이거나 순수 흰색/회색 계열
    diff = max(abs(r - g), abs(g - b), abs(b - r))
    if diff <= 8 and (r > 175 or (185 <= r <= 205) or r >= 240):
        return True
    return False


def remove_checkerboard_from_corners(img: Image.Image) -> Image.Image:
    """외곽 코너에서 Flood Fill로 체커보드 영역만 투명화"""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()

    visited = [[False] * h for _ in range(w)]
    queue = deque()

    # 4개 모서리 및 가장자리 테두리 픽셀을 시드로 추가
    for x in range(w):
        for y in [0, 1, 2, h - 3, h - 2, h - 1]:
            r, g, b, _ = pixels[x, y]
            if is_checkerboard_or_gray(r, g, b) and not visited[x][y]:
                queue.append((x, y))
                visited[x][y] = True

    for y in range(h):
        for x in [0, 1, 2, w - 3, w - 2, w - 1]:
            r, g, b, _ = pixels[x, y]
            if is_checkerboard_or_gray(r, g, b) and not visited[x][y]:
                queue.append((x, y))
                visited[x][y] = True

    # BFS Flood Fill
    while queue:
        cx, cy = queue.popleft()
        pixels[cx, cy] = (0, 0, 0, 0)

        for nx, ny in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]:
            if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny]:
                r, g, b, a = pixels[nx, ny]
                if is_checkerboard_or_gray(r, g, b):
                    visited[nx][ny] = True
                    queue.append((nx, ny))

    return rgba


def process_lake(src_name_keyword: str, dest_filename: str):
    found_path = None
    for fname in os.listdir(ARTIFACT_DIR):
        if src_name_keyword in fname and fname.endswith(".jpg"):
            found_path = os.path.join(ARTIFACT_DIR, fname)
            break

    if not found_path:
        print(f"ERROR: {src_name_keyword} 파일을 찾을 수 없습니다.")
        return

    print(f"처리 중: {found_path}")
    raw_img = Image.open(found_path)

    # 1. 코너 체커보드 투명화
    transparent_img = remove_checkerboard_from_corners(raw_img)

    # 2. 바운딩 박스로 실제 내용물 크롭
    bbox = transparent_img.getbbox()
    if bbox:
        cropped = transparent_img.crop(bbox)
    else:
        cropped = transparent_img

    # 3. 448x320 캔버스에 중앙 하단 정렬로 배치 (아이소메트릭 규격)
    final_canvas = Image.new("RGBA", (TARGET_W, TARGET_H), (0, 0, 0, 0))

    # 종횡비 유지 리사이징
    cw, ch = cropped.size
    scale = min(TARGET_W / cw, TARGET_H / ch)
    new_w = int(cw * scale)
    new_h = int(ch * scale)
    scaled = cropped.resize((new_w, new_h), Image.LANCZOS)

    # 캔버스 하단 기준 중앙 배치 (dest_pos.y -= (tex_h - tile_h) 규격 대응)
    pos_x = (TARGET_W - new_w) // 2
    pos_y = TARGET_H - new_h

    final_canvas.paste(scaled, (pos_x, pos_y), scaled)

    dest_path = os.path.join(BUILDINGS_DIR, dest_filename)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    final_canvas.save(dest_path, "PNG")
    print(f"  성공: {dest_path} ({TARGET_W}x{TARGET_H} PNG)")


def main():
    process_lake("manseokgeo_iso_lake", "manseokgeo.png")
    process_lake("chukmanje_iso_lake", "chukmanje.png")
    print("만석거 및 축만제 PNG 생성 완료!")


if __name__ == "__main__":
    main()
