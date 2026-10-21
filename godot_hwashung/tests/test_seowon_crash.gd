extends SceneTree

const GameGrid = preload("res://scripts/GameGrid.gd")
const CityLayer = preload("res://scripts/CityLayer.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const CitizenLayer = preload("res://scripts/CitizenLayer.gd")
const InspectNarrativeGenerator = preload("res://scripts/InspectNarrativeGenerator.gd")
const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

func _init() -> void:
	print("=== 서원 클릭 크래시 재현 테스트 시작 ===")
	var grid: GameGrid = GameGrid.new()
	grid.size = 40
	grid.grid = []
	for y in range(40):
		var row: Array = []
		for x in range(40):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 1.0,
				"road_type": "dirt"
			})
		grid.grid.append(row)

	var seowon_pos := Vector2i(10, 10)
	var t: Dictionary = grid.grid[seowon_pos.y][seowon_pos.x]
	t["building"] = ""
	t["plaza"] = {"x0": 10, "y0": 10, "n": 3, "kind": "seowon"}
	t["facility_id"] = "seowon"
	t["special_type"] = "seowon"
	t["building_type"] = "SPECIAL"
	t["building_name"] = "화성 유학 서원 (書院)"

	var tile: Dictionary = grid.tile(seowon_pos.x, seowon_pos.y)
	print("서원 타일 데이터: ", tile)

	# 2. InspectNarrativeGenerator build_inspect_data 직접 호출
	print("\n[Step 2] InspectNarrativeGenerator.build_inspect_data() 호출 테스트")
	var t_entity: Dictionary = tile.duplicate()
	t_entity["pos"] = seowon_pos
	t_entity["facility_id"] = "seowon"
	t_entity["special_building_id"] = "seowon"
	t_entity["special_type"] = "seowon"
	t_entity["is_special_building"] = true
	t_entity["building_name"] = "화성 유학 서원 (書院)"

	var data: Dictionary = InspectNarrativeGenerator.build_inspect_data(t_entity, null, grid, null)
	print("반환된 데이터: ", data)
	assert(data["title"] == "화성 유학 서원 (書院)", "서원 제목 불일치")
	assert(data["description"].contains("선현의 위패"), "서원 고증 설명문 누락")
	assert(data["texture"] != null, "서원 포트레이트 누락")

	# 3. maegok_seowon 키로 된 경우 테스트
	print("\n[Step 3] maegok_seowon facility_id / building 테스트")
	var t2: Dictionary = {"facility_id": "maegok_seowon", "building": "maegok_seowon", "pos": seowon_pos}
	var data2: Dictionary = InspectNarrativeGenerator.build_inspect_data(t2, null, grid, null)
	print("maegok_seowon 반환 데이터: ", data2)
	assert(data2["title"] == "화성 유학 서원 (書院)", "매곡서원 제목 불일치")
	assert(data2["description"].contains("선현의 위패"), "매곡서원 고증 설명문 누락")
	assert(data2["texture"] != null, "매곡서원 포트레이트 누락")

	# 4. plaza 딕셔너리 내부에 kind가 없는 경우 또는 int인 경우
	print("\n[Step 4] plaza 딕셔너리 이상 케이스 테스트")
	var t3: Dictionary = {"plaza": {"kind": 0}, "pos": seowon_pos, "building": 0}
	var data3: Dictionary = InspectNarrativeGenerator.build_inspect_data(t3, null, grid, null)
	print("plaza 이상 케이스 반환: ", data3)
	assert(data3.has("title"), "이상 케이스에서도 무중단 반환 필수")

	# 5. 서원 타일 클릭 시 CityLayer 단의 이름 및 facility_id 판정 테스트
	print("\n[Step 5] 서원 타일 메타데이터 안전 변환 테스트")
	var p_info: Dictionary = tile.get("plaza", {})
	var p_kind: String = str(p_info.get("kind", ""))
	assert(p_kind == "seowon", "p_kind가 seowon이어야 함")
	var b_name := "빈 터"
	if p_kind in ["seowon", "maegok_seowon"] or str(tile.get("facility_id", "")) in ["seowon", "maegok_seowon"]:
		b_name = "화성 유학 서원 (書院)"
	assert(b_name == "화성 유학 서원 (書院)", "b_name 서원 매핑 실패")

	# 6. 서원 렌더링 텍스처 로드 테스트
	print("\n[Step 6] 서원 렌더링 텍스처 로드 테스트")
	var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", "maegok_seowon", Vector2i(192, 160))
	print("maegok_seowon 텍스처: ", tex)
	assert(tex != null, "maegok_seowon 텍스처 로드 실패")

	print("\n=== 서원 테스트 정상 통과 ===")
	quit(0)
