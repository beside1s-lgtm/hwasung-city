extends RefCounted
class_name NewspaperSystem

# PORT-TRACE: src/core/GameState.ts generateNewspaperArticle, src/domain/HistoryEvents.ts (dilemma pool)
# 이식 로그: docs/godot_port_log.md 항목 P5

const SEASONS := ["봄", "여름", "가을", "겨울"]

static func generate(sim: SimulationCore, grid: GameGrid, historic_event: String) -> Dictionary:
	var y := sim.current_year
	var season: String = SEASONS[sim.season_now()]
	var date_str := "%s %s호" % [TimeManager.era_label(y), season] # 1800년 엔딩 뒤는 순조 이후 연호
	var season_index := sim.season_now()
	if historic_event == "wonhaeng1789":
		return _a(date_str, "정조 대왕, 현륭원 원행 단행! 한강에 웅장한 주교(舟橋) 개통",
			"정약용 설계 배다리로 백성 피해 없이 한강 도하. 수원 신도시 일대 환호",
			"과인의 부친 사도세자의 묘소를 수원 화산으로 영구히 모시는 원행 행렬이 무사히 한강을 건넜다. 정약용의 주교지모가 천하를 놀라게 하고 있다.",
			"[비변사 논평] 화성 신도시가 왕실과 국가의 정신적 상징으로 우뚝 솟아오르고 있다.")
	if historic_event == "eulmyo1795":
		return _a(date_str, "을묘년 혜경궁 홍씨 회갑연! 화성행궁 봉수당에서 천하 대잔치",
			"어머니를 위한 8일간의 화성 행차. 장용영 정예병 사열로 노론 벽파 간담 서늘",
			"화성행궁 봉수당에서 모친 혜경궁 홍씨를 위한 회갑연이 성대히 거행되었다. 팔달산 서장대에 오른 정조 대왕의 지휘 아래 장용영이 위용을 떨쳤다.",
			"[한양 정계 반응] 장용영의 포화 소리에 붕당 세력들이 숨을 죽이고 있다.")
	if grid.fortress_progress >= 100:
		return _a(date_str, "천하제일 철옹성 수원화성 완공! 거중기와 녹로로 2년 9개월의 기적",
			"품삯을 지급하는 관급 공사 제도로 부역 고통 해소. 세계적 성곽 탄생",
			"화성성역의 대역사가 대단원의 막을 내렸다. 정약용의 거중기와 채제공의 헌신으로 공사비와 기간을 절반으로 단축시켰다.",
			"[사관의 평] 임금의 애민정신과 실학 과학기술이 빚어낸 조선 역사상 가장 찬란한 금자탑이다.")
	if season_index == 2 and grid.count_buildings("agr") >= 2:
		return _a(date_str, "대유둔전 황금 들판 추수 대풍! 성문 거쳐 군량미 대거 입고",
			"수리 관개와 사통팔달 성문 도로망 연결로 운송 효율 극대화. 국고 풍족",
			"성 밖 외곽 대유평 둔전에서 수확한 벼가 수레와 마차에 실려 장안문과 팔달문 홍예를 거쳐 성내 저장고로 쉼 없이 들어오고 있다.",
			"[호조 판서 품의] 성문과 도로망이 개통되어 낟알 하나 유실 없이 군량으로 온전히 환수되었습니다.")
	if grid.reservoir_count >= 1 and season_index == 0:
		return _a(date_str, "만석거(萬石渠) 축조 성공! 고지대 저수지로 둔전 관개 완비",
			"정조 대왕의 혜안, 황무지가 곡창지대로 변모. 가뭄 걱정 해소",
			"수원 북방 고지대에 축조된 인공 저수지 만석거가 완공되어 수문을 열었다. 관개 용수가 대유둔전으로 흘러들고 있다.",
			"[비변사 평가] 치수와 수리를 겸비한 농업 인프라로 국가 재정의 보루가 마련되었다.")
	if grid.flood_defense >= 50 and season_index == 1:
		return _a(date_str, "수원천 석축 제방 준공! 청계천 준천에 버금가는 대역사 완성",
			"여름철 집중호우에도 침수 피해 없어. 유수부 치수 행정 극찬",
			"수원천을 따라 견고한 화강암 석축 제방이 들어서면서 매년 반복되던 여름철 범람이 끊어졌다.",
			"[백성들의 노래] 물난리 걱정 없이 안심하고 잠을 이루니 정조 대왕의 성덕이 하해와 같습니다.")
	if sim.demand_com > 50:
		return _a(date_str, "삼남대로 저잣거리 번영! 팔도 보부상들 수원으로 대거 집결",
			"신해통공의 온기 확산. 난전 금지령 폐지로 상인 모두 활짝",
			"수원 팔달문 밖 삼남대로에 전국 팔도의 물산이 넘쳐나고 있다. 상업 장려책과 세제 감면으로 대규모 교역 중심지로 급부상 중이다.",
			"[시전 상인회] 조세를 낮추고 도로를 닦아주니 장사할 맛이 납니다.")
	if sim.rice < 300:
		return _a(date_str, "수원천 일대 가뭄 우려. 비변사 군량미 비축 경보 발령",
			"식량 재고 급감에 백성들 동요. 관개 정비와 둔전 확충 시급",
			"계절적 가뭄으로 수원천 수량이 줄어 둔전의 벼 수확에 비상이 걸렸다. 대외 곡물 교역과 고구마 보급이 필요하다.",
			"[민심 동향] 배고픈 백성에겐 성벽보다 한 사발의 밥이 급선무입니다.")
	return _a(date_str, "화성성역 순항! 신도시 인구 %d명 돌파하며 활기" % sim.population,
		"충성도 %d%% 유지. 성벽 완공도 %d%% 달성" % [sim.loyalty, grid.fortress_progress],
		"정조 대왕의 개혁 의지가 서린 수원화성 신도시가 하루가 다르게 웅장한 면모를 갖춰가고 있다.",
		"[비변사 감찰] 정착률이 높고 치안이 안정되어 있으니 방어벽 축성에 만전을 기해야 할 것이다.")

