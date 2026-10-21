class_name ModalBase
extends CanvasLayer

## [공통 팝업 모달 베이스 프레임]
## 조선 한지 및 옻칠 단청 스타일의 규격화된 팝업 모달.
## 부드러운 슬라이드업 & 페이드인 트윈 및 버튼 마이크로 인터랙션을 기본 제공합니다.

signal closed
signal confirmed

@onready var backdrop: ColorRect = $Backdrop
@onready var modal_panel: PanelContainer = $CenterContainer/ModalPanel
@onready var label_title: Label = $CenterContainer/ModalPanel/VBox/Header/TitleLabel
@onready var btn_close: Button = $CenterContainer/ModalPanel/VBox/Header/CloseButton
@onready var content_container: VBoxContainer = $CenterContainer/ModalPanel/VBox/ContentContainer
@onready var action_container: HBoxContainer = $CenterContainer/ModalPanel/VBox/ActionContainer
@onready var btn_confirm: Button = $CenterContainer/ModalPanel/VBox/ActionContainer/ConfirmButton
@onready var btn_cancel: Button = $CenterContainer/ModalPanel/VBox/ActionContainer/CancelButton

var _open_tween: Tween = null
var _close_tween: Tween = null

func _ready() -> void:
	layer = 60
	ThemeManager.apply_title_font(label_title, ThemeManager.FONT_SIZE_TITLE)
	ThemeManager.bind_button_micro_interaction(btn_close)
	ThemeManager.bind_button_micro_interaction(btn_confirm)
	ThemeManager.bind_button_micro_interaction(btn_cancel)

	btn_close.pressed.connect(close_modal)
	btn_cancel.pressed.connect(close_modal)
	btn_confirm.pressed.connect(func():
		confirmed.emit()
		close_modal()
	)

	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_modal()
	)

func set_title(title_text: String) -> void:
	if label_title:
		label_title.text = title_text

func open_modal() -> void:
	visible = true
	modal_panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	modal_panel.scale = Vector2(0.95, 0.95)
	modal_panel.pivot_offset = modal_panel.size * 0.5

	if _open_tween and _open_tween.is_running():
		_open_tween.kill()

	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	_open_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.20)
	_open_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.20)

func close_modal() -> void:
	if _close_tween and _close_tween.is_running():
		_close_tween.kill()

	_close_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(backdrop, "modulate:a", 0.0, 0.15)
	_close_tween.tween_property(modal_panel, "modulate:a", 0.0, 0.15)
	_close_tween.tween_property(modal_panel, "scale", Vector2(0.95, 0.95), 0.15)
	_close_tween.chain().tween_callback(func():
		visible = false
		closed.emit()
	)
