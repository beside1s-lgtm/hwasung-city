extends CanvasLayer
class_name InspectPopup

## 살피기(Inspect) 전용 고풍스러운 한지 모달 팝업
## 좌측 고증 일러스트/초상화 + 우측 20자 규격 동적 내러티브 렌더링

signal closed

var _backdrop: ColorRect
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _title_label: Label
var _desc_label: Label
var _close_btn: Button
var _bottom_btn: Button
var _action_buttons_container: HBoxContainer
var trial_manager: TrialManager = null
var panels: PanelController = null
var seojangdae_popup: SeojangdaePopup = null
var yeonmudae_popup: YeonmudaePopup = null

func _init() -> void:
	layer = 85 # HUD 상단, 일반 모달과 조화

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 1. 반투명 배경 딤 (클릭 시 닫기)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 2. 중앙 한지 두루마리 팝업 패널
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 240)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -310
	_panel.offset_top = -120
	_panel.offset_right = 310
	_panel.offset_bottom = 120

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5")          # 한지 크림색
	sb.border_color = Color("7a5835")      # 고풍스러운 고목 목재 테두리
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# 3. 메인 수평 레이아웃 (좌: 초상화, 우: 텍스트 정보)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	_panel.add_child(hbox)

	# [좌측] 초상화 / 대표 일러스트 영역
	var left_box := VBoxContainer.new()
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(left_box)

	var p_frame := PanelContainer.new()
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color("f7f3e8")
	p_sb.border_color = Color("b39268")
	p_sb.set_border_width_all(2)
	p_sb.set_corner_radius_all(6)
	p_sb.set_content_margin_all(4)
	p_frame.add_theme_stylebox_override("panel", p_sb)
	left_box.add_child(p_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(160, 160)
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # 도트 그림을 또렷하게(80px → 160px)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_frame.add_child(_portrait_rect)

	# [우측] 제목, 구분선, 내러티브, 닫기 버튼
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	hbox.add_child(right_box)

	# 상단 행: 제목 + 우측 상단 X 닫기 버튼
	var top_row := HBoxContainer.new()
	right_box.add_child(top_row)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("8f1d1d")) # 조선 궁중 홍색
	top_row.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.add_theme_font_size_override("font_size", 15)
	_close_btn.add_theme_color_override("font_color", Color("7a5835"))
	_close_btn.pressed.connect(close_inspect)
	top_row.add_child(_close_btn)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color("c9b28b")
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	right_box.add_child(sep)

	# 본문 텍스트 (20자 2~4줄 규격)
	_desc_label = Label.new()
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", Color("2c1a0e")) # 전통 먹물색
	_desc_label.add_theme_constant_override("line_spacing", 5)
	right_box.add_child(_desc_label)

	# 하단 버튼 행 (특수 기능 버튼들 + 확인 닫기 버튼)
	var btm_row := HBoxContainer.new()
	btm_row.alignment = BoxContainer.ALIGNMENT_END
	btm_row.add_theme_constant_override("separation", 8)
	right_box.add_child(btm_row)

	_action_buttons_container = HBoxContainer.new()
	_action_buttons_container.add_theme_constant_override("separation", 6)
	btm_row.add_child(_action_buttons_container)

	_bottom_btn = Button.new()
	_bottom_btn.text = "확인"
	_bottom_btn.custom_minimum_size = Vector2(86, 32)
	_bottom_btn.add_theme_font_size_override("font_size", 14)
	_bottom_btn.pressed.connect(close_inspect)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color("8c6239")
	btn_sb.border_color = Color("5c3a21")
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(4)
	btn_sb.set_content_margin_all(4)
	_bottom_btn.add_theme_stylebox_override("normal", btn_sb)

	var btn_hover_sb := StyleBoxFlat.new()
	btn_hover_sb.bg_color = Color("a87848")
	btn_hover_sb.border_color = Color("5c3a21")
	btn_hover_sb.set_border_width_all(1)
	btn_hover_sb.set_corner_radius_all(4)
	btn_hover_sb.set_content_margin_all(4)
	_bottom_btn.add_theme_stylebox_override("hover", btn_hover_sb)
	btm_row.add_child(_bottom_btn)

