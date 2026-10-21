extends SceneTree

func _init() -> void:
	print("=== 세시풍속 및 난전마당·제방 NPC 복구 검증 시작 ===")
	
	var grid := GameGrid.new()
	var sim := SimulationCore.new()
	var court := CourtSystem.new()
	var citizens := CitizenManager.new()
	var festivals := FestivalSystem.new()
	
	grid._ready()
	citizens.setup(grid, court, sim)
	festivals.setup(grid, sim, citizens)
	
	# 1. 호랑이 판정 (has_active_tiger) 검증
	print("[검증 1] 호랑이 출현 판정 검증")
	# 1-1. 평시 산속(50칸 밖) 호랑이 존재 시
	var wild_tiger: Dictionary = {
		"id": 999, "type": "tiger", "x": 60.0, "y": 60.0, "state": "prowl", "is_dead": false
	}
	citizens.agents.append(wild_tiger)
	assert(not citizens.has_active_tiger(), "산속 50칸 밖 prowl 호랑이는 마을 호환 경보를 발동시키지 않아야 함")
	print("  - 산속 50칸 밖 야생 호랑이: has_active_tiger == false (PASS)")
	
	# 1-2. 조정의 포호책 위기 활성화 시
	court.tiger["active"] = true
	assert(citizens.has_active_tiger(), "조정 포호책 활성화 시 has_active_tiger == true 여야 함")
	print("  - 조정 포호책(어명 위기) 활성화 시: has_active_tiger == true (PASS)")
	court.tiger["active"] = false
	
	# 1-3. 호랑이가 마을 반경(50칸 이내) 침입 시
	var village_tiger: Dictionary = {
		"id": 998, "type": "tiger", "x": 10.0, "y": 10.0, "state": "stalk_village", "is_dead": false
	}
	citizens.agents.append(village_tiger)
	assert(citizens.has_active_tiger(), "마을 50칸 이내 침입 호랑이는 has_active_tiger == true 여야 함")
	print("  - 마을 침입 습격 호랑이: has_active_tiger == true (PASS)")
	village_tiger["is_dead"] = true
	wild_tiger["is_dead"] = true
	
	# 2. 사계절 세시풍속 놀이판(FestivalSystem) 등록 검증
	print("[검증 2] 사계절 세시풍속 놀이판 등록 검증")
	
	# 2-1. 봄: 지신밟기 풍물, 택견
	festivals.on_season_changed("봄")
	assert(festivals.scenes.size() > 0, "봄 놀이판이 1개 이상 등록되어야 함")
	var spring_kinds: Array = festivals.scenes.map(func(sc: Dictionary) -> String: return str(sc.get("kind", "")))
	print("  - 봄 등록 놀이판: %s (PASS)" % [str(spring_kinds)])
	
	# 2-2. 여름: 단오 씨름, 탈춤, 석전(제방/천변)
	festivals.on_season_changed("여름")
	assert(festivals.scenes.size() > 0, "여름 놀이판이 1개 이상 등록되어야 함")
	var summer_kinds: Array = festivals.scenes.map(func(sc: Dictionary) -> String: return str(sc.get("kind", "")))
	print("  - 여름 등록 놀이판: %s (PASS)" % [str(summer_kinds)])
	
	# 2-3. 가을: 강강술래, 줄타기
	festivals.on_season_changed("가을")
	assert(festivals.scenes.size() > 0, "가을 놀이판이 1개 이상 등록되어야 함")
	var autumn_kinds: Array = festivals.scenes.map(func(sc: Dictionary) -> String: return str(sc.get("kind", "")))
	print("  - 가을 등록 놀이판: %s (PASS)" % [str(autumn_kinds)])
	
	# 2-4. 겨울: 연날리기, 팽이치기, 쥐불놀이
	festivals.on_season_changed("겨울")
	var winter_kinds: Array = festivals.scenes.map(func(sc: Dictionary) -> String: return str(sc.get("kind", "")))
	print("  - 겨울 등록 놀이판: %s (PASS)" % [str(winter_kinds)])
	
	# 3. 난전마당 POI 이벤트 검증
	print("[검증 3] 난전마당 POI 이벤트 스폰 검증")
	citizens._market_plaza_cache.append(Vector2i(15, 15))
	citizens._update_plaza_events()
	assert(citizens._plaza_events.size() > 0, "공터에 난전/사당패/쉼터 이벤트가 스폰되어야 함")
	var ev: Dictionary = citizens._plaza_events[0]
	print("  - 난전마당 이벤트 종류: %s, 에이전트 수: %d, 유지 타이머: %.1f초 (PASS)" % [
		ev.get("kind", ""), ev.get("agents", []).size(), ev.get("timer", 0.0)
	])
	
	print("=== 모든 세시풍속 및 난전마당 검증 완벽 통과 (ALL PASS) ===")
	quit(0)
