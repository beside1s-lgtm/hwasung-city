import json
import math

# 조선 정조 수원화성 고증 지형 생성기
# 1. 팔달산 동쪽 기슭 완경사 평탄화 (화성행궁/동헌 터 확보)
# 2. 행궁 앞을 흐르는 금천(실개천 지류) 수원천 합류 수로 구현
# 3. 성 밖 현륭원 지도 내 타일 제거 및 순수 이벤트화

SCALE = 3.2  # 20x20 -> 64x64
MAP_W = 64
MAP_H = 64


def sc(pt):
    return (round(pt[0] * SCALE), round(pt[1] * SCALE))


# ------------------------------------------------------------------
# 1. 화성 성곽 외곽선 (3.2배 확대)
WALL_PATH_20 = [
    (8, 1), (16, 1), (18, 5), (17, 9), (15, 13), (12, 17), (8, 19), (5, 19),
    (2, 17), (1, 14), (1, 9), (1, 4), (4, 1),
]
WALL_PATH = [sc(p) for p in WALL_PATH_20]

GATES_20 = {
    "jangan": (8, 2), "changryong": (15, 9), "paldal": (5, 17), "hwaseo": (2, 4),
}
GATES = {k: sc(v) for k, v in GATES_20.items()}

# 2. 팔달산 (서장대는 정상 능선)
MOUNTAIN_CENTER = sc((4, 9)) # (13, 29)
MOUNTAIN_CORE_R = 2.4 * SCALE # 7.68
MOUNTAIN_SLOPE_R = 3.8 * SCALE # 12.16
MOUNTAIN_PEAK_H = 7.0
MOUNTAIN_SLOPE_H = 2.6
SEOJANGDAE_POS = MOUNTAIN_CENTER

# 3. 수원천 본류 — 북쪽 밖에서 남쪽 밖까지 끊김 없이 관통하는 자연 하천
RIVER_CONTROL = [
    (35, -2),  # 북쪽 지도 밖에서 자연 유입
    (35, 6),   # 화홍문 (북수문) 통과
    (35, 16),
    (34, 26),
    (33, 34),  # 매향교 / 도심 중심부
    (33, 44),  # 행궁 실개천 합류점
    (34, 54),  # 남수문 통과
    (34, 66),  # 남쪽 지도 밖으로 자연 유출
]
RIVER_CORE_R = 1.2   # 폭 약 2.4타일의 적정하고 아름다운 하천 폭
RIVER_BANK_R = 2.2   # 완만한 하천 둔치
RIVER_DEPTH = -1.2

# 4. 행궁 앞마당을 흐르는 실개천 (금천 / 지류 소하천)
# 팔달산 서북 능선 골짜기에서 자연 발원하여 행궁 앞을 곡선으로 감싸고 수원천 본류로 합류
STREAM_CONTROL = [
    (8, 14),   # 팔달산 능선 서북쪽 계곡 발원지
    (11, 18),  # 화서문 안쪽 골짜기
    (15, 22),
    (19, 25),
    (23, 28),  # 행궁 북동쪽 감싸는 곡선
    (24, 33),  # 행궁 정면 앞 (금천)
    (25, 38),  # 남동쪽으로 선회
    (28, 43),
    (33, 44),  # 수원천 본류와 정확히 합류
]
STREAM_CORE_R = 0.65 # 폭 약 1.3타일의 아늑하고 맑은 실개천
STREAM_BANK_R = 1.5
STREAM_DEPTH = -0.6

# 5. 대유둔전 둔덕 (만석거 예정지)
HILLOCK_CENTER = sc((14, 12))
HILLOCK_R = 2.5 * SCALE
HILLOCK_H = 2.3

# 6. 성문 밖 간선로
GATE_OUTBOUND_LEN = 14


def point_in_polygon(x, y, poly):
    n = len(poly)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def seg_dist(px, py, p1, p2):
    x1, y1 = p1
    x2, y2 = p2
    dx, dy = x2 - x1, y2 - y1
    seg_len2 = dx * dx + dy * dy
    t = 0.0 if seg_len2 == 0 else max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / seg_len2))
    cx, cy = x1 + t * dx, y1 + t * dy
    return math.hypot(px - cx, py - cy)


def river_dist(px, py):
    return min(seg_dist(px, py, RIVER_CONTROL[i], RIVER_CONTROL[i + 1]) for i in range(len(RIVER_CONTROL) - 1))


def stream_dist(px, py):
    return min(seg_dist(px, py, STREAM_CONTROL[i], STREAM_CONTROL[i + 1]) for i in range(len(STREAM_CONTROL) - 1))


