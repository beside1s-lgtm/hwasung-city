extends Node2D
class_name GateSignboard

## 사대문 및 특수 수문/교량 상단 부유 현판 (World Nameplate)
## 규격: 금색 테두리 + 검은 바탕 + 금색 한글/한자 병기 현판 + LOD/거리 컬링

@export var gate_name: String = ""
@export var lod_min_zoom: float = 0.55

func _ready() -> void:
	z_index = 25 # 월드 타일 및 유닛 상단 부유

func setup_name(korean_name: String) -> void:
	gate_name = korean_name
	queue_redraw()

func setup(display_name: String) -> void:
	setup_name(display_name)


func _draw() -> void:
	if gate_name == "":
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x < lod_min_zoom:
		return # LOD/거리 컬링: 줌 아웃 시 과도한 드로우콜 차단

	var tag_size := Vector2(float(gate_name.length() * 11 + 16), 16)
	var tag_rect := Rect2(-tag_size * 0.5, tag_size)
	# 검은 바탕
	draw_rect(tag_rect, Color(0.12, 0.08, 0.05, 0.88))
	# 금색 테두리
	draw_rect(tag_rect, Color("e8b820"), false, 1.0)
	# 금색 텍스트
	draw_string(ThemeDB.fallback_font, Vector2(-tag_size.x * 0.5 + 8, 4), gate_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color("fef3c7"))
