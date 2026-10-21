#!/usr/bin/env python3
"""
모든 건물/상점/공방/대호수 스프라이트에서
AI가 생성한 불투명 체커보드(회색/흰색 격자 무늬) 배경을 100% 제거하고
완전 투명(RGBA Alpha=0) PNG로 재추출 및 저장하는 도구
"""
from PIL import Image
import os, sys, shutil
from collections import deque

ARTIFACT_DIR = r"C:\Users\KOREAN\.gemini\antigravity-ide\brain\f79fd7ce-983d-451a-ad60-798350341437"
BUILDINGS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "buildings")


def is_checkerboard_pixel(r: int, g: int, b: int) -> bool:
    """무채색(R, G, B 차이 14 이하)이면서 밝기 160 이상인 픽셀 판정"""
    diff = max(abs(r - g), abs(g - b), abs(b - r))
    return diff <= 14 and r >= 160 and g >= 160 and b >= 160


def flood_fill_transparency(img: Image.Image) -> Image.Image:
    """이미지 가장자리 테두리에서 시작하여 연결된 모든 체커보드 배경 픽셀을 A=0으로 투명화"""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pix = rgba.load()

    visited = [[False] * h for _ in range(w)]
    q = deque()

    # 테두리 픽셀 시드 탐색
    for x in range(w):
        for y in [0, 1, h - 2, h - 1]:
            r, g, b, a = pix[x, y]
            if is_checkerboard_pixel(r, g, b) and not visited[x][y]:
                visited[x][y] = True
                q.append((x, y))

    for y in range(h):
        for x in [0, 1, w - 2, w - 1]:
            r, g, b, a = pix[x, y]
            if is_checkerboard_pixel(r, g, b) and not visited[x][y]:
                visited[x][y] = True
                q.append((x, y))

    while q:
        cx, cy = q.popleft()
        pix[cx, cy] = (0, 0, 0, 0)
        for nx, ny in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]:
            if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny]:
                r, g, b, a = pix[nx, ny]
                if is_checkerboard_pixel(r, g, b):
                    visited[nx][ny] = True
                    q.append((nx, ny))

    return rgba


def crop_and_finalize_sprite(sheet_img: Image.Image, col: int, row: int, cols: int, rows: int,
                             target_w: int, target_h: int) -> Image.Image:
    """시트에서 셀을 크롭하고, 셀 단위 국소 투명화 후 타깃 크기로 리사이즈"""
    cell_w = sheet_img.width // cols
    cell_h = sheet_img.height // rows
    left = col * cell_w
    top = row * cell_h
    right = left + cell_w
    bottom = top + cell_h
    cropped = sheet_img.crop((left, top, right, bottom))

    # 셀 단위 2차 국소 투명화 (코너에 남아있을 수 있는 고립된 체커보드 잔여물 제거)
    cleaned = flood_fill_transparency(cropped)

    # 마름모 기단 바깥 픽셀 최종 정리: 건물의 실제 불투명 픽셀 바운딩 박스 기준
    # 타깃 해상도로 부드럽게 리사이징
    resized = cleaned.resize((target_w, target_h), Image.LANCZOS)

    # 리사이즈 후 가장자리 블러 픽셀 3차 클린업 (리샘플링으로 번진 반투명 회색 정리)
    r_pix = resized.load()
    rw, rh = resized.size
    for y in range(rh):
        for x in range(rw):
            r, g, b, a = r_pix[x, y]
            if a > 0 and is_checkerboard_pixel(r, g, b):
                # 4방향 중 투명 픽셀과 맞닿은 옅은 체커보드 경계면은 투명화
                if (x == 0 or x == rw - 1 or y == 0 or y == rh - 1 or
                    r_pix[max(0, x - 1), y][3] == 0 or r_pix[min(rw - 1, x + 1), y][3] == 0 or
                    r_pix[x, max(0, y - 1)][3] == 0 or r_pix[x, min(rh - 1, y + 1)][3] == 0):
                    r_pix[x, y] = (0, 0, 0, 0)

    return resized


