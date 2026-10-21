class_name SpeechBubbleItem
extends Control

## [경량 전역 말풍선 풀 아이템 노드]
## 개별 NPC에 자식 노드로 생성되지 않고, 전역 풀(최대 3개)에서 대사가 있을 때만
## 화면 내 NPC 위치에 부착되어 렌더링된 후 즉시 풀로 반납됩니다.

var target_owner: Node2D = null
var life_timer: float = 0.0
var text_content: String = ""
var tag_content: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_data(p_owner: Node2D, p_text: String, p_tag: String, p_duration: float) -> void:
	target_owner = p_owner
	text_content = p_text
	tag_content = p_tag
	life_timer = p_duration
	visible = true
	if target_owner != null and is_instance_valid(target_owner):
		global_position = target_owner.global_position + Vector2(0.0, -32.0)
	queue_redraw()

func clear_data() -> void:
	visible = false
	target_owner = null
	life_timer = 0.0
	text_content = ""
	tag_content = ""

func _process(delta: float) -> void:
	if not visible:
		return
	life_timer -= delta
	if life_timer <= 0.0 or target_owner == null or not is_instance_valid(target_owner) or not target_owner.visible:
		clear_data()
		return
	global_position = target_owner.global_position + Vector2(0.0, -32.0)
	queue_redraw()

func _draw() -> void:
	if text_content == "":
		return
	var font: Font = ThemeDB.fallback_font
	var font_sz: int = 12
	var str_w: float = font.get_string_size(text_content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x if font != null else 60.0
	var tag_w: float = font.get_string_size(tag_content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x if (font != null and tag_content != "") else 0.0
	var box_w: float = maxf(str_w + 16.0, tag_w + 24.0)
	var box_h: float = 28.0
	var rect := Rect2(-box_w * 0.5, -box_h, box_w, box_h)

	# 1. 그림자
	draw_rect(Rect2(rect.position + Vector2(1.5, 1.5), rect.size), Color(0.0, 0.0, 0.0, 0.25), true)
	# 2. 크림색 한지 바탕
	draw_rect(rect, Color("fffdf5"), true)
	draw_rect(rect, Color("3d2817"), false, 1.2)
	# 3. 꼬리표
	var tail := PackedVector2Array([Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Vector2(0.0, 4.0)])
	draw_colored_polygon(tail, Color("fffdf5"))
	draw_line(tail[0], tail[2], Color("3d2817"), 1.2)
	draw_line(tail[1], tail[2], Color("3d2817"), 1.2)
	# 4. 텍스트
	if font != null:
		if tag_content != "":
			draw_string(font, Vector2(rect.position.x + 6.0, rect.position.y + 11.0), tag_content, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("912323"))
			draw_string(font, Vector2(rect.position.x + 6.0, rect.position.y + 23.0), text_content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color("1f1812"))
		else:
			draw_string(font, Vector2(rect.position.x + 6.0, rect.position.y + 18.0), text_content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color("1f1812"))
