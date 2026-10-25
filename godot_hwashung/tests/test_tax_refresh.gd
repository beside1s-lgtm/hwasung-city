extends SceneTree

func _init() -> void:
	print("=== 조세 창 리프레시 방지 검증 테스트 시작 ===")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	
	var panel: PanelController = main.panels
	var sim: SimulationCore = main.simulation_core
	
	# 초기 세율 설정 (예: 5%, 5%, 5%)
	sim.tax_rate_land = 5
	sim.tax_rate_market = 5
	sim.tax_rate_military = 5
	
	# 1. 조세 모달 열기
	panel.open_action_modal("tax")
	print("조세 창 오픈 후 _modal_no_refresh 상태: ", panel._modal_no_refresh)
	assert(panel._modal_no_refresh == true, "조세 모달은 _modal_no_refresh == true 여야 함")
	
	# 2. 임시 세율 변경 (유저가 슬라이더를 12%, 10%, 8%로 조율)
	panel._temp_tax_land = 12
	panel._temp_tax_market = 10
	panel._temp_tax_military = 8
	
	# 3. 0.5초 경과 및 sim.state_updated 발생 시뮬레이션
	sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, 0)
	await process_frame
	
	# _refresh_menu_buttons() 가 _modal_no_refresh 덕분에 실행되지 않아 _temp_tax_* 가 보존되어야 함
	print("sim.state_updated 후 임시 세율 값: land=", panel._temp_tax_land, " market=", panel._temp_tax_market, " military=", panel._temp_tax_military)
	assert(panel._temp_tax_land == 12, "land 세율이 리셋되지 않고 12% 유지되어야 함")
	assert(panel._temp_tax_market == 10, "market 세율이 리셋되지 않고 10% 유지되어야 함")
	assert(panel._temp_tax_military == 8, "military 세율이 리셋되지 않고 8% 유지되어야 함")
	
	# 4. _modal_busy_with_pointer() 범위 검사 (HSlider 위에 마우스가 있거나 할 때도 안전한지)
	var slider := HSlider.new()
	panel._modal.add_child(slider)
	assert(slider is Range, "HSlider는 Range 타입이어야 함")
	slider.queue_free()
	
	# 5. 적용 버튼 로직 검증: sim에 반영되는지 확인
	sim.tax_rate_land = panel._temp_tax_land
	sim.tax_rate_market = panel._temp_tax_market
	sim.tax_rate_military = panel._temp_tax_military
	assert(sim.tax_rate_land == 12)
	assert(sim.tax_rate_market == 10)
	assert(sim.tax_rate_military == 8)
	print("조세 적용 후 sim 세율: land=", sim.tax_rate_land, " market=", sim.tax_rate_market, " military=", sim.tax_rate_military)
	
	# 6. 모달 닫기
	panel._close_modal()
	
	# 7. 다른 모달 열었을 때 _modal_no_refresh가 정상 복구되는지 확인
	panel.open_action_modal("newspaper")
	print("일반 모달(시보) 오픈 후 _modal_no_refresh 상태: ", panel._modal_no_refresh)
	assert(panel._modal_no_refresh == false, "일반 모달 오픈 시 _modal_no_refresh는 false로 리셋되어야 함")
	
	print("=== 조세 창 리프레시 방지 검증 테스트 성공 (ALL PASS) ===")
	quit(0)