func open_inspect(title_text: String, desc_text: String, tex: Texture2D) -> void:
	if _title_label == null:
		_build_ui()
	_title_label.text = _sanitize_korean_title(title_text)
	_desc_label.text = desc_text
	var target_tex: Texture2D = tex if tex != null else InspectNarrativeGenerator.get_portrait("commoner")
	_portrait_rect.texture = target_tex
	if target_tex != null and (target_tex.get_width() >= 96 or target_tex.get_height() >= 96):
		_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_update_action_buttons(_title_label.text)
	# 근대화 시대에 개편·조성한 건물은 버튼은 옛 이름으로 고르고, 제목만 새 이름으로 보인다
	if UrbanEvolutionManager.instance:
		_title_label.text = UrbanEvolutionManager.instance.modern_title(_title_label.text)
	visible = true

func _clear_action_buttons() -> void:
	if _action_buttons_container == null:
		return
	for ch in _action_buttons_container.get_children():
		ch.queue_free()

func _add_action_button(label_text: String, on_click: Callable, bg_color: Color = Color("8f1d1d")) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 32)
	btn.add_theme_font_size_override("font_size", 13)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var act_sb := StyleBoxFlat.new()
	act_sb.bg_color = bg_color
	act_sb.border_color = Color("d4af37")
	act_sb.set_border_width_all(1)
	act_sb.set_corner_radius_all(4)
	act_sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", act_sb)

	var act_hover := act_sb.duplicate() as StyleBoxFlat
	act_hover.bg_color = bg_color.lightened(0.18)
	btn.add_theme_stylebox_override("hover", act_hover)
	btn.add_theme_color_override("font_color", Color("ffffff"))

	btn.pressed.connect(func():
		close_inspect()
		on_click.call()
	)
	_action_buttons_container.add_child(btn)
	return btn

