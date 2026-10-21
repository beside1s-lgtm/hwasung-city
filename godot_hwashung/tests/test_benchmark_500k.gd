extends SceneTree

const PerformanceProfiler = preload("res://scripts/PerformanceProfiler.gd")

## [인구 50만+ 대규모 시뮬레이션 및 3단계 LOD 벤치마크 검증 테스트 러너]
## 1. 50만+ 인구 및 건물 342채 배치 상태 구축
## 2. 카메라 줌 조작: LOD 0 (1.8x) -> LOD 1 (1.0x) -> LOD 2 (0.5x)
## 3. 계절 전환 40칸/프레임 타임 슬라이스 베이킹 소요 시간 실측
## 4. 백그라운드 논리(방호력, 순라, 세수 등) 무결성 및 콘솔 리포트 출력

func _init() -> void:
	print("=== [QA BENCHMARK RUNNER] 50만+ 대규모 시뮬레이션 & 3단계 LOD 검증 개시 ===")
	call_deferred("_run")

func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("[FAIL] Main.tscn 로드 실패")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 인트로 및 타이틀 건너뛰기
	if main.has_node("IntroVideoLayer"):
		var intro = main.get_node("IntroVideoLayer")
		intro.queue_free()
	if main.has_node("TitleScreenLayer"):
		var title = main.get_node("TitleScreenLayer")
		title.queue_free()
	main._on_start_new_game()
	await process_frame
	await process_frame

	print("[QA BENCHMARK] 게임 루프 초기화 완료. 프로파일러 가동...")

	var profiler := PerformanceProfiler.new()
	profiler.setup(main)
	main.add_child(profiler)

	var report: Dictionary = profiler.run_benchmark()

	# 검증 Assertions
	var all_pass: bool = true
	if report.get("population", 0) < 500000:
		printerr("[FAIL] 인구 50만 미달: ", report.get("population", 0))
		all_pass = false
	if report.get("buildings", 0) < 300:
		printerr("[FAIL] 건물 300채 미달: ", report.get("buildings", 0))
		all_pass = false
	if report.get("lod2_rendering_npcs", -1) != 0:
		printerr("[FAIL] LOD 2에서 개별 NPC가 컬링되지 않음: ", report.get("lod2_rendering_npcs"))
		all_pass = false
	if report.get("lod2_particles", -1) != 0:
		printerr("[FAIL] LOD 2에서 파티클이 정지되지 않음: ", report.get("lod2_particles"))
		all_pass = false

	if all_pass:
		print("=== [QA BENCHMARK SUCCESS] 모든 벤치마크 및 무결성 검증 통과 (PASS) ===")
		quit(0)
	else:
		printerr("=== [QA BENCHMARK FAILED] 검증 기준 미달 ===")
		quit(1)