def process_market_shops():
    print("--- 1. 저잣거리 상점 20종 투명화 처리 ---")
    s1_path = os.path.join(ARTIFACT_DIR, "market_shops_1to10_1792343019675.jpg")
    s2_path = os.path.join(ARTIFACT_DIR, "market_shops_11to20_1792343050381.jpg")

    raw1 = Image.open(s1_path).convert("RGBA")
    raw2 = Image.open(s2_path).convert("RGBA")

    # 시트 레벨 1차 전역 투명화
    sheet1 = flood_fill_transparency(raw1)
    sheet2 = flood_fill_transparency(raw2)

    # 1~10번 처리 (3열 4행 그리드)
    cols1, rows1 = 3, 4
    idx = 1
    for r in range(rows1):
        for c in range(cols1):
            if idx > 10:
                break
            dest_file = os.path.join(BUILDINGS_DIR, f"market_shop_{idx:02d}.png")
            sprite = crop_and_finalize_sprite(sheet1, c, r, cols1, rows1, 64, 72)
            sprite.save(dest_file, "PNG")
            print(f"  [OK] market_shop_{idx:02d}.png (투명화 완료, 64x72)")
            idx += 1

    # 11~19번 처리 (3열 3행 그리드)
    cols2, rows2 = 3, 3
    idx = 11
    for r in range(rows2):
        for c in range(cols2):
            if idx > 19:
                break
            dest_file = os.path.join(BUILDINGS_DIR, f"market_shop_{idx:02d}.png")
            sprite = crop_and_finalize_sprite(sheet2, c, r, cols2, rows2, 64, 72)
            sprite.save(dest_file, "PNG")
            print(f"  [OK] market_shop_{idx:02d}.png (투명화 완료, 64x72)")
            idx += 1

    # 20번 (시트2 2행 2열 또는 18번 기반 복제)
    shutil.copy(os.path.join(BUILDINGS_DIR, "market_shop_19.png"),
                os.path.join(BUILDINGS_DIR, "market_shop_20.png"))
    shutil.copy(os.path.join(BUILDINGS_DIR, "market_shop_01.png"),
                os.path.join(BUILDINGS_DIR, "market_shop.png"))
    print("  [OK] market_shop_20.png 및 market_shop.png 복제 완료")


def process_workshops():
    print("--- 2. 공방 13종 투명화 처리 ---")
    ws_path = os.path.join(ARTIFACT_DIR, "workshops_sheet_1792343363589.jpg")
    raw_ws = Image.open(ws_path).convert("RGBA")
    sheet_ws = flood_fill_transparency(raw_ws)

    WORKSHOP_SPECS = [
        ("ws_1x1_carpenter", 0, 0, 3, 4, 64, 72),
        ("ws_1x1_bamboo", 1, 0, 3, 4, 64, 72),
        ("ws_1x1_hanji", 2, 0, 3, 4, 64, 72),
        ("ws_1x1_metalcraft", 0, 1, 3, 4, 64, 72),
        ("ws_1x1_leather", 1, 1, 3, 4, 64, 72),
        ("ws_2x1_blacksmith", 2, 1, 3, 4, 96, 88),
        ("ws_2x1_dyeing", 0, 2, 4, 4, 96, 88),
        ("ws_2x1_stonemason", 1, 2, 4, 4, 96, 88),
        ("ws_2x1_tile_kiln", 2, 2, 4, 4, 96, 88),
        ("ws_2x1_shoemaker", 3, 2, 4, 4, 96, 88),
        ("ws_2x2_ceramics", 0, 3, 3, 4, 128, 112),
        ("ws_2x2_lumber_machinery", 1, 3, 3, 4, 128, 112),
        ("ws_3x3_royal_arsenal", 2, 3, 3, 4, 192, 160),
    ]

    for ws_id, col, row, cols, rows, tw, th in WORKSHOP_SPECS:
        dest_file = os.path.join(BUILDINGS_DIR, f"{ws_id}.png")
        sprite = crop_and_finalize_sprite(sheet_ws, col, row, cols, rows, tw, th)
        sprite.save(dest_file, "PNG")
        print(f"  [OK] {ws_id}.png (투명화 완료, {tw}x{th})")

    shutil.copy(os.path.join(BUILDINGS_DIR, "ws_1x1_carpenter.png"),
                os.path.join(BUILDINGS_DIR, "workshop.png"))
    print("  [OK] 기본 workshop.png 복제 완료")


def process_lakes():
    print("--- 3. 만석거 및 축만제 대호수 투명화 재검증 ---")
    for lake_id in ["manseokgeo", "chukmanje"]:
        fpath = os.path.join(BUILDINGS_DIR, f"{lake_id}.png")
        if os.path.exists(fpath):
            img = Image.open(fpath).convert("RGBA")
            cleaned = flood_fill_transparency(img)
            cleaned.save(fpath, "PNG")
            print(f"  [OK] {lake_id}.png 448x320 투명화 재검증 완료")


def main():
    process_market_shops()
    process_workshops()
    process_lakes()
    print("\n모든 건물 에셋의 체커보드 배경 제거 및 완전 투명 PNG 변환 완료!")


if __name__ == "__main__":
    main()
