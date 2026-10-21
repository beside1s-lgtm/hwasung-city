extends RefCounted
class_name ScholarManager

## [조선 후기 탕평 사대부 인재풀(12인) 및 현장 무정파 기술 장인 계층 격리 분리 관리자]
## - Track A: 무정파 현장 기술 장인 (김바우, 이성길, 무쇠 등) -> Faction.NONE, 탕평도 분모 100% 제외
## - Track B: 조정 사대부 탕평 인재풀 (12인) -> 노론, 소론, 남인, 북학파 탕평도 및 학문력 전담

enum Faction {
	NONE = 0,
	NORON = 1,
	SORON = 2,
	NAMIN = 3,
	BUKHAK = 4
}

enum RoleType {
	FIELD_ARTISAN = 0,
	COURT_SCHOLAR = 1
}

## 전체 인재 및 기술 장인 마스터 데이터
const TALENTS_DATA: Dictionary = {
	# ==================== [Track A] 무정파 현장 기술 장인 (탕평도 100% 제외) ====================
	"kim_bau": {
		"id": "bau",
		"key": "kim_bau",
		"name": "석수 김바우",
		"role": "수석 석공 명장",
		"role_type": RoleType.FIELD_ARTISAN,
		"faction": Faction.NONE,
		"cost": 130,
		"salary": 150,
		"academic": 0,
		"desc": "수석 석공 명장 — 매달 성곽 완공도 +2, 대역사 투입비 -20%",
		"is_western": false
	},
	"lee_seonggil": {
		"id": "lee_seonggil",
		"key": "lee_seonggil",
		"name": "도편수 이성길",
		"role": "수석 목수 도편수",
		"role_type": RoleType.FIELD_ARTISAN,
		"faction": Faction.NONE,
		"cost": 150,
		"salary": 180,
		"academic": 0,
		"desc": "수석 목수 도편수 — 화성행궁 및 목조 누각 건립 공기 단축",
		"is_western": false
	},
	"musoe": {
		"id": "musoe",
		"key": "musoe",
		"name": "가죽공 무쇠",
		"role": "군수 가죽공 장인",
		"role_type": RoleType.FIELD_ARTISAN,
		"faction": Faction.NONE,
		"cost": 100,
		"salary": 120,
		"academic": 0,
		"desc": "군수 피혁 명장 — 갑옷 및 군장 완비로 방호력 +50",
		"is_western": false
	},
	"baek_dongsu": {
		"id": "baek",
		"key": "baek_dongsu",
		"name": "야뇌 백동수",
		"role": "장용영 무예 총관",
		"role_type": RoleType.FIELD_ARTISAN,
		"faction": Faction.NONE,
		"cost": 200,
		"salary": 280,
		"academic": 0,
		"desc": "장용영 무예 총관 — 국방력 +10/달, 도적 침략 차단, 성 방호력 +300",
		"is_western": false
	},

	# ==================== [Track B] 조정 사대부 탕평 인재풀 (12인) ====================
	# 1. 채제공 (남인 영수)
	"chae_jegong": {
		"id": "chae",
		"key": "chae_jegong",
		"name": "번암 채제공",
		"role": "남인 영수 / 영의정",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NAMIN,
		"cost": 150,
		"salary": 300,
		"academic": 9,
		"desc": "화성 축성 공기 단축, 대역사 공사비 25% 절감, 남인 결집",
		"is_western": false
	},
	# 2. 정약용 (남인 실학)
	"jeong_yakyong": {
		"id": "jeong",
		"key": "jeong_yakyong",
		"name": "다산 정약용",
		"role": "남인 실학 / 성역 실무",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NAMIN,
		"cost": 200,
		"salary": 500,
		"academic": 10,
		"desc": "거중기·녹로 기술 가속, 방호력 강화 / 서학 의혹(천주교당 위험)",
		"is_western": true
	},
	# 3. 김홍도 (중인 / 화원 - 학문력 +5 기여, 탕평도는 중립/NONE)
	"kim_hongdo": {
		"id": "kim",
		"key": "kim_hongdo",
		"name": "단원 김홍도",
		"role": "중인 / 화원 / 의궤도",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NONE,
		"cost": 120,
		"salary": 200,
		"academic": 5,
		"desc": "도시 문화도·민심 상승(+2/달), 을묘의궤 완성 / 노임 및 화구 지출",
		"is_western": false
	},
	# 4. 심환지 (노론 벽파 영수)
	"sim_hwanji": {
		"id": "sim_hwanji",
		"key": "sim_hwanji",
		"name": "만포 심환지",
		"role": "노론 벽파 영수 / 이조판서",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NORON,
		"cost": 50,
		"salary": 50,
		"academic": -3,
		"desc": "노론 사대부 반발 억제, 군포세 저항 감소 / 신기술 도입 지연, 학문력 감산",
		"is_western": false
	},
	# 5. 홍인한 (노론 척신)
	"hong_inhan": {
		"id": "hong",
		"key": "hong_inhan",
		"name": "좌의정 홍인한",
		"role": "노론 척신 / 우의정",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NORON,
		"cost": 0,
		"salary": 100,
		"academic": -5,
		"desc": "일시불 국고 대량 확보(+3,000냥) / 국고 누수(-5%), 왕권 지속 감소",
		"is_western": false
	},
	# 6. 김조순 (노론 시파)
	"kim_josun": {
		"id": "kim_josun",
		"key": "kim_josun",
		"name": "풍고 김조순",
		"role": "노론 시파 / 규장각 제학",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NORON,
		"cost": 180,
		"salary": 220,
		"academic": 6,
		"desc": "조정 정국 안정, 세자 교육 효율 보조 / 정조 사후 세도정치 잠재력",
		"is_western": false
	},
	# 7. 박제가 (북학파 서얼)
	"park_jega": {
		"id": "park",
		"key": "park_jega",
		"name": "초정 박제가",
		"role": "북학파 (서얼) / 검서관",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 180,
		"salary": 320,
		"academic": 8,
		"desc": "저잣거리 상업 교역량 20% 증가, 청나라 기술 / 사대부 반발",
		"is_western": false
	},
	# 8. 이덕무 (북학파 서얼)
	"lee_deokmu": {
		"id": "lee_deokmu",
		"key": "lee_deokmu",
		"name": "청장관 이덕무",
		"role": "북학파 (서얼) / 검서관",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 200,
		"salary": 300,
		"academic": 8,
		"desc": "세자 제왕학 서연 진척도 가산, 서적 편찬 가속 / 녹봉 지속 지출",
		"is_western": false
	},
	# 9. 서유구 (소론 농학자)
	"seo_yugu": {
		"id": "seo",
		"key": "seo_yugu",
		"name": "풍석 서유구",
		"role": "소론 / 농학자",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.SORON,
		"cost": 160,
		"salary": 180,
		"academic": 7,
		"desc": "대유둔전 식량 생산 25% 증대, 수리 시설 개선 / 상업 정책과 마찰",
		"is_western": false
	},
	# 10. 정범조 (소론 원로)
	"jeong_beomjo": {
		"id": "jeong_beomjo",
		"key": "jeong_beomjo",
		"name": "해좌 정범조",
		"role": "소론 원로 / 대제학",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.SORON,
		"cost": 150,
		"salary": 200,
		"academic": 6,
		"desc": "화성 향교 유생 결집, 왕권 정당성 부여 / 보수적 원칙 강조",
		"is_western": false
	},
	# 11. 이가환 (남인 학자)
	"lee_gahwan": {
		"id": "lee_gahwan",
		"key": "lee_gahwan",
		"name": "정헌 이가환",
		"role": "남인 학자 / 공조판서",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NAMIN,
		"cost": 220,
		"salary": 280,
		"academic": 9,
		"desc": "수학적 축성 정밀도 상승, 천문 역법 교정 / 서학 연루 상소 빈발",
		"is_western": true
	},
	# 12. 유득공 (북학파 서얼)
	"yu_deukgong": {
		"id": "yu_deukgong",
		"key": "yu_deukgong",
		"name": "영재 유득공",
		"role": "북학파 (서얼) / 검서관",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 140,
		"salary": 200,
		"academic": 7,
		"desc": "북방 역사 정립으로 백성 자긍심 고취, 민심 상승 / 체제 유지비 증가",
		"is_western": false
	},

	# ==================== 기존 추가 호환용 인물 ====================
	"park_jiwon": {
		"id": "park_jiwon",
		"key": "park_jiwon",
		"name": "연암 박지원",
		"role": "북학파 / 열하일기",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 250,
		"salary": 450,
		"academic": 10,
		"desc": "저잣거리 상업·유통 세수 +50%, 《열하일기》",
		"is_western": false
	},
	"hong_daeyong": {
		"id": "hong_daeyong",
		"key": "hong_daeyong",
		"name": "담헌 홍대용",
		"role": "북학파 / 과학·천문",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 220,
		"salary": 350,
		"academic": 10,
		"desc": "학문력 +10, 천문·과학 연구 비용 -20%",
		"is_western": true
	},
	"kim_jeonghui": {
		"id": "kim_jeonghui",
		"key": "kim_jeonghui",
		"name": "추사 김정희",
		"role": "북학파 / 금석학·서예",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.BUKHAK,
		"cost": 150,
		"salary": 250,
		"academic": 4,
		"desc": "비문 고증·예술 — 민심 +1/달",
		"is_western": false
	},
	"jo_simtae": {
		"id": "jo",
		"key": "jo_simtae",
		"name": "수원부사 조심태",
		"role": "소론 / 치수·토목 감동",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.SORON,
		"cost": 140,
		"salary": 200,
		"academic": 1,
		"desc": "치수·토목 감동 — 방재율 +5/달",
		"is_western": false
	},
	"yu_hanji": {
		"id": "yu",
		"key": "yu_hanji",
		"name": "명필 유한지",
		"role": "중인 / 예서 명필",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NONE,
		"cost": 110,
		"salary": 150,
		"academic": 2,
		"desc": "예서 명필 — 민심 +1, 왕권 +1/달",
		"is_western": false
	},
	"gu_seonbok": {
		"id": "gu",
		"key": "gu_seonbok",
		"name": "어영대장 구선복",
		"role": "노론 / 군부 실세",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NORON,
		"cost": 250,
		"salary": 250,
		"academic": 0,
		"desc": "국방력 +15/달 (부작용: 군량 -10/달)",
		"is_western": false
	},
	"hong_gukyeong": {
		"id": "guk",
		"key": "hong_gukyeong",
		"name": "도승지 홍국영",
		"role": "노론 / 측근·숙위소 대장",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NORON,
		"cost": 220,
		"salary": 220,
		"academic": 0,
		"desc": "등용 즉시 왕권 +15 (부작용: 민심 -1/달)",
		"is_western": false
	},
	"lee_gigyeong": {
		"id": "lee_gigyeong",
		"key": "lee_gigyeong",
		"name": "이기경",
		"role": "남인 / 척사파",
		"role_type": RoleType.COURT_SCHOLAR,
		"faction": Faction.NAMIN,
		"cost": 70,
		"salary": 70,
		"academic": -4,
		"desc": "서학 탄압으로 학문력 -2/달, 정약용과 불화",
		"is_western": false
	}
}

