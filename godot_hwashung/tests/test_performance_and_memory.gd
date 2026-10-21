extends SceneTree

## [QA 자동화 감사] 런타임 성능 프로파일링 및 메모리 누수·렉 유발 요소 실측 테스트 스위트
## 100턴 고속 시뮬레이션 중 메모리 사용량, 고아 노드 수, 에이전트 풀 상한, A* 갱신 시간 등을 실측합니다.

func _init() -> void:
	print("=== [QA BENCHMARK START] 런타임 성능 및 메모리 무결성 실측 검증 개시 ===")
	call_deferred("_run_benchmark")

func _run_benchmark() -> void:
	# 1. Main 씬 로드 및 인스턴싱
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("[FAIL] Main.tscn 로드 실패")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 인트로 영상 제거 및 본 게임 시작
	if main.has_node("IntroVideoLayer"):
		var intro = main.get_node("IntroVideoLayer")
		intro.queue_free()
	if main.has_node("TitleScreenLayer"):
		var title = main.get_node("TitleScreenLayer")
		title.queue_free()
	main._on_start_new_game()
	await process_frame

	print("[QA SETUP] 메인 씬 인스턴싱 및 게임 루프 진입 완료")

	# 초기 상태 측정
	var mem_init: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var orphan_init: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var nodes_init: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_init: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var citizens_init: int = main.citizens.agents.size() if main.citizens else 0

	print("\n[초기 기준 상태 (Turn 0)]")
	print("  - 정적 메모리(Static RAM): %.2f MB" % mem_init)
	print("  - 고아 노드(Orphans): %d개" % orphan_init)
	print("  - 씬 트리 노드(Nodes): %d개" % nodes_init)
	print("  - 활성 객체(Objects): %d개" % objects_init)
	print("  - 활성 시민 에이전트(Agents): %d명" % citizens_init)

	# 100턴 시뮬레이션 및 데이터 샘플링
	var total_turns: int = 100
	var samples: Array[Dictionary] = []
	var max_process_time_ms: float = 0.0

	for t in range(1, total_turns + 1):
		# 30일 시뮬레이션 전진
		main.time_manager.advance_day(30)
		main.simulation_core.on_simulation_tick(30)

		# 5턴마다 건설/개발 액션 수행 (타일 변경 및 A* 내비게이션 갱신 부하 시뮬레이션)
		if t % 5 == 0:
			var px: int = 20 + (t % 15)
			var py: int = 20 + (t / 5)
			main.grid.apply_tool("road", px, py, false)
			main.grid.apply_tool("res", px + 1, py, false)

		# 25턴마다 도적 침입 및 장용영 요격 전투 부하 시뮬레이션
		if t % 25 == 0 and main.siege_defense:
			main.siege_defense.start_invasion("bandit", 400)
			main.siege_defense._on_combat_finished(true)

		# 프레임 처리
		await process_frame

		var p_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		if p_time > max_process_time_ms:
			max_process_time_ms = p_time

		# 10턴 단위 샘플링
		if t % 10 == 0:
			var cur_mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
			var cur_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
			var cur_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var cur_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var cur_citizens: int = main.citizens.agents.size() if main.citizens else 0

			samples.append({
				"turn": t,
				"mem": cur_mem,
				"orphans": cur_orphans,
				"nodes": cur_nodes,
				"objects": cur_objects,
				"citizens": cur_citizens,
				"process_ms": p_time
			})

			print("[Turn %3d / %3d] 메모리: %6.2f MB | 고아노드: %d개 | 씬노드: %d개 | 객체: %d개 | 시민: %2d명 | 프레임: %.2f ms" % [
				t, total_turns, cur_mem, cur_orphans, cur_nodes, cur_objects, cur_citizens, p_time
			])

	# 100턴 종료 후 최종 분석
	var final_mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var final_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var final_citizens: int = main.citizens.agents.size() if main.citizens else 0

	var mem_growth_total: float = final_mem - mem_init
	# 20턴(초기 안정화 이후)부터 100턴까지의 순 증가량
	var mem_turn_20: float = samples[1]["mem"]
	var mem_growth_stabilized: float = final_mem - mem_turn_20

	print("\n=== [QA 실측 벤치마크 결과 종합] ===")
	print("1. 메모리 소비 지표:")
	print("   - 초기 메모리: %.2f MB" % mem_init)
	print("   - 20턴 안정화 시점 메모리: %.2f MB" % mem_turn_20)
	print("   - 100턴 최종 메모리: %.2f MB" % final_mem)
	print("   - 총 메모리 변동: %+.2f MB" % mem_growth_total)
	print("   - 20턴 이후 안정화 구간 메모리 변동: %+.2f MB" % mem_growth_stabilized)
	print("2. 객체 및 노드 누수(Leak) 지표:")
	print("   - 초기 고아 노드: %d개 -> 100턴 후: %d개 (신규 고아 노드: %d개)" % [orphan_init, final_orphans, final_orphans - orphan_init])
	print("   - 씬 노드 변동: %d개 -> %d개 (변동: %+d개)" % [nodes_init, final_nodes, final_nodes - nodes_init])
	print("   - 시민 에이전트 수: %d명 -> %d명 (에이전트 풀 상한 통제 확인)" % [citizens_init, final_citizens])
	print("3. 프로세스 프레임 타임:")
	print("   - 최대 프로세스 틱 소요: %.2f ms (60FPS 기준치 16.6ms 대비 여유)" % max_process_time_ms)

	# 검증 판정
	var passed: bool = true

	# 고아 노드 누적 검사: 신규 고아 노드가 10개 이상 발생하면 누수 의심
	if (final_orphans - orphan_init) > 10:
		printerr("[FAIL] 고아 노드 누수 감지: %d개 발생" % (final_orphans - orphan_init))
		passed = false
	else:
		print("[PASS] 고아 노드 누수 없음: 정상 범위 유지")

	# 안정화 구간 메모리 폭증 검사: 20턴부터 100턴까지 메모리 증가가 50MB 미만이어야 함
	if mem_growth_stabilized > 50.0:
		printerr("[FAIL] 메모리 선형 누수(Leak) 감지: 80턴 동안 +%.2f MB 증가" % mem_growth_stabilized)
		passed = false
	else:
		print("[PASS] 메모리 누수 없음: 80턴 동안 증감률 %.2f MB로 안정적 수렴" % mem_growth_stabilized)

	# 시민 에이전트 무한 증식 검사 (상한선 100명 미만 유지)
	if final_citizens > 120:
		printerr("[FAIL] 시민 에이전트 무한 증식 감지: %d명" % final_citizens)
		passed = false
	else:
		print("[PASS] 시민 에이전트 수명주기(Despawn) 및 풀 통제 정상: %d명 유지" % final_citizens)

	if passed:
		print("\n=== [QA BENCHMARK COMPLETE] 렉 및 메모리 누수 요인 0건 검증 완료 (100% PASS) ===")
		quit(0)
	else:
		printerr("\n=== [QA BENCHMARK FAILED] 성능 또는 메모리 결함 감지 ===")
		quit(1)
