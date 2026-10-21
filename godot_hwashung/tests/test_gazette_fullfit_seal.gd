extends SceneTree

## 비변사 시보 리팩토링 검증:
## 1. 지면 풀-핏(Full-Fit) 1060x680 레이아웃
## 2. 폰트 크기(헤드라인 26px, 부제목 17px, 본문 17px, 인용문 16px) 및 행간 6px
## 3. 우측 3단 기사 카드(sub1, sub2, sub3) 확장
## 4. 실물 유물 스타일 전서체 사각 관인(bibyeonsa_official_seal.png) 우측 하단 절대 고정(Bottom-Right Anchor)

func _init() -> void:
	print("\n=== [테스트 시작] 비변사 시보 풀-핏 레이아웃 & 전서체 관인 리디자인 검증 ===")
	call_deferred("_run_verification")

func _run_verification() -> void:
	var popup := BibyeonsaSiboPopup.new()
	root.add_child(popup)
	var sim := SimulationCore.new()
	var grid := GameGrid.new()
	popup.setup(sim, grid)
	popup.publish_edition(1)

	# 1. 메인 패널 사이즈 검증
	assert(popup._main_panel != null, "메인 패널 미존재")
	assert(popup._main_panel.custom_minimum_size == Vector2(1060, 680), "풀-핏 패널 규격 1060x680 불일치")
	print("  - [PASS] 메인 패널 1060x680 풀-핏 사이즈 검증 완료")

	# 2. 폰트 크기 및 행간 검증
	assert(popup._main_headline_lbl.get_theme_font_size("font_size") == 26, "헤드라인 26px 불일치")
	assert(popup._main_subhead_lbl.get_theme_font_size("font_size") == 17, "부제목 17px 불일치")
	assert(popup._main_body_lbl.get_theme_font_size("font_size") == 17, "본문 17px 불일치")
	assert(popup._main_body_lbl.get_theme_constant("line_spacing") == 6, "본문 행간 6px 불일치")
	assert(popup._main_interview_lbl.get_theme_font_size("font_size") == 16, "인용구 16px 불일치")
	print("  - [PASS] 폰트 크기(헤드라인 26px, 부제목 17px, 본문 17px, 인용문 16px) 및 행간 6px 가독성 검증 완료")

	# 3. 우측 3단 서브 기사 검증
	assert(popup._sub1_title_lbl != null and popup._sub1_body_lbl != null, "우측 상단 서브1 누락")
	assert(popup._sub2_title_lbl != null and popup._sub2_body_lbl != null, "우측 중단 서브2 누락")
	assert(popup._sub3_title_lbl != null and popup._sub3_body_lbl != null, "우측 하단 서브3 누락")
	assert(popup._sub1_body_lbl.get_theme_font_size("font_size") == 16, "서브1 폰트 16px 불일치")
	assert(popup._sub2_body_lbl.get_theme_font_size("font_size") == 16, "서브2 폰트 16px 불일치")
	assert(popup._sub3_body_lbl.get_theme_font_size("font_size") == 16, "서브3 폰트 16px 불일치")
	print("  - [PASS] 우측 지면 3단 기사 카드(상단/중단/하단) 풀-핏 배치 완료")

	# 4. 전서체 사각 관인 우측 하단 절대 고정(Bottom-Right Anchor) 검증
	assert(popup._seal_overlay_rect != null, "관인 오버레이 텍스처 노드 누락")
	assert(popup._seal_overlay_rect.anchor_left == 1.0 and popup._seal_overlay_rect.anchor_right == 1.0, "관인 수평 앵커 우측 고정 실패")
	assert(popup._seal_overlay_rect.anchor_top == 1.0 and popup._seal_overlay_rect.anchor_bottom == 1.0, "관인 수직 앵커 하단 고정 실패")
	assert(popup._seal_overlay_rect.texture != null, "관인 전서체 에셋 텍스처 로드 실패")
	assert(FileAccess.file_exists("res://assets/ui/bibyeonsa_official_seal.png"), "bibyeonsa_official_seal.png 파일 미존재")
	print("  - [PASS] 전통 전서체 사각 관인(bibyeonsa_official_seal.png) 우측 하단 절대 앵커 고정 완료")

	popup.queue_free()
	print("\n=== [테스트 완료] 비변사 시보 풀-핏 레이아웃 & 관인 리디자인 전 항목 통과! (PASS) ===\n")
	quit()