def height_at(x, y):
    """연속 고도 함수. 평지=1.0, 팔달산 정상은 솟고 동쪽 기슭은 행궁터를 위해 완만하게 내려앉는다."""
    h = 1.0

    # 팔달산 고도 계산 (동쪽 x > MOUNTAIN_CENTER[0] + 1 은 행궁터를 위해 완만하게 평탄화)
    md = dist((x, y), MOUNTAIN_CENTER)
    dx_east = x - MOUNTAIN_CENTER[0]
    
    # 동쪽으로 뻗은 기슭은 급경사를 신속히 낮춰 행궁 터 확보
    effective_core_r = MOUNTAIN_CORE_R
    effective_slope_r = MOUNTAIN_SLOPE_R
    if dx_east > 0:
        effective_core_r = max(1.2, MOUNTAIN_CORE_R - dx_east * 0.7)
        effective_slope_r = max(2.2, MOUNTAIN_SLOPE_R - dx_east * 1.2)

    if md < effective_core_r:
        t = md / effective_core_r
        h = max(h, MOUNTAIN_PEAK_H - t * (MOUNTAIN_PEAK_H - MOUNTAIN_SLOPE_H))
    elif md < effective_slope_r:
        t = (md - effective_core_r) / (effective_slope_r - effective_core_r)
        h = max(h, MOUNTAIN_SLOPE_H - t * (MOUNTAIN_SLOPE_H - 1.0))

    # 대유둔전 둔덕
    hd = dist((x, y), HILLOCK_CENTER)
    if hd < HILLOCK_R and h <= 1.1:
        t = hd / HILLOCK_R
        h = max(h, HILLOCK_H - t * (HILLOCK_H - 1.0))

    # 수원천 본류
    rd = river_dist(x, y)
    if rd < RIVER_CORE_R:
        h = min(h, RIVER_DEPTH)
    elif rd < RIVER_BANK_R:
        t = (rd - RIVER_CORE_R) / (RIVER_BANK_R - RIVER_CORE_R)
        h = min(h, RIVER_DEPTH + t * (1.0 - RIVER_DEPTH))

    # 행궁 앞 실개천 (금천)
    sd = stream_dist(x, y)
    if sd < STREAM_CORE_R:
        h = min(h, STREAM_DEPTH)
    elif sd < STREAM_BANK_R:
        t = (sd - STREAM_CORE_R) / (STREAM_BANK_R - STREAM_CORE_R)
        h = min(h, STREAM_DEPTH + t * (1.0 - STREAM_DEPTH))

    return h


# ------------------------------------------------------------------
# 정점 높이맵 (size+1)^2
VS = MAP_W + 1
raw_vertex = [[height_at(vx, vy) for vx in range(VS)] for vy in range(VS)]
corner_heights = [[0.0] * VS for _ in range(VS)]
for vy in range(VS):
    for vx in range(VS):
        total = 0.0
        weight_sum = 0.0
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = vy + dy, vx + dx
                if 0 <= ny < VS and 0 <= nx < VS:
                    w = 4 if (dx == 0 and dy == 0) else (2 if dx == 0 or dy == 0 else 1)
                    total += raw_vertex[ny][nx] * w
                    weight_sum += w
        corner_heights[vy][vx] = round(total / weight_sum, 3)

# 타일별 지형 분류(플레이 규칙용 이산값)와 성 안/밖 판정
terrain = [["plain"] * MAP_W for _ in range(MAP_H)]
for y in range(MAP_H):
    for x in range(MAP_W):
        cx, cy = x + 0.5, y + 0.5
        inside = point_in_polygon(cx, cy, WALL_PATH)
        md = dist((cx, cy), MOUNTAIN_CENTER)
        dx_east = cx - MOUNTAIN_CENTER[0]

        rd = river_dist(cx, cy)
        sd = stream_dist(cx, cy)

        # 동쪽 기슭은 행궁 터를 위해 산악 판정을 제외하고 평지(plain)로 처리
        # 정상 능선(x <= 14) 및 서쪽/남서쪽 성곽 방면만 산악 판정 유지
        is_mountain = False
        if dx_east <= 1.5:
            if md < MOUNTAIN_SLOPE_R:
                is_mountain = True
        elif dx_east <= 2.2:
            if abs(cy - MOUNTAIN_CENTER[1]) < 2.0 and md < 2.5:
                is_mountain = True

        if rd < RIVER_CORE_R or sd < STREAM_CORE_R:
            t = "water"
        elif is_mountain:
            t = "mountain"
        else:
            t = "plain"

        terrain[y][x] = t if inside else (t if t != "plain" else "outside")

# 성문 밖 간선로
gate_dirs = {
    "jangan": (0, -1), "paldal": (0, 1), "hwaseo": (-1, 0), "changryong": (1, 0),
}
outbound_roads = {}
for key, (gx, gy) in GATES.items():
    dx, dy = gate_dirs[key]
    pts = []
    reached_outside = False
    for i in range(1, GATE_OUTBOUND_LEN + 1):
        px, py = gx + dx * i, gy + dy * i
        if not (0 <= px < MAP_W and 0 <= py < MAP_H):
            break
        tt = terrain[py][px]
        if tt in ("mountain", "water"):
            break
        if tt == "outside":
            reached_outside = True
            pts.append([px, py])
        elif reached_outside:
            break
    outbound_roads[key] = pts