func _update_action_buttons(s_title: String) -> void:
	_clear_action_buttons()

	# 0-2. 관아·순라청·멸화군: 근대 관공서 개편(버튼만 더하고 기존 버튼은 아래에서 그대로 붙는다)
	var civic_id := UrbanEvolutionManager.civic_id_for_title(s_title)
	if UrbanEvolutionManager.is_active() and civic_id != "":
		var cu: UrbanEvolutionManager = UrbanEvolutionManager.instance
		var info: Dictionary = UrbanEvolutionManager.CIVIC_UPGRADES[civic_id]
		if ModernPoliticsManager.is_presidential():
			_add_action_button("📜 대통령제: 개편은 국정 건의로만 승인할 수 있습니다", func(): if panels: panels.open_action_modal("proposals"), Color("1d4ed8"))
		elif not cu.upgrades_unlocked():
			_add_action_button("🔒 석조 전환 완료 후 개편 가능 (진행 %d%%)" % int(UrbanEvolutionManager.instance.stone_ratio * 100.0), func(): pass, Color("44403c"))
		elif cu.is_civic_upgraded(civic_id):
			_add_action_button("✓ %s 개편 완료" % info["name"], func(): pass, Color("2e5a2e"))
		else:
			_add_action_button("🏛️ %s 개편 (금 %d냥, %s)" % [info["name"], int(info["cost"]), info["effect"]], func():
				var ok := cu.build_civic_upgrade(civic_id)
				if panels and panels.hud:
					panels.hud._show_toast(("%s이(가) %s(으)로 개편되었습니다!" % [info["old"], info["name"]]) if ok else "국고가 부족해 개편할 수 없습니다. (%d냥 필요)" % int(info["cost"]), "🏛️" if ok else "⚠")
			, Color("334155"))

	# 0-3. 난전 마당·어린이 마당·여인 놀이마당: 근대 공원 개편
	var plaza_kind := UrbanEvolutionManager.plaza_kind_for_title(s_title)
	if UrbanEvolutionManager.is_active() and plaza_kind != "":
		var pu: UrbanEvolutionManager = UrbanEvolutionManager.instance
		var pinfo: Dictionary = UrbanEvolutionManager.PLAZA_UPGRADES[plaza_kind]
		if ModernPoliticsManager.is_presidential():
			_add_action_button("📜 대통령제: 개편은 국정 건의로만 승인할 수 있습니다", func(): if panels: panels.open_action_modal("proposals"), Color("1d4ed8"))
		elif not pu.upgrades_unlocked():
			_add_action_button("🔒 석조 전환 완료 후 개편 가능 (진행 %d%%)" % int(pu.stone_ratio * 100.0), func(): pass, Color("44403c"))
		elif pu.is_plaza_upgraded(plaza_kind):
			_add_action_button("✓ %s 조성 완료" % pinfo["name"], func(): pass, Color("2e5a2e"))
		else:
			_add_action_button("🌳 %s(으)로 개편 (금 %d냥, 민심 +%d)" % [pinfo["name"], int(pinfo["cost"]), int(pinfo["loyalty"])], func():
				var ok := pu.build_plaza_upgrade(plaza_kind)
				if panels and panels.hud:
					panels.hud._show_toast(("도시의 %s이(가) 모두 %s(으)로 바뀌었습니다!" % [pinfo["old"], pinfo["name"]]) if ok else "국고가 부족해 개편할 수 없습니다. (%d냥 필요)" % int(pinfo["cost"]), "🌳" if ok else "⚠")
			, Color("15803d"))
		return

	# 0-1. 축만제·만석거: 근대화 시대 호수공원 조성
	var lake_id := UrbanEvolutionManager.lake_park_id_for_title(s_title)
	if UrbanEvolutionManager.is_active() and lake_id != "":
		var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
		var park_name: String = UrbanEvolutionManager.LAKE_PARKS[lake_id]["name"]
		if ModernPoliticsManager.is_presidential():
			_add_action_button("📜 대통령제: 개편은 국정 건의로만 승인할 수 있습니다", func(): if panels: panels.open_action_modal("proposals"), Color("1d4ed8"))
		elif not um.upgrades_unlocked():
			_add_action_button("🔒 석조 전환 완료 후 개편 가능 (진행 %d%%)" % int(UrbanEvolutionManager.instance.stone_ratio * 100.0), func(): pass, Color("44403c"))
		elif um.is_lake_park(lake_id):
			_add_action_button("✓ %s 조성 완료" % park_name, func(): pass, Color("2e5a2e"))
		else:
			var cost := UrbanEvolutionManager.LAKE_PARK_COST
			_add_action_button("🌳 %s 조성 (금 %d냥, 민심 +%d)" % [park_name, cost, UrbanEvolutionManager.LAKE_PARK_LOYALTY], func():
				var ok := um.build_lake_park(lake_id)
				if panels and panels.hud:
					panels.hud._show_toast(("%s이(가) 조성되었습니다! 시민들의 쉼터가 생겼습니다." % park_name) if ok else "국고가 부족해 호수공원을 조성할 수 없습니다. (%d냥 필요)" % cost, "🌳" if ok else "⚠")
			, Color("15803d"))
		return

	# 0. 사대문: 근대화 시대 국제외교 회담
	if ModernizationManager.is_active() and ModernizationManager.is_great_gate(s_title):
		var open_dip := func():
			if panels:
				panels.open_action_modal("diplomacy")
		if ModernizationManager.instance.diplomacy_unlocked:
			_add_action_button("🌐 국제외교 회담 개최", open_dip, Color("1d4ed8"))
		else:
			_add_action_button("🔒 국제외교 (열강 침공 격퇴 후 해금)", open_dip, Color("44403c"))
		return

	# 1. 서장대: 서장대 야조훈련
	if s_title.contains("서장대"):
		var drill_cost: Dictionary = DifficultyManager.get_military_drill_cost()
		var g_cost: int = int(drill_cost.get("gold", 2000))
		var r_cost: int = int(drill_cost.get("rice", 1000))
		var cd_months: int = 0
		if panels and panels.sim:
			cd_months = panels.sim.seojangdae_drill_cd_months

		var cb_seojangdae := func():
			close_inspect()
			if seojangdae_popup != null:
				seojangdae_popup.open_seojangdae_popup()
			elif panels:
				RoyalCourtManager.execute_seojangdae_drill(panels)

		if cd_months > 0:
			_add_action_button(
				"✓ 올해 야조 실시 완료 (다음 훈련까지 %d개월)" % cd_months,
				cb_seojangdae,
				Color("2e5a2e")
			)
		else:
			_add_action_button(
				"⚔️ 서장대 야조훈련 지휘 (금 %d냥, 곡 %d석)" % [g_cost, r_cost],
				cb_seojangdae,
				Color("78350f")
			)
		return

	# 2. 연무대: 장용영 무예 사열 (군사훈련)
	if s_title.contains("연무대") or s_title.contains("동장대"):
		# 근대화 시대: 신식 군사기지 개편
		if UrbanEvolutionManager.is_active():
			var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
			if ModernPoliticsManager.is_presidential():
				_add_action_button("📜 대통령제: 개편은 국정 건의로만 승인할 수 있습니다", func(): if panels: panels.open_action_modal("proposals"), Color("1d4ed8"))
			elif not um.upgrades_unlocked():
				_add_action_button("🔒 석조 전환 완료 후 개편 가능 (진행 %d%%)" % int(UrbanEvolutionManager.instance.stone_ratio * 100.0), func(): pass, Color("44403c"))
			elif um.military_base:
				_add_action_button("✓ %s (국방 +%d)" % [UrbanEvolutionManager.MILITARY_BASE_NAME, UrbanEvolutionManager.MILITARY_BASE_DEFENSE], func(): pass, Color("2e5a2e"))
			else:
				var mb_cost := UrbanEvolutionManager.MILITARY_BASE_COST
				_add_action_button("🪖 신식 군사기지 개편 (금 %d냥, 국방 +%d)" % [mb_cost, UrbanEvolutionManager.MILITARY_BASE_DEFENSE], func():
					var ok := um.build_military_base()
					if panels and panels.hud:
						panels.hud._show_toast(("연무대가 %s로 개편되었습니다! 신식 군대가 주둔합니다." % UrbanEvolutionManager.MILITARY_BASE_NAME) if ok else "국고가 부족해 군사기지를 개편할 수 없습니다. (%d냥 필요)" % mb_cost, "🪖" if ok else "⚠")
				, Color("3f3f46"))
		var drill_cost: Dictionary = DifficultyManager.get_yeonmudae_drill_cost()
		var g_cost: int = int(drill_cost.get("gold", 2000))
		var r_cost: int = int(drill_cost.get("rice", 2000))
		var cd_months: int = 0
		if panels and panels.sim:
			cd_months = panels.sim.yeonmudae_drill_cd_months

		var cb_yeonmudae := func():
			close_inspect()
			if yeonmudae_popup != null:
				yeonmudae_popup.open_yeonmudae_popup()
			elif panels:
				RoyalCourtManager.execute_yeonmudae_drill(panels)

		if cd_months > 0:
			_add_action_button(
				"✓ 올해 무예 사열 완료 (%d개월 후 가능)" % cd_months,
				cb_yeonmudae,
				Color("1b4d3e")
			)
		else:
			_add_action_button(
				"⚔️ 장용영 무예 사열 (금 %d냥, 곡 %d석)" % [g_cost, r_cost],
				cb_yeonmudae,
				Color("1e3a5f")
			)
		return

	# 3. 화성유수부 동헌(관아): 호포책 시행 및 도적떼 퇴치
	if s_title.contains("관아") or s_title.contains("동헌") or s_title.contains("유수부"):
		var has_trial: bool = trial_manager != null and trial_manager.has_pending_trial()
		if has_trial:
			var cb_trial := func():
				if trial_manager:
					trial_manager.open_trial_ui()
			_add_action_button(
				"⚖️ [원옥 친국]",
				cb_trial,
				Color("8f1d1d")
			)
		# ① 호포책 정무 버튼
		var cb_tiger := func():
			if panels:
				RoyalCourtManager.execute_gwana_action("tiger", panels)
		_add_action_button(
			"📜 호포책 정무",
			cb_tiger,
			Color("8f1d1d")
		)
		# ② 도적떼 토벌 출동 버튼
		var cb_bandit := func():
			if panels:
				RoyalCourtManager.execute_gwana_action("bandit", panels)
		_add_action_button(
			"🛡️ 도적떼 토벌 출동",
			cb_bandit,
			Color("2c3e50")
		)
		return

	# 4. 화성행궁: 시강원 세자서연 (경연) — 1800년 엔딩(순조 즉위) 뒤·현대 정치체제 전환 뒤(대통령궁)에는 없음
	if (s_title.contains("행궁") or s_title.contains("봉수당") or s_title.contains("신풍루")) and not CrownPrinceEducationManager.prince_affairs_closed(panels.sim.current_year if panels and panels.sim else 1789):
		var cb_prince := func():
			if panels:
				panels.open_crown_prince_popup()
		_add_action_button(
			"👑 시강원 세자서연 (경연)",
			cb_prince,
			Color("1e3a5f")
		)
		return

	# 5. 수원향교: 실학 강독 시험 퀴즈 (1년 1회, 근엄한 경어체 대사성)
	if s_title.contains("향교") or s_title.contains("대성전") or s_title.contains("명륜당"):
		var cur_year: int = 1789
		if panels and panels.sim:
			cur_year = panels.sim.current_year
		var qm: AcademyQuizManager = AcademyQuizManager.get_instance()
		var can_q: bool = qm.can_take_quiz("hyanggyo", cur_year)
		var cb_hyanggyo := func():
			AcademyQuizPopup.open_quiz("hyanggyo", cur_year, panels.sim if panels else null)

		if can_q:
			_add_action_button(
				"📖 [실학 강독 시험] 도전",
				cb_hyanggyo,
				Color("2e5a2e")
			)
		else:
			var last_y: int = qm.get_last_quiz_year("hyanggyo")
			_add_action_button(
				"✓ 올해 강독 완료 (%d년 재도전)" % (last_y + 1),
				cb_hyanggyo,
				Color("5c3a21")
			)
		return

	# 6. 서원: 수원화성 역사 퀴즈 (1년 1회, 친절한 선생님 말투)
	if s_title.contains("서원") or s_title.contains("강당"):
		var cur_year: int = 1789
		if panels and panels.sim:
			cur_year = panels.sim.current_year
		var qm: AcademyQuizManager = AcademyQuizManager.get_instance()
		var can_q: bool = qm.can_take_quiz("seowon", cur_year)
		var cb_seowon := func():
			AcademyQuizPopup.open_quiz("seowon", cur_year, panels.sim if panels else null)

		if can_q:
			_add_action_button(
				"📖 [수원화성 퀴즈] 도전",
				cb_seowon,
				Color("1b4d3e")
			)
		else:
			var last_y: int = qm.get_last_quiz_year("seowon")
			_add_action_button(
				"✓ 올해 퀴즈 완료 (%d년 재도전)" % (last_y + 1),
				cb_seowon,
				Color("5c3a21")
			)
		return

	# 7. 서당: 세시풍속 문답 퀴즈 (1년 1회, 아랫것들에게 호통치는 훈장님)
	if s_title.contains("서당") or s_title.contains("글방"):
		var cur_year: int = 1789
		if panels and panels.sim:
			cur_year = panels.sim.current_year
		var qm: AcademyQuizManager = AcademyQuizManager.get_instance()
		var can_q: bool = qm.can_take_quiz("seodang", cur_year)
		var cb_seodang := func():
			AcademyQuizPopup.open_quiz("seodang", cur_year, panels.sim if panels else null)

		if can_q:
			_add_action_button(
				"📖 [세시풍속 퀴즈] 도전",
				cb_seodang,
				Color("8f1d1d")
			)
		else:
			var last_y: int = qm.get_last_quiz_year("seodang")
			_add_action_button(
				"✓ 올해 문답 완료 (%d년 재도전)" % (last_y + 1),
				cb_seodang,
				Color("5c3a21")
			)
		return