## 탕평도 계산 (무정파 현장 기술 장인 100% 제외)
## 공식: (1.0 - (max_share - 0.25) / 0.75) * 100.0 (0~100 clamp)
static func calculate_faction_balance(retainers: Dictionary) -> float:
	var court_scholars: Array[Dictionary] = []
	for key in TALENTS_DATA.keys():
		if bool(retainers.get(key, false)):
			var s_data: Dictionary = TALENTS_DATA[key]
			var f: int = int(s_data.get("faction", Faction.NONE))
			# 무정파(NONE) 장인/기술자는 분모에서 원천 제외
			if f != Faction.NONE:
				court_scholars.append(s_data)

	if court_scholars.is_empty():
		return 50.0 # 기본 균형치

	var faction_counts: Dictionary = {
		Faction.NORON: 0,
		Faction.SORON: 0,
		Faction.NAMIN: 0,
		Faction.BUKHAK: 0
	}

	for s: Dictionary in court_scholars:
		var fac: int = int(s.get("faction", Faction.NONE))
		if faction_counts.has(fac):
			faction_counts[fac] = int(faction_counts[fac]) + 1

	var max_count: int = 0
	for cnt: int in faction_counts.values():
		if cnt > max_count:
			max_count = cnt

	var max_share: float = float(max_count) / float(court_scholars.size())
	return clampf((1.0 - (max_share - 0.25) / 0.75) * 100.0, 0.0, 100.0)

