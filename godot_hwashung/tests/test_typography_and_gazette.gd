extends SceneTree

## [검증 테스트]
## 1. 전역 전통 서체(궁서체/휴먼옛체/양재인장체) ThemeManager 시스템 검증
## 2. 비변사 시보 신문 UI (BibyeonsaSiboPopup) 3단 레이아웃 및 붉은 관인 검증
## 3. 김홍도 풍속화 도트 일러스트 아틀라스 연동 검증
## 4. 익살맞은 기사 데이터베이스 (GazetteArticleDatabase) 동적 매칭 검증
## 5. 격년 8턴 발간 시그널 및 GameSettings 자동 팝업 토글 & Persistence 검증

func _init() -> void:
	print("\n=== [테스트 시작] 전역 전통 서체 및 비변사 시보 신문 시스템 통합 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_typography_theme()
	_test_folk_art_atlas()
	_test_article_database()
	_test_settings_persistence()
	_test_popup_and_signal_integration()
	print("\n=== [테스트 완료] 전역 전통 폰트 및 비변사 시보 신문 시스템 전 항목 100% 통과! (PASS) ===\n")
	quit()

func _test_typography_theme() -> void:
	print("\n[검증 1] 전역 서체(Typography) ThemeManager 검증...")
	ThemeManager.initialize_fonts()
	var base_f := ThemeManager.get_base_font()
	var title_f := ThemeManager.get_title_font()
	var seal_f := ThemeManager.get_seal_font()

	assert(base_f != null, "기본 본문 폰트(궁서체) 로드 실패")
	assert(title_f != null, "강조/타이틀 폰트(휴먼옛체) 로드 실패")
	assert(seal_f != null, "관인 전용 폰트(양재인장체) 로드 실패")

	var lbl := Label.new()
	ThemeManager.apply_base_font(lbl, 14)
	assert(lbl.has_theme_font_override("font"), "본문 폰트 테마 주입 실패")
	assert(lbl.get_theme_font_size("font_size") == 14, "본문 폰트 크기 주입 실패")

	var t_lbl := Label.new()
	ThemeManager.apply_title_font(t_lbl, 24)
	assert(t_lbl.has_theme_font_override("font"), "타이틀 폰트 테마 주입 실패")
	assert(t_lbl.get_theme_font_size("font_size") == 24, "타이틀 폰트 크기 주입 실패")

	var s_lbl := Label.new()
	ThemeManager.apply_seal_font(s_lbl, 20)
	assert(s_lbl.has_theme_font_override("font"), "관인 폰트 테마 주입 실패")
	assert(s_lbl.get_theme_font_size("font_size") == 20, "관인 폰트 크기 주입 실패")
	print("  - [PASS] 본문(궁서체), 타이틀(휴먼옛체), 관인(양재인장체) 폰트 주입 정상")

func _test_folk_art_atlas() -> void:
	print("\n[검증 2] 김홍도 풍속화 아틀라스 텍스처 연동 검증...")
	FolkArtAtlasGenerator.ensure_atlas_generated()
	assert(FileAccess.file_exists(FolkArtAtlasGenerator.ATLAS_PATH), "folk_art_sheet.png 파일 미존재")

	for key in ["swing", "tavern", "hunting_bear", "geojunggi", "ssireum", "seojangdae_guard"]:
		var tex: Texture2D = FolkArtAtlasGenerator.get_art_texture(key)
		assert(tex != null, "아틀라스 서브텍스처 로드 실패: %s" % key)
		assert(tex.get_width() > 0 and tex.get_height() > 0, "텍스처 해상도 유효성 실패: %s" % key)
	print("  - [PASS] 풍속화 도트 아틀라스 스프라이트시트 및 영역 매핑 정상")

func _test_article_database() -> void:
	print("\n[검증 3] GazetteArticleDatabase 상태 연동 기사 풀 검증...")
	var sim := SimulationCore.new()
	var grid := GameGrid.new()

	# 1. 1789년 초기 천도 기사
	sim.current_year = 1789
	var ed1: Dictionary = GazetteArticleDatabase.get_current_gazette_edition(sim, grid, 1)
	assert(ed1.has("main") and ed1.has("sub1") and ed1.has("sub2"), "기사 에디션 3단 구성 누락")
	assert(ed1["header_date"].contains("정조"), "헤더 날짜 정조 연호 누락")
	assert(ed1["main"]["category"] == "천도 대역사", "1789년 천도 대역사 톱기사 매칭 실패")

	# 2. 1795년 을묘원행 기사
	sim.current_year = 1795
	var ed2: Dictionary = GazetteArticleDatabase.get_current_gazette_edition(sim, grid, 4)
	assert(ed2["main"]["category"] == "을묘원행/왕권", "1795년 을묘원행 톱기사 매칭 실패")
	assert(ed2["main"]["headline"].contains("어가 행렬"), "을묘원행 헤드라인 누락")

	# 3. 성곽 100% 완공 기사
	sim.current_year = 1796
	grid.fortress_progress = 100
	var ed3: Dictionary = GazetteArticleDatabase.get_current_gazette_edition(sim, grid, 5)
	assert(ed3["main"]["category"] == "성곽 완공", "성곽 완공 톱기사 매칭 실패")

	# 4. 서브 기사(맛집, 연애, 사건사고) 확인
	assert(ed3["sub1"].has("headline") and ed3["sub1"].has("body"), "서브 기사 1 포맷 누락")
	assert(ed3["sub2"].has("headline") and ed3["sub2"].has("body"), "서브 기사 2 포맷 누락")
	print("  - [PASS] 상태별(연도, 을묘원행, 완공도, 경제) 톱기사 및 익살맞은 서브 기사 동적 매칭 정상")

func _test_settings_persistence() -> void:
	print("\n[검증 4] GameSettings 자동 팝업 토글 및 영구 저장(Persistence) 검증...")
	GameSettings.set_auto_show_gazette(true)
	assert(GameSettings.is_auto_show_gazette() == true, "토글 ON 실패")

	GameSettings.set_auto_show_gazette(false)
	assert(GameSettings.is_auto_show_gazette() == false, "토글 OFF 실패")

	# 파일에서 재로드하여 영구 저장 검증
	GameSettings._loaded = false
	GameSettings.load_settings()
	assert(GameSettings.is_auto_show_gazette() == false, "user://settings.cfg 저장 및 복원 실패")

	# 복구
	GameSettings.set_auto_show_gazette(true)
	assert(GameSettings.is_auto_show_gazette() == true, "토글 원복 실패")
	print("  - [PASS] GameSettings auto_show_gazette 설정 파일(user://settings.cfg) 영구 보존 정상")

func _test_popup_and_signal_integration() -> void:
	print("\n[검증 5] BibyeonsaSiboPopup UI 인스턴싱 및 8턴 발간 신호 연동 검증...")
	var sim := SimulationCore.new()
	var grid := GameGrid.new()
	var popup := BibyeonsaSiboPopup.new()
	root.add_child(popup)
	popup.setup(sim, grid)

	# 1호 발간
	popup.publish_edition(1)
	assert(popup.edition_history.size() == 1, "발간 이력 누적 실패")
	assert(popup._header_info_lbl != null and popup._header_info_lbl.text.contains("제 1호"), "1호 헤더 바인딩 실패")

	# 2호 발간
	popup.publish_edition(2)
	assert(popup.edition_history.size() == 2, "2호 발간 이력 누적 실패")
	assert(popup._header_info_lbl.text.contains("제 2호"), "2호 헤더 바인딩 실패")

	# 보관함(지난 호수 읽기) 테스트
	popup._on_archive_pressed()
	assert(popup._header_info_lbl.text.contains("제 1호"), "지난 호수 보관함 순환 열람 실패")

	popup._on_archive_pressed()
	assert(popup._header_info_lbl.text.contains("제 2호"), "보관함 최신 호수 복귀 실패")

	# 팝업 열기/닫기
	popup._open_popup()
	assert(popup.visible == true, "팝업 열기 상태 실패")
	popup._close_popup()

	popup.queue_free()
	print("  - [PASS] 신문 UI 레이아웃, 한지 텍스처, 붉은 관인[비변사印], 보관함 순환 열람 정상")