func _sanitize_korean_title(raw_title: String) -> String:
	var trimmed: String = raw_title.strip_edges()
	if trimmed == "":
		return "화성 시설"
	var key_cand: String = trimmed.to_lower().replace(" ", "_")
	if InspectNarrativeGenerator.KOREAN_FACILITY_NAMES.has(key_cand):
		return str(InspectNarrativeGenerator.KOREAN_FACILITY_NAMES[key_cand])
	if InspectNarrativeGenerator.KOREAN_NAMES.has(key_cand):
		return str(InspectNarrativeGenerator.KOREAN_NAMES[key_cand])

	# 패턴 기반 검사 (Res 2, Gwana Site 등)
	if key_cand.begins_with("res_"):
		if key_cand == "res_1": return "소박한 서민 초가집"
		if key_cand == "res_2": return "단정한 살림 기와집 (여염집)"
		if key_cand == "res_3": return "고급 사대부 기와집"
		return "단정한 살림 기와집 (여염집)"
	elif key_cand.contains("gwana"):
		return "화성유수부 동헌 (관아)"
	elif key_cand.contains("seowon"):
		return "화성 유학 서원 (書院)"
	elif key_cand.contains("seodang"):
		return "동네 서당 (글방)"

	# 영문 식별자가 그대로 노출되는 것을 방지
	var has_hangul: bool = false
	var has_alpha: bool = false
	for i: int in range(trimmed.length()):
		var c: int = trimmed.unicode_at(i)
		if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E):
			has_hangul = true
		elif (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			has_alpha = true

	if not has_hangul and has_alpha:
		return InspectNarrativeGenerator.get_korean_name(key_cand, "화성 시설")

	return trimmed

func close_inspect() -> void:
	visible = false
	emit_signal("closed")

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		close_inspect()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			close_inspect()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_inspect()
		get_viewport().set_input_as_handled()