## 등용된 사대부 인재들의 학문력 기여 합산 (무정파 장인은 0)
static func get_scholars_academic_power(retainers: Dictionary) -> int:
	var total: int = 0
	for key in TALENTS_DATA.keys():
		if bool(retainers.get(key, false)):
			var s_data: Dictionary = TALENTS_DATA[key]
			var r_type: int = int(s_data.get("role_type", RoleType.COURT_SCHOLAR))
			# 사대부 인재 및 김홍도 학문력 반영 (무정파 장인은 0)
			if r_type == RoleType.COURT_SCHOLAR or key == "kim_hongdo":
				total += int(s_data.get("academic", 0))
	return total

## 서학 성향 인재 등용 여부 확인 (정약용, 이가환, 홍대용 등)
static func has_western_scholar_hired(retainers: Dictionary) -> bool:
	for key in TALENTS_DATA.keys():
		if bool(retainers.get(key, false)):
			var s_data: Dictionary = TALENTS_DATA[key]
			if bool(s_data.get("is_western", false)):
				return true
	return false

## 서학 성향 등용 인재 수 반환
static func count_western_scholars_hired(retainers: Dictionary) -> int:
	var count: int = 0
	for key in TALENTS_DATA.keys():
		if bool(retainers.get(key, false)):
			var s_data: Dictionary = TALENTS_DATA[key]
			if bool(s_data.get("is_western", false)):
				count += 1
	return count