# ------------------------------------------------------------------
# 타일별 지표면 질감 분류 (surfaces: grass, forest, dirt, field, rocky, water)
# 사용자 요청: 돌밭, 흙밭, 나무가 우거진 곳, 풀이 난 곳, 흙길, 박석길
surfaces = [["grass"] * MAP_W for _ in range(MAP_H)]
for y in range(MAP_H):
    for x in range(MAP_W):
        t = terrain[y][x]
        cx, cy = x + 0.5, y + 0.5
        rd = river_dist(cx, cy)
        sd = stream_dist(cx, cy)
        md = dist((cx, cy), MOUNTAIN_CENTER)
        hd = dist((cx, cy), HILLOCK_CENTER)

        avg_h = (corner_heights[y][x] + corner_heights[y][x+1] + 
                 corner_heights[y+1][x] + corner_heights[y+1][x+1]) * 0.25

        n1 = math.sin(x * 0.32) * math.cos(y * 0.32) + 0.5 * math.sin(x * 0.65 + y * 0.45)
        n2 = math.cos(x * 0.37 - y * 0.28) * math.sin(y * 0.48)
        rand_val = (math.sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1.0

        if t == "water":
            surf = "water"
        elif t == "mountain":
            if avg_h >= 4.0 or md < 2.8:
                surf = "rocky"
            elif md < MOUNTAIN_SLOPE_R + 1.5:
                surf = "forest"
            else:
                surf = "rocky" if rand_val < 0.4 else "forest"
        else:
            if rd < RIVER_BANK_R + 0.6 or sd < STREAM_BANK_R + 0.4:
                if rand_val < 0.55:
                    surf = "rocky"
                else:
                    surf = "dirt"
            elif hd < HILLOCK_R * 1.05 and rand_val < 0.70:
                surf = "field"
            elif any(dist((cx, cy), g_pos) < 3.2 for g_pos in GATES.values()) and rand_val < 0.65:
                surf = "dirt"
            elif 42 <= cx <= 56 and 14 <= cy <= 28 and n1 > 0.2:
                surf = "forest"
            elif n1 > 0.90:
                surf = "forest"
            elif n1 < -0.85:
                surf = "field"
            elif n2 > 0.78:
                surf = "dirt"
            elif n2 < -0.82:
                surf = "rocky"
            else:
                surf = "grass"
        surfaces[y][x] = surf

# 현륭원 좌표는 지도 밖(-1, -1) 처리: 성 안 타일에서 완전 제거
terrain_data = {
    "size": MAP_W,
    "corner_heights": [v for row in corner_heights for v in row],
    "terrain": [t for row in terrain for t in row],
    "surfaces": [s for row in surfaces for s in row],
    "wall_path": [list(p) for p in WALL_PATH],
    "gates": {k: list(v) for k, v in GATES.items()},
    "outbound_roads": outbound_roads,
    "seojangdae_pos": list(SEOJANGDAE_POS),
    "hyoryungwon_pos": [-1, -1], # 성 밖 사도세자 묘역은 이벤트로만 등장
    "hillock_center": list(HILLOCK_CENTER),
    "mountain_center": list(MOUNTAIN_CENTER),
}

out_path = r"c:\myapp\hwashung city\godot_hwashung\maps\terrain_data.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(terrain_data, f)
print(f"Generated updated terrain_data.json with Haenggung plain and Stream channel")

# 빈 Tiled 맵 갱신
empty_layer_data = [0] * (MAP_W * MAP_H)
tiled_map = {
    "compressionlevel": -1, "height": MAP_H, "infinite": False,
    "layers": [{
        "data": empty_layer_data, "height": MAP_H, "id": 1, "name": "CoordRef",
        "opacity": 1, "type": "tilelayer", "visible": True, "width": MAP_W, "x": 0, "y": 0,
    }],
    "nextlayerid": 2, "nextobjectid": 1, "orientation": "isometric", "renderorder": "right-down",
    "tiledversion": "1.10.2", "tileheight": 32,
    "tilesets": [{"firstgid": 1, "source": "../assets/terrain_tileset.tsj"}],
    "tilewidth": 64, "type": "map", "version": "1.10", "width": MAP_W,
}
map_out = r"c:\myapp\hwashung city\godot_hwashung\maps\hwashung_map.tmj"
with open(map_out, "w", encoding="utf-8") as f:
    json.dump(tiled_map, f, indent=2)
print(f"Generated coordinate-reference map: {map_out}")