static func _a(d: String, h: String, s: String, b: String, e: String) -> Dictionary:
	return {"dateStr": d, "headline": h, "subhead": s, "body": b, "editorial": e}

## 3턴마다 등장하는 암행어사 딜레마. effect는 sim을 변경하고 결과 문자열을 반환하는 Callable.
static func dilemma_pool(sim: SimulationCore) -> Array:
	var pool: Array = [
		{
			"id": "sinhae_tonggong",
			"title": "암행어사 서면 보고: 난전 단속",
			"desc": "수원 저잣거리에 난전(자유 상인)이 급증했습니다. 난전을 허용하시겠습니까?",
			"choices": [
				{"text": "신해통공 발령 (난전 전면 허용)", "effect": func():
					if sim.loyalty >= 70:
						sim.gold += 350
						return "상업이 융성하며 막대한 세수가 들어왔습니다. (금 +350)"
					sim.loyalty -= 15
					return "치안 부재로 난전 폭력배가 상가를 불태웠습니다. (민심 -15)"},
				{"text": "시전 상인의 독점권 인정", "effect": func():
					sim.gold += 120
					sim.loyalty -= 5
					return "상인들의 헌금을 받았으나 물가가 올랐습니다."},
			],
		},
		{
			"id": "relief_food",
			"title": "암행어사 긴급 보고: 흉년과 환곡",
			"desc": "흉년으로 굶주림이 극에 달했습니다. 구휼미를 풀겠습니까?",
			"choices": [
				{"text": "사창을 열어 무상 방출 (쌀 %d석)" % DifficultyManager.get_relief_food_cost(sim.population), "effect": func():
					var req_rice: int = DifficultyManager.get_relief_food_cost(sim.population)
					if sim.rice >= req_rice:
						sim.rice -= req_rice
						sim.loyalty = min(100, sim.loyalty + 25)
						return "백성들이 결속합니다. (민심 +25)"
					sim.loyalty -= 20
					return "창고에 쌀이 부족하여 소요가 일어났습니다."},
				{"text": "성역 예비미이므로 보존", "effect": func():
					sim.loyalty -= 18
					sim.population = max(20, sim.population - 20)
					return "유민들이 떠나 인구가 줄었습니다."},
			],
		},
	]

	# 사병 음모(Conspiracy Loop): 쿨타임 및 결정 대기 플래그 검사 (실시간 5초 팝업 스팸 원천 방어)
	var can_conspire: bool = false
	if sim != null:
		can_conspire = (sim.conspiracy_cooldown_turns <= 0 and not sim.is_conspiracy_decision_pending)

	if can_conspire:
		var cand: Dictionary = sim.select_available_conspirator()
		var c_id: String = str(cand.get("id", "gu_seon_bok"))
		var c_name: String = str(cand.get("name", "구선복"))
		var c_title: String = str(cand.get("title", "군부 실세"))

		pool.append({
			"id": "conspiracy_dilemma",
			"title": "군관 급보: %s의 사병 훈련" % c_name,
			"desc": "%s %s이(가) 은밀히 사병을 모아 세력을 규합한다는 밀고가 들어왔습니다. 즉시 조치하시겠습니까?" % [c_title, c_name],
			"choices": [
				{
					"text": "백동수의 장용영으로 선제 압수수색",
					"effect": _on_conspiracy_crackdown.bind(sim, c_id, c_name, c_title)
				},
				{
					"text": "묵인하고 관직 하사 (세력 관망)",
					"effect": _on_conspiracy_ignore.bind(sim, c_id, c_name, c_title)
				},
			],
		})

	return pool

static func _on_conspiracy_crackdown(p_sim: Variant, p_id: String, p_name: String, p_title: String) -> String:
	if p_sim != null:
		p_sim.active_conspirator_id = p_id
		p_sim.active_conspirator_name = p_name
		p_sim.active_conspirator_title = p_title
		if p_sim.has_method("on_conspiracy_crackdown_selected"):
			return str(p_sim.on_conspiracy_crackdown_selected())
	return ""

static func _on_conspiracy_ignore(p_sim: Variant, p_id: String, p_name: String, p_title: String) -> String:
	if p_sim != null:
		p_sim.active_conspirator_id = p_id
		p_sim.active_conspirator_name = p_name
		p_sim.active_conspirator_title = p_title
		if p_sim.has_method("on_conspiracy_ignore_selected"):
			return str(p_sim.on_conspiracy_ignore_selected())
	return ""