## 전역 등용 인재 캐시 (중복 등용 100% 방지)
static var hired_scholars: Dictionary = {}

static func normalize_scholar_id(scholar_id: String) -> String:
	var norm_id: String = scholar_id
	match scholar_id:
		"jeong": norm_id = "jeong_yakyong"
		"park": norm_id = "park_jega"
		"seo": norm_id = "seo_yugu"
		"chae": norm_id = "chae_jegong"
		"baek": norm_id = "baek_dongsu"
		"kim": norm_id = "kim_hongdo"
		"guk": norm_id = "hong_gukyeong"
		"gu": norm_id = "gu_seonbok"
		"hong": norm_id = "hong_inhan"
		"jo": norm_id = "jo_simtae"
		"bau": norm_id = "kim_bau"
		"yu": norm_id = "yu_hanji"
		"gahwan": norm_id = "lee_gahwan"
	return norm_id

## 필수 인재 등용 여부 확인 (O(1) 해시 조회, 별칭 및 남인 정파 포괄 지원)
static func has_scholar(scholar_id: String, retainers: Dictionary = {}) -> bool:
	if scholar_id == "":
		return true
	if scholar_id == "namin":
		return is_scholar_hired("chae_jegong", retainers) or is_scholar_hired("jeong_yakyong", retainers)

	var norm_id: String = normalize_scholar_id(scholar_id)
	if bool(hired_scholars.get(norm_id, false)):
		return true
	return bool(retainers.get(norm_id, false))

## 필수 인재 등용 여부 확인 (별칭 메서드)
static func is_scholar_hired(scholar_id: String, retainers: Dictionary = {}) -> bool:
	return has_scholar(scholar_id, retainers)

## 인재 직접 등용 및 상태 즉시 반영 (중복 등용 차단 및 국고 차감)
static func hire_scholar(scholar_id: String, sim: SimulationCore = null, court: CourtSystem = null) -> bool:
	var norm_id: String = normalize_scholar_id(scholar_id)
	if is_scholar_hired(norm_id, sim.retainers if sim != null else {}):
		return false # 이미 등용된 인재는 중복 질문 및 재등용 차단

	var cost: int = 150
	if TALENTS_DATA.has(norm_id):
		cost = int(TALENTS_DATA[norm_id].get("cost", 150))
	elif court != null and court.SCHOLARS.has(norm_id):
		cost = int(court.SCHOLARS[norm_id].get("cost", 150))

	if sim != null:
		if sim.gold < cost:
			return false
		sim.gold -= cost
		sim.retainers[norm_id] = true

	hired_scholars[norm_id] = true

	if court != null:
		court.update_faction_and_academic()

	GameProgressManager.unlock_puzzle_piece("people", norm_id)
	return true

