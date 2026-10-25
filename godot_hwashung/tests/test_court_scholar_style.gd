extends SceneTree

## 조정 인재 목록 이름 볼드체/코발트색(#1d4ed8) 스타일 검증 테스트

func _init() -> void:
	print("=== 조정 인재 목록 볼드체/코발트색 스타일 검증 시작 ===")
	ThemeManager.initialize_fonts()
	
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	
	var panels: PanelController = main_scene.panels
	assert(panels != null, "PanelController 인스턴스가 존재하지 않습니다.")
	
	var court: CourtSystem = main_scene.court
	assert(court != null, "CourtSystem 인스턴스가 존재하지 않습니다.")
	
	var sim: SimulationCore = main_scene.simulation_core
	assert(sim != null, "SimulationCore 인스턴스가 존재하지 않습니다.")
	
	# 후보 인재 임의 추가
	court.candidates.clear()
	court.candidates.append({
		"id": "gu",
		"turns": 1,
		"praise": "참된 인재이옵니다! 국방력 +15/달 (부작용: 군량 -10/달)\n  [단서] 호: - · 이력: 어영대장 · 훈련대장, 무관 실세 · 행적: 사도세자 죽음에 연루 의심, 역모로 처형(1786)",
		"accurate": true,
		"acc": 100
	})
	court.candidates.append({
		"id": "sim_hwanji",
		"turns": 2,
		"praise": "겉으론 번지르르하나 속을 들여다보니 경계해야 할 인물이옵니다.\n  [단서] 호: 만포(晩圃)",
		"accurate": true,
		"acc": 100
	})
	
	# 이미 등용된 인재 추가 (정약용)
	sim.retainers["jeong_yakyong"] = true
	
	# 모달 창 열기
	panels._open("규장각 및 조정 인사", panels._build_retainers)
	await process_frame
	
	var body: VBoxContainer = panels._body
	assert(body != null, "PanelController _body가 존재하지 않습니다.")
	
	var found_candidate_rtl := 0
	var found_retainer_rtl := 0
	
	for child in body.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is RichTextLabel:
					var rtl: RichTextLabel = sub
					assert(rtl.bbcode_enabled, "RichTextLabel의 bbcode_enabled가 false입니다.")
					assert(rtl.text.find("[b][color=#1d4ed8]") != -1, "코발트색 및 볼드 태그가 없습니다: " + rtl.text)
					assert(rtl.text.find("[/color][/b]") != -1, "닫는 태그가 없습니다: " + rtl.text)
					
					if rtl.text.find("어영대장 구선복") != -1 or rtl.text.find("만포 심환지") != -1:
						found_candidate_rtl += 1
						print("[검증 성공] 후보 인재 RTL: ", rtl.text.split("\n")[0])
					elif rtl.text.find("다산 정약용") != -1:
						found_retainer_rtl += 1
						print("[검증 성공] 조정 등용 인재 RTL: ", rtl.text.split("\n")[0])
	
	assert(found_candidate_rtl >= 2, "후보 인재 2명 모두 RichTextLabel로 렌더링되지 않았습니다. (발견: %d)" % found_candidate_rtl)
	assert(found_retainer_rtl >= 1, "등용 인재가 RichTextLabel로 렌더링되지 않았습니다. (발견: %d)" % found_retainer_rtl)
	
	print("=== 조정 인재 목록 스타일 검증 성공 완료 (ALL PASSED) ===")
	quit(0)
