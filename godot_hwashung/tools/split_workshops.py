#!/usr/bin/env python3
"""
공방 13종 시트 이미지를 개별 규격별 PNG로 분할하여
assets/sprites/buildings/ 에 저장
"""
from PIL import Image
import os, sys, shutil

ARTIFACT_DIR = r"C:\Users\KOREAN\.gemini\antigravity-ide\brain\f79fd7ce-983d-451a-ad60-798350341437"
BUILDINGS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "buildings")

# 13종 공방 키 및 규격
# 1행: carpenter (1x1), bamboo (1x1), hanji (1x1)
# 2행: metalcraft (1x1), leather (1x1), blacksmith (2x1)
# 3행: dyeing (2x1), stonemason (2x1), tile_kiln (2x1), shoemaker (2x1) -> 4개? 3행에 4개 또는 3열 레이아웃
# 전체 이미지: 1024x1024, 대략 4행 또는 3열 그리드 구조
# 이미지 확인:
# 1행: carpenter, bamboo, hanji (3개)
# 2행: metalcraft, leather, blacksmith (3개)
# 3행: dyeing, stonemason, tile_kiln, shoemaker (4개)
# 4행: ceramics, lumber_machinery, royal_arsenal (3개)

WORKSHOP_SPECS = [
    # (id, col, row, cols, rows, target_w, target_h)
    # Row 0: 3 items (목공소, 죽공예, 한지)
    ("ws_1x1_carpenter", 0, 0, 3, 4, 64, 72),
    ("ws_1x1_bamboo", 1, 0, 3, 4, 64, 72),
    ("ws_1x1_hanji", 2, 0, 3, 4, 64, 72),
    # Row 1: 3 items (금속/유기, 가죽, 대장간)
    ("ws_1x1_metalcraft", 0, 1, 3, 4, 64, 72),
    ("ws_1x1_leather", 1, 1, 3, 4, 64, 72),
    ("ws_2x1_blacksmith", 2, 1, 3, 4, 96, 88),
    # Row 2: 4 items (염색, 석공, 기와가마, 갖신) - 4분할
    ("ws_2x1_dyeing", 0, 2, 4, 4, 96, 88),
    ("ws_2x1_stonemason", 1, 2, 4, 4, 96, 88),
    ("ws_2x1_tile_kiln", 2, 2, 4, 4, 96, 88),
    ("ws_2x1_shoemaker", 3, 2, 4, 4, 96, 88),
    # Row 3: 3 items (도자기, 목재기계, 무기창)
    ("ws_2x2_ceramics", 0, 3, 3, 4, 128, 112),
    ("ws_2x2_lumber_machinery", 1, 3, 3, 4, 128, 112),
    ("ws_3x3_royal_arsenal", 2, 3, 3, 4, 192, 160),
]


def main():
    sheet_path = None
    for fname in os.listdir(ARTIFACT_DIR):
        if "workshops_sheet" in fname and fname.endswith(".jpg"):
            sheet_path = os.path.join(ARTIFACT_DIR, fname)

    if not sheet_path:
        print("ERROR: 공방 시트 이미지를 찾을 수 없습니다.")
        sys.exit(1)

    print(f"공방 시트: {sheet_path}")
    img = Image.open(sheet_path).convert("RGBA")
    W, H = img.size

    for ws_id, col, row, cols, rows, tw, th in WORKSHOP_SPECS:
        cell_w = W // cols
        cell_h = H // rows
        left = col * cell_w
        top = row * cell_h
        right = left + cell_w
        bottom = top + cell_h
        cropped = img.crop((left, top, right, bottom))
        resized = cropped.resize((tw, th), Image.LANCZOS)
        dest = os.path.join(BUILDINGS_DIR, f"{ws_id}.png")
        resized.save(dest, "PNG")
        print(f"  Saved: {ws_id}.png ({tw}x{th})")

    # 기본 workshop.png도 목공소로 복사
    shutil.copy(os.path.join(BUILDINGS_DIR, "ws_1x1_carpenter.png"),
                os.path.join(BUILDINGS_DIR, "workshop.png"))
    print("\n공방 13종 및 기본 workshop.png 저장 완료!")


if __name__ == "__main__":
    main()
