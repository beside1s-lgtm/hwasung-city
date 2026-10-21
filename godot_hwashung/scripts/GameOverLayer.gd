extends CanvasLayer
class_name GameOverLayer

## PORT-TRACE [게임 오버]: 반란군·도적떼 공성에서 성 방호력이 공격력에 못 미치면 화성 함락 — 패배 화면.
## [다시 하기]는 장면을 새로 불러 처음부터, [마지막 저장 불러오기]는 가장 최근 저장 슬롯을 그 자리에서 복원,
## [타이틀로]는 장면을 다시 불러 타이틀 화면으로.

signal load_latest
var _panel: Control

func show_game_over(reason: String, has_save: bool) -> void:
	layer = 60
	if _panel:
		_panel.queue_free()
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_panel = root
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.78)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -150.0
	box.offset_bottom = 150.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title := Label.new()
	title.text = "화성 함락(華城 陷落)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("e8453a"))
	box.add_child(title)
	var msg := Label.new()
	msg.text = reason + "\n정조의 개혁은 여기서 멈추었습니다."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(500, 70)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", Color("f5efe0"))
	box.add_child(msg)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	box.add_child(hb)
	var again := _btn("⟲ 다시 하기", Color(0.45, 0.12, 0.08))
	again.pressed.connect(func(): get_tree().reload_current_scene())
	hb.add_child(again)
	var load_btn := _btn("📂 마지막 저장 불러오기", Color(0.12, 0.22, 0.38))
	load_btn.disabled = not has_save
	load_btn.pressed.connect(func():
		emit_signal("load_latest")
		_panel.queue_free()
		_panel = null
	)
	hb.add_child(load_btn)
	var title_btn := _btn("🏯 첫 화면으로", Color(0.30, 0.26, 0.20))
	title_btn.pressed.connect(func(): get_tree().reload_current_scene())
	hb.add_child(title_btn)

func _btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 40)
	b.add_theme_font_size_override("font_size", 14)
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate()
	sh.bg_color = col.lightened(0.18)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", Color(0.99, 0.96, 0.86))
	return b
