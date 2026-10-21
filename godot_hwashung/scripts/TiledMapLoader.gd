extends Node2D
class_name TiledMapLoader

## Tiled JSON(.tmj) 맵을 파싱하여 Godot 4 TileMapLayer로 구성하는 로더

@export var map_path: String = "res://maps/hwashung_map.tmj"
@export var tileset_texture_path: String = "res://assets/terrain_tileset.png"

var tile_set: TileSet

func _ready() -> void:
	_create_tileset()
	load_tiled_map(map_path)

func _create_tileset() -> void:
	tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN # PORT-TRACE P12: 기본 stacked 레이아웃이면 마름모 배치가 깨짐
	tile_set.tile_size = Vector2i(64, 32)

	var tex: Texture2D = null
	if ResourceLoader.exists(tileset_texture_path) or FileAccess.file_exists(tileset_texture_path):
		tex = load(tileset_texture_path) as Texture2D
	if not tex:
		var fallback_img := Image.create_empty(256, 160, false, Image.FORMAT_RGBA8)
		tex = ImageTexture.create_from_image(fallback_img)

	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(64, 32)

	# 4x5 아틀라스 그리드 등록 (PORT-TRACE P23: 16번 성저 미편입지 타일 추가로 5행)
	for row in range(5):
		for col in range(4):
			source.create_tile(Vector2i(col, row))

	tile_set.add_source(source, 1)

func load_tiled_map(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Map file does not exist: " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		push_error("JSON Parse Error in map: " + json.get_error_message())
		return

	var map_data = json.data
	var map_w = int(map_data.get("width", 20))
	var _map_h = int(map_data.get("height", 20))
	var layers = map_data.get("layers", [])

	for layer_data in layers:
		var layer_name = layer_data.get("name", "Layer")
		var raw_data = layer_data.get("data", [])

		var tml = TileMapLayer.new()
		tml.name = layer_name
		tml.tile_set = tile_set
		# Y-Sort 활성화로 앞 건물 뒤 건물 자동 정렬
		tml.y_sort_enabled = true
		add_child(tml)

		for i in range(raw_data.size()):
			var gid = int(raw_data[i])
			if gid <= 0:
				continue

			# PORT-TRACE P23 버그 수정: generate_map.py/generate_tileset.py의 모든 주석과 값은
			# "데이터 값 == tiles[] 배열 인덱스"를 직접 가리키도록 작성되어 있었다(예: "3: 수원천
			# 물" 주석은 tiles[3]을 의미). 이전 코드의 `gid - 1` 오프셋은 이를 한 칸씩 밀려
			# 읽어(gid=3이 실제로는 tiles[2] "황토 평지"를 그리는 등) 물/모래톱/절벽/완경사 색이
			# 서로 뒤바뀌어 렌더링되는 원인이었다. gid=0은 "타일 없음"으로 이미 위에서 걸러지므로
			# 오프셋 없이 gid를 그대로 배열 인덱스로 사용한다.
			var tile_idx = gid
			var atlas_x: int = tile_idx % 4
			var atlas_y: int = int(float(tile_idx) / 4.0)

			var gx: int = i % map_w
			var gy: int = int(float(i) / float(map_w))

			tml.set_cell(Vector2i(gx, gy), 1, Vector2i(atlas_x, atlas_y))

	print("Tiled Isometric Map Loaded Successfully: %d layers" % layers.size())
