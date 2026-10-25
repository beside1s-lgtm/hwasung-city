extends CanvasLayer
class_name DiplomacyQuizPopup

## 외교 문답 팝업 (1876 조약 회담·동맹 협상 공용)
## 보기 4개 중 하나를 고른다. 맞히면 해설을 보여 주고 다음 문항, 하나라도 틀리면 바로 실패.
## 열려 있는 동안 시간을 멈추고, 닫히면 원래 배속으로 돌린다.

var _questions: Array = []
var _idx: int = 0
var _on_success: Callable
var _on_fail: Callable
var _time_manager: TimeManager
var _prev_speed: int = TimeManager.SpeedMode.NORMAL
var _title: String = ""
## 역사 사전 [근대 외교와 결말] 조각: 문항마다("%d" 자리에 번호) / 문답을 마칠 때(맞든 틀리든) 연다
var piece_per_question: String = ""
var piece_on_finish: String = ""
var _col: Color = Color("1d4ed8")

var _vbox: VBoxContainer
var _q_label: Label
var _btn_box: VBoxContainer

static func open(parent: Node, title: String, intro: String, questions: Array, col: Color, tm: TimeManager, on_success: Callable, on_fail: Callable) -> DiplomacyQuizPopup:
	var p: DiplomacyQuizPopup = load("res://scripts/DiplomacyQuizPopup.gd").new() # 자기 class_name 직접 참조 대신 경로로 만든다(전역 클래스 캐시가 늦게 갱신될 때 대비)
	p.layer = 97
	p._questions = questions
	p._on_success = on_success
	p._on_fail = on_fail
	p._time_manager = tm
	p._title = title
	p._col = col
	parent.add_child(p)
	p._build(intro)
	return p

func _build(intro: String) -> void:
	if _time_manager:
		_prev_speed = _time_manager.current_speed
		_time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	var panel := ModernizationManager._make_panel(self, _title, intro, _col)
	panel.custom_minimum_size = Vector2(620, 0)
	_vbox = panel.get_meta("vbox")
	(_vbox.get_child(1) as Label).custom_minimum_size = Vector2(580, 0)
	_q_label = Label.new()
	_q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q_label.custom_minimum_size = Vector2(580, 0)
	_q_label.add_theme_color_override("font_color", Color("fde68a"))
	_vbox.add_child(_q_label)
	_btn_box = VBoxContainer.new()
	_btn_box.add_theme_constant_override("separation", 6)
	_vbox.add_child(_btn_box)
	_show_question()

func _clear_buttons() -> void:
	for c in _btn_box.get_children():
		c.queue_free()

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(580, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_btn_box.add_child(b)

func _show_question() -> void:
	_clear_buttons()
	var q: Dictionary = _questions[_idx]
	_q_label.text = "【%d / %d】 %s" % [_idx + 1, _questions.size(), q["q"]]
	var answers: Array = q["a"]
	for i in range(answers.size()):
		var pick := i
		_add_button("%d) %s" % [i + 1, answers[i]], func(): _answer(pick))

func _answer(pick: int) -> void:
	var q: Dictionary = _questions[_idx]
	_clear_buttons()
	if piece_per_question != "":
		GameProgressManager.unlock_puzzle_piece("modern", piece_per_question % _idx)
	if pick != int(q["c"]):
		_q_label.text = "✖ 협상이 틀어졌습니다.\n\n정답: %s\n%s" % [q["a"][int(q["c"])], q["why"]]
		_add_button("확인", func(): _finish(false))
		return
	_q_label.text = "✔ 상대가 수긍합니다.\n\n%s" % q["why"]
	_idx += 1
	if _idx >= _questions.size():
		_add_button("협상 타결", func(): _finish(true))
	else:
		_add_button("다음 문답으로", _show_question)

func _finish(ok: bool) -> void:
	if piece_on_finish != "":
		GameProgressManager.unlock_puzzle_piece("modern", piece_on_finish)
	queue_free()
	if _time_manager:
		_time_manager.set_speed(_prev_speed as TimeManager.SpeedMode)
	if ok:
		if _on_success.is_valid():
			_on_success.call()
	elif _on_fail.is_valid():
		_on_fail.call()
