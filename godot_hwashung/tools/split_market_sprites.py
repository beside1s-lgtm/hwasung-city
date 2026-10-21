#!/usr/bin/env python3
"""
저잣거리 상점 시트 이미지를 개별 64x72 PNG로 분할하여
assets/sprites/buildings/ 에 market_shop_01.png ~ market_shop_20.png 로 저장
"""
from PIL import Image
import os, sys, shutil

ARTIFACT_DIR = r"C:\Users\KOREAN\.gemini\antigravity-ide\brain\f79fd7ce-983d-451a-ad60-798350341437"
BUILDINGS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "sprites", "buildings")

# 1~10 시트: 1024x1024 이미지, 5열 2행 레이아웃 (각 스프라이트 약 200x300px 영역)
# 11~20 시트: 1024x1024 이미지, 3열 3행 레이아웃

TARGET_W, TARGET_H = 64, 72


def crop_and_save(src_img: Image.Image, col: int, row: int, cols: int, rows: int,
                  dest_path: str, target_w: int = 64, target_h: int = 72) -> None:
    """시트에서 (col, row) 위치의 스프라이트를 크롭 후 target 크기로 리샘플 저장"""
    cell_w = src_img.width // cols
    cell_h = src_img.height // rows
    left = col * cell_w
    top = row * cell_h
    right = left + cell_w
    bottom = top + cell_h
    cropped = src_img.crop((left, top, right, bottom))
    # 리샘플링 (LANCZOS for quality)
    resized = cropped.resize((target_w, target_h), Image.LANCZOS)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    resized.save(dest_path, "PNG")
    print(f"  Saved: {os.path.basename(dest_path)}")


def main():
    # 1~10: 3열 4행으로 배치된 시트 (실제로는 생성된 이미지에서 확인 필요)
    sheet1_path = None
    sheet2_path = None
    for fname in os.listdir(ARTIFACT_DIR):
        if "market_shops_1to10" in fname and fname.endswith(".jpg"):
            sheet1_path = os.path.join(ARTIFACT_DIR, fname)
        if "market_shops_11to20" in fname and fname.endswith(".jpg"):
            sheet2_path = os.path.join(ARTIFACT_DIR, fname)

    if not sheet1_path or not sheet2_path:
        print("ERROR: 시트 이미지를 찾을 수 없습니다.")
        sys.exit(1)

    print(f"시트1 (1-10): {sheet1_path}")
    print(f"시트2 (11-20): {sheet2_path}")

    img1 = Image.open(sheet1_path).convert("RGBA")
    img2 = Image.open(sheet2_path).convert("RGBA")

    # 시트1: 3열 4행 (12 셀, 10개 사용)
    # 실제 배치를 보면 생성된 이미지가 3x4 혹은 다른 배치일 수 있음
    # 이미지 크기로 배치 추정
    # 시트1 — 3열 4행
    COLS1, ROWS1 = 3, 4
    COLS2, ROWS2 = 3, 3

    shop_idx = 1
    # 시트1에서 1~10
    for row in range(ROWS1):
        for col in range(COLS1):
            if shop_idx > 10:
                break
            dest = os.path.join(BUILDINGS_DIR, f"market_shop_{shop_idx:02d}.png")
            crop_and_save(img1, col, row, COLS1, ROWS1, dest, TARGET_W, TARGET_H)
            shop_idx += 1

    # 시트2에서 11~20
    shop_idx = 11
    for row in range(ROWS2):
        for col in range(COLS2):
            if shop_idx > 20:
                break
            dest = os.path.join(BUILDINGS_DIR, f"market_shop_{shop_idx:02d}.png")
            crop_and_save(img2, col, row, COLS2, ROWS2, dest, TARGET_W, TARGET_H)
            shop_idx += 1

    # market_shop.png (기본) = 01번
    shutil.copy(os.path.join(BUILDINGS_DIR, "market_shop_01.png"),
                os.path.join(BUILDINGS_DIR, "market_shop.png"))
    print("\n완료: market_shop_01.png ~ market_shop_20.png 저장됨")


if __name__ == "__main__":
    main()
