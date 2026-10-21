extends Node2D
class_name RoyalProcessionManager
const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 1795년 을묘원행(乙卯園幸) 국책 대기록 이벤트 및 8일간의 화성 행차 시뮬레이션 매니저
## - 발동 조건 검증 (왕권, 민심, 성곽 폐곡선, 도로/박석길, 자원, 3대 인재)
## - 게임 시간 일시정지 및 도시 환경 상태 전환 (전시/도적 억제, 백성 환호 모드)
## - 《원행을묘정리의궤》 기반 대규모 능행차 행렬 (6개 제대, 트레일 추종, 풀링)
## - 격쟁(擊錚 10종) & 상언(上言 10종) 인터랙션 모달
## - 행궁 3대 의례 (봉수당 진찬연, 낙남헌 양로연, 신풍루 사미)
## - 서장대 야조 (야간 조명, 횃불, 신포 사격, 장용영 야간 기동)
## - 화성 별시 (낙남헌 앞마당 문무 과거시험, 어사화 수여)
## - 팔달문 출정 및 융릉 참배 퇴장, 이벤트 완수 및 정상 롤백

signal eulmyo_started
signal eulmyo_phase_changed(phase_name: String, phase_title: String)
signal petition_triggered(petition_data: Dictionary)
signal eulmyo_completed

enum Phase {
	NONE = 0,
	ENTRY_PROCESSION = 1, # 1. 한양 외곽 -> 장안문 -> 신풍루 진입 능행차
	CEREMONY_BONGSU = 2,  # 2. 봉수당 진찬연 (혜경궁 홍씨 회갑연, 여민락 무용)
	CEREMONY_NAKNAM = 3,  # 3. 낙남헌 양로연 (70세 이상 고을 노인 잔치 및 지팡이 하사)
	CEREMONY_SINPUNG = 4, # 4. 신풍루 사미 (백성들에게 구휼미 직접 배급)
	SEOJANGDAE_YAJO = 5,  # 5. 서장대 야조 (야간 군사 훈련, 횃불, 신포 사격)
	YEONMUDAE_ARCHERY = 6,# 6. 연무대(동장대) 사열 및 정조 대왕 친림 활쏘기 (득중정 어사)
	BYEOLSI_EXAM = 7,     # 7. 화성 별시 (낙남헌 앞마당 문무 과거시험, 어사화 수여)
	EXIT_PROCESSION = 8,  # 8. 행궁 -> 팔달문(남문) -> 융릉 참배 출정 및 퇴장
	FINISHED = 9          # 9. 완수 축하 팝업 및 정상 상태 롤백
}

var current_phase: Phase = Phase.NONE
var phase_timer: float = 0.0

# 참조 객체
var sim: SimulationCore
var grid: GameGrid
var citizens: CitizenManager
var time_manager: TimeManager
var hud: HUDController
var panels: PanelController
var city_layer: CityLayer
var camera: CameraController = null

# 발동 상태 플래그 및 매월 정기 평가 추적
var eulmyo_triggered: bool = false
var _last_eval_year: int = -1
var _last_eval_month: int = -1

# 트레일 및 행렬 유닛 풀링
var waypoints: Array[Vector2] = []
var trail_history: Array[Vector2] = []
var procession_units: Array[Dictionary] = []
var lead_distance_traveled: float = 0.0
const MARCH_SPEED: float = 46.0 # 초당 픽셀 이동 속도
const UNIT_SPACING: float = 24.0 # 제대 내 유닛 간 거리

# 백성 원래 상태 백업 (롤백용)
var _backup_agent_states: Array[Dictionary] = []
var _hidden_predators: Array[Dictionary] = []
var _orig_time_speed: int = 1

# 모달 및 오버레이 UI 노드
var _ui_layer: CanvasLayer = null
var _night_rect: ColorRect = null
var _modal_panel: PanelContainer = null
var _is_modal_open: bool = false
var _active_petition: Dictionary = {}

# 연도(沿道) 도열 백성 풀링 및 앰비언트 시스템
var crowd_spectators: Array[Dictionary] = []
var _spectator_talk_timer: float = 0.0

# 격쟁/상언 돌발 인터랙션 FSM 상태
enum PetitionFSM {
	NONE,
	RUNNING_IN,    # 꽹과리 치며 / 상소문 들고 도로 중앙 난입
	DIALOGUE,      # 정조 대왕 어명 및 백성 호소 대사, 모달 팝업 표시
	RESOLVING,     # 승정원 상소 접수 및 어명 처리
	STEPPING_BACK  # 감격하여 큰절 후 도로변으로 퇴장
}
var petition_fsm: PetitionFSM = PetitionFSM.NONE
var petition_fsm_timer: float = 0.0
var petition_actor: Dictionary = {}
var king_speech_text: String = ""
var king_speech_timer: float = 0.0
var _pending_petition_cat: String = ""
var _petition_auto_timer: float = 0.0 # 자동 진행 타이머 (데드락 방지용 4초)

# 야간 효과 (서장대 야조)
var night_alpha: float = 0.0
var _torch_flicker: float = 0.0
var _cannon_flash: float = 0.0

# 의례 연출 위치 (BuildingManager 동적 갱신)
var haenggung_pos: Vector2i = Vector2i(-1, -1)
var sinpungru_pos: Vector2i = Vector2i(-1, -1)
var naknam_pos: Vector2i = Vector2i(-1, -1)
var seojangdae_pos: Vector2i = Vector2i(-1, -1)
var yeonmudae_pos: Vector2i = Vector2i(-1, -1)
var paldal_pos: Vector2i = Vector2i(-1, -1)
var jangan_pos: Vector2i = Vector2i(-1, -1)

# 격쟁(10종) & 상언(10종) 마스터 데이터
var petitions_gyeokjaeng: Array[Dictionary] = [
	{
		"id": "g_1", "type": "격쟁(擊錚)", "petitioner": "대유둔전 농민 장칠석",
		"title": "대유둔전 수세 감면 청원",
		"desc": "가뭄과 흙바람에 벼이삭이 마르고 둔전 지세가 무거워 양식이 동났사옵니다. 징을 치며 엎드려 비오니 지세를 감면하여 주옵소서!",
		"accept_text": "임금께서 어명을 내려 둔전세를 반으로 감하고 백성을 보듬으셨습니다.",
		"reject_text": "국고 지출을 감안하여 징을 친 농민을 타일러 논으로 돌려보냈습니다.",
		"effects_accept": {"loyalty": 5, "gold": -2000, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -2, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_2", "type": "격쟁(擊錚)", "petitioner": "수원천 천변 뱃사공 마당쇠",
		"title": "수원천 보 수축 요구",
		"desc": "장마철마다 하천 둑이 터져 초가삼간이 물에 잠기옵니다. 성역 공사에 수원천 보(洑)와 둑을 튼튼히 보수해 주옵소서!",
		"accept_text": "석축 보 공사를 즉시 발주하여 수원천 치수 공사를 강화하였습니다.",
		"reject_text": "당장의 축성 공역에 집중하고자 탄원을 차후로 미루었습니다.",
		"effects_accept": {"loyalty": 4, "gold": -1500, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -1, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_3", "type": "격쟁(擊錚)", "petitioner": "팔달산 밑 빈민 과부 김씨",
		"title": "환곡 이자 탕감 요청",
		"desc": "지난해 빌린 환곡에 이자가 갑절로 불어나 자식들을 굶기고 있사옵니다. 성군의 자비로 모곡(耗穀) 이자를 탕감해 주옵소서!",
		"accept_text": "환곡 빚을 전액 탕감하고 구휼미를 내리시니 백성들이 만세를 불렀습니다.",
		"reject_text": "창고 규율을 지키기 위해 감면을 불허하고 기한을 연장해주었습니다.",
		"effects_accept": {"loyalty": 8, "gold": 0, "rice": -5000, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -3, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_4", "type": "격쟁(擊錚)", "petitioner": "석수 인부 박바우",
		"title": "부당한 부역 면제 탄원",
		"desc": "관아의 일부 군관이 공사 품삯을 가로채고 무보수 부역을 강요하옵니다. 정조 대왕의 모립제 원칙대로 바로잡아 주옵소서!",
		"accept_text": "어명으로 탐학한 관리를 삭탈관직하고 인부들에게 정당한 품삯을 지급했습니다.",
		"reject_text": "공정 지연을 우려하여 현장 감관에게 조사를 넘겼습니다.",
		"effects_accept": {"loyalty": 6, "gold": -1000, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -2, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_5", "type": "격쟁(擊錚)", "petitioner": "남문 밖 죄수 가족 최봉석",
		"title": "억울한 옥살이 호소",
		"desc": "토호의 모함으로 옥에 갇힌 아비의 결백을 밝혀주옵소서. 징을 울리며 임금님의 행차 앞에 목숨 걸고 엎드립니다!",
		"accept_text": "임금께서 친히 사건을 재조사하게 하여 억울한 죄수를 즉시 석방했습니다.",
		"reject_text": "고을 수령의 판결을 존중하여 관아로 돌려보냈습니다.",
		"effects_accept": {"loyalty": 5, "gold": 0, "rice": 0, "authority": 1, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -1, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_6", "type": "격쟁(擊錚)", "petitioner": "저잣거리 노점상 윤칠복",
		"title": "저잣거리 난전 자율화 청원",
		"desc": "시전 상인들이 난전을 금압하여 보부상과 소상인들이 입에 풀칠을 못 하옵니다. 신해통공의 뜻을 화성에도 베풀어 주옵소서!",
		"accept_text": "금난전권을 철폐하여 난전을 허용하니 시장 상권이 크게 활성화되었습니다.",
		"reject_text": "시전 상인들의 기득권 반발을 고려하여 규제를 유지했습니다.",
		"effects_accept": {"loyalty": 7, "gold": -800, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -2, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_7", "type": "격쟁(擊錚)", "petitioner": "동문 밖 이재민 백달수",
		"title": "가뭄 피해주민 구휼미 요청",
		"desc": "봄가뭄에 씨앗마저 떨어져 흙과 풀뿌리로 연명하고 있사옵니다. 어가 행차의 자비로 사미(賜米)를 내려 주옵소서!",
		"accept_text": "행궁 창고를 열어 굶주린 이재민들에게 쌀을 넉넉히 나누어주었습니다.",
		"reject_text": "향후 군량 비축을 위해 긴급 배급량을 줄였습니다.",
		"effects_accept": {"loyalty": 6, "gold": 0, "rice": -3000, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -2, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_8", "type": "격쟁(擊錚)", "petitioner": "광교산 소작농 오억쇠",
		"title": "지방 토호의 토지 강탈 고발",
		"desc": "권세가 토호가 문서를 위조해 조상 대대로 물려받은 전답을 빼앗아갔사옵니다. 성주이신 전하께서 억울함을 풀어주소서!",
		"accept_text": "토호의 불법 토지를 몰수하여 농민에게 돌려주었습니다. (사대부 일부 반발)",
		"reject_text": "사대부 가문의 반발을 우려해 관아의 조율에 맡겼습니다.",
		"effects_accept": {"loyalty": 8, "gold": 0, "rice": 0, "authority": -3, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -4, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_9", "type": "격쟁(擊錚)", "petitioner": "칠보산 산간마을 사포수 손덕배",
		"title": "호환 피해 보상 요구",
		"desc": "지난달 백두대간에서 내려온 큰 호랑이에 일가친척이 다치고 소를 잃었사옵니다. 포호 위로금을 하사해 주옵소서!",
		"accept_text": "장용영 착호갑사를 급파하고 피해 가구에 위로금을 하사했습니다.",
		"reject_text": "개인적인 야생 피해로 보아 위로금을 감액했습니다.",
		"effects_accept": {"loyalty": 5, "gold": -800, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -1, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "g_10", "type": "격쟁(擊錚)", "petitioner": "수원부 효자마을 주민 일동",
		"title": "효자·열녀 정려문 포상 청원",
		"desc": "눈먼 부모를 20년 모신 가난한 효자와 절개를 지킨 열녀에게 조정의 정려(旌閭)와 쌀을 하사하시어 풍속을 바로잡아 주소서!",
		"accept_text": "효열을 칭송하며 정려문을 세우고 상금을 하사하여 효심을 진작했습니다.",
		"reject_text": "심사가 더 필요하다 하여 예조로 안건을 넘겼습니다.",
		"effects_accept": {"loyalty": 4, "gold": -500, "rice": 0, "authority": 2, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	}
]

var petitions_sangeon: Array[Dictionary] = [
	{
		"id": "s_1", "type": "상언(上言)", "petitioner": "수원향교 장의 이선달",
		"title": "화성 향교 학전 확대 요청",
		"desc": "화성이 유신(維新)의 도읍이 되려면 인재 양성이 근본이옵니다. 향교에 학전(學田)과 서책을 넉넉히 하사해 주옵소서.",
		"accept_text": "향교 학전과 유생 장학금을 증액하여 화성의 학문 기틀을 세웠습니다.",
		"reject_text": "재정 한계를 이유로 차후 증설을 검토하기로 했습니다.",
		"effects_accept": {"loyalty": 0, "gold": -3000, "rice": 0, "authority": 0, "academic": 5, "defense": 0},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": -1, "defense": 0}
	},
	{
		"id": "s_2", "type": "상언(上言)", "petitioner": "규장각 검서관 유득공",
		"title": "규장각 서적 화성 보급",
		"desc": "왕실 서고인 규장각의 《대전통편》과 실학 서적을 화성 봉수당과 서원에 분관 비치하시어 백성과 관리가 함께 읽게 하소서.",
		"accept_text": "규장각 서적 수백 권을 화성에 이봉하여 문화와 학문 수준을 드높였습니다.",
		"reject_text": "왕실 비장의 원본 유출을 염려하여 보급을 축소했습니다.",
		"effects_accept": {"loyalty": 0, "gold": -1000, "rice": 0, "authority": 3, "academic": 8, "defense": 0},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_3", "type": "상언(上言)", "petitioner": "경기 유림 대표 정만식",
		"title": "사도세자 추숭 및 묘호 건의",
		"desc": "현륭원에 묻히신 장헌세자(사도세자)를 국왕으로 추숭하시어 왕실의 정통성과 효도를 천하에 밝히소서!",
		"accept_text": "부왕에 대한 효심을 온 천하에 천명하여 왕권을 드높였습니다. (보수파 일부 반발)",
		"reject_text": "조정의 당쟁과 혼란을 경계하여 때를 기다리기로 하였습니다.",
		"effects_accept": {"loyalty": -2, "gold": 0, "rice": 0, "authority": 10, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": -3, "academic": 0, "defense": 0}
	},
	{
		"id": "s_4", "type": "상언(上言)", "petitioner": "암행어사 출신 유생 박종수",
		"title": "부패 아전 엄벌 상소",
		"desc": "읍치 관아의 일부 이방과 군교들이 둔전 세금을 가로채고 백성을 능멸하옵니다. 엄벌에 처해 관기를 바로잡으소서!",
		"accept_text": "부패 아전을 즉시 파직하고 곤장을 쳐 백성들의 칭송을 받았습니다. (향리 세력 불만)",
		"reject_text": "실무 행정의 공백을 우려하여 경고 조치로 갈음했습니다.",
		"effects_accept": {"loyalty": 7, "gold": 0, "rice": 0, "authority": -4, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": -3, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_5", "type": "상언(上言)", "petitioner": "남인 실학 유생 이승훈",
		"title": "서학(西學) 서적 검열 완화",
		"desc": "서양의 기하학·수리학·천문학 서적은 성역 축성과 수리관개에 큰 보탬이 되옵니다. 학문적 연구를 허락하소서!",
		"accept_text": "과학기술 서적의 연구를 윤허하여 실학적 도시 설계를 발전시켰습니다.",
		"reject_text": "성리학 정통을 지키기 위해 서학 연구를 엄격히 제한했습니다.",
		"effects_accept": {"loyalty": 0, "gold": 0, "rice": 0, "authority": -3, "academic": 6, "defense": 0},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": -2, "defense": 0}
	},
	{
		"id": "s_6", "type": "상언(上言)", "petitioner": "호조 참의 권대운",
		"title": "장용영 군포세 현실화",
		"desc": "장용영 군사들의 유지비가 막대하오니, 화성 관내 부호들에게 균등하게 군포를 징수하여 국고를 보충하소서.",
		"accept_text": "호포를 징수하여 군영 재정을 탄탄히 확충했습니다. (부호들의 불만 발생)",
		"reject_text": "백성의 조세 부담을 늘리지 않겠다는 정조의 신념에 따라 반려했습니다.",
		"effects_accept": {"loyalty": -3, "gold": 4000, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": 2, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_7", "type": "상언(上言)", "petitioner": "장용영 대장 구선복",
		"title": "삼수병 편제 정비 건의",
		"desc": "화성 성벽 포루와 공심돈에 배치할 포수(砲手)와 사수(射手)의 훈련 체계를 고쳐 성곽 방호력을 굳건히 하소서.",
		"accept_text": "삼수병 편제를 엄히 재편하고 조총을 보급하여 성곽 방호력을 극대화했습니다.",
		"reject_text": "군사 지출을 아끼고자 기존 훈련 체계를 유지했습니다.",
		"effects_accept": {"loyalty": 0, "gold": -2500, "rice": 0, "authority": 0, "academic": 0, "defense": 50},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_8", "type": "상언(上言)", "petitioner": "사헌부 지평 심환지",
		"title": "과거 시험 부정 척결",
		"desc": "이번 화성 별시에서 문벌 귀족의 자제들이 대술(代述)과 부정청탁을 시도하려 하옵니다. 시험장을 엄단하소서!",
		"accept_text": "시험 감독을 철저히 강화하고 부정행위자를 엄벌하여 공정을 확립했습니다.",
		"reject_text": "소요를 막기 위해 관례대로 온건히 치르도록 하였습니다.",
		"effects_accept": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 4, "academic": 5, "defense": 0},
		"effects_reject": {"loyalty": -3, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_9", "type": "상언(上言)", "petitioner": "성설 설계관 정약용",
		"title": "벽돌·석재 규격 표준화",
		"desc": "전유(磚踰) 벽돌과 장석(長石)의 규격을 표준화하면 향후 축성 및 보수 비용을 영구히 줄일 수 있사옵니다.",
		"accept_text": "석재 표준 거푸집을 제작 보급하여 건축 효율을 비약적으로 높였습니다.",
		"reject_text": "초기 틀 제작 비용을 아끼고자 장인 재량에 맡겼습니다.",
		"effects_accept": {"loyalty": 0, "gold": -2000, "rice": 0, "authority": 0, "academic": 3, "defense": 20},
		"effects_reject": {"loyalty": 0, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	},
	{
		"id": "s_10", "type": "상언(上言)", "petitioner": "개성상단 대도방 만석",
		"title": "은광 및 삼남 상업로 개척",
		"desc": "화성 삼남대로를 남양만 포구와 연결하여 청나라 및 왜관과의 은 무역로를 열면 막대한 상업 이익이 생기옵니다.",
		"accept_text": "대외 상업로를 개척하여 막대한 금화를 국고에 유입시켰습니다. (일부 농본파 반발)",
		"reject_text": "농업 근본주의를 지키고자 상업로 확장을 보류했습니다.",
		"effects_accept": {"loyalty": -2, "gold": 5000, "rice": 0, "authority": 0, "academic": 0, "defense": 0},
		"effects_reject": {"loyalty": 1, "gold": 0, "rice": 0, "authority": 0, "academic": 0, "defense": 0}
	}
]

func _init() -> void:
	name = "RoyalProcessionManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 900 # PORT-TRACE [을묘원행 안 보임]: 지형·건물 조각 그림(z 10~76) 위에 오도록 — 예전 값은 조각에 덮였다

func _ready() -> void:
	_setup_ui_layer()

## 외부 모듈 의존성 설정 및 월별 검사 바인딩
func setup(
	s_core: SimulationCore,
	g_grid: GameGrid,
	c_mgr: CitizenManager,
	t_mgr: TimeManager,
	h_hud: HUDController = null,
	p_panels: PanelController = null,
	c_layer: CityLayer = null,
	cam: CameraController = null
) -> void:
	sim = s_core
	grid = g_grid
	citizens = c_mgr
	time_manager = t_mgr
	hud = h_hud
	panels = p_panels
	city_layer = c_layer
	camera = cam

	_update_facility_positions()

	if time_manager:
		if not time_manager.month_changed.is_connected(_on_month_changed):
			time_manager.month_changed.connect(_on_month_changed)
		if not time_manager.year_changed.is_connected(_on_year_changed):
			time_manager.year_changed.connect(_on_year_changed)

## 시설별 중심 및 출입구 좌표 동적 갱신
func _update_facility_positions() -> void:
	if grid == null:
		return
	var h_yard := BuildingManager.get_building_center_pos("haenggung_yard", grid)
	if h_yard.x >= 0: haenggung_pos = h_yard
	var s_ru := BuildingManager.get_building_center_pos("haenggung_sinpungru", grid)
	if s_ru.x >= 0: sinpungru_pos = s_ru
	var n_nam := BuildingManager.get_building_center_pos("haenggung_naknam", grid)
	if n_nam.x >= 0: naknam_pos = n_nam
	var s_jang := BuildingManager.get_building_center_pos("seojangdae", grid)
	if s_jang.x >= 0: seojangdae_pos = s_jang
	var y_mu := BuildingManager.get_building_center_pos("yeonmudae", grid)
	if y_mu.x >= 0: yeonmudae_pos = y_mu
	var j_gate := BuildingManager.get_building_center_pos("jangan_gate", grid)
	if j_gate.x >= 0: jangan_pos = j_gate
	var p_gate := BuildingManager.get_building_center_pos("paldal_gate", grid)
	if p_gate.x >= 0: paldal_pos = p_gate

	if jangan_pos.x < 0 and grid.has_method("get_four_gates_positions"):
		jangan_pos = grid.get_four_gates_positions().get("jangan", Vector2i(-1, -1))
	if paldal_pos.x < 0 and grid.has_method("get_four_gates_positions"):
		paldal_pos = grid.get_four_gates_positions().get("paldal", Vector2i(-1, -1))


func _on_month_changed(month: int) -> void:
	evaluate_monthly_trigger(month)

func _on_year_changed(_year: int) -> void:
	evaluate_monthly_trigger()

## 매월 초 및 연도 변경 시 발동 평가 (1795년 Grace Window 및 1795년 이후 Late Procession)
func evaluate_monthly_trigger(_m: int = -1, force: bool = false) -> bool:
	if sim == null or grid == null or time_manager == null:
		return false
	if eulmyo_triggered or sim.is_eulmyo_active or sim.is_eulmyo_completed:
		return false

	var yr: int = time_manager.current_year
	if yr < 1795:
		return false

	var cur_m: int = time_manager.current_month
	if not force and _last_eval_year == yr and _last_eval_month == cur_m:
		return false
	_last_eval_year = yr
	_last_eval_month = cur_m

	var is_ok: bool = check_eulmyo_conditions()
	if is_ok:
		eulmyo_triggered = true
		var is_late: bool = (yr > 1795)
		if is_late:
			if hud:
				hud._show_toast("지연된 을묘원행 거행! 모든 조건을 갖추어 능행차가 장안문으로 입성합니다.", "🥁")
			print_debug("[을묘원행 발동] 1795년 이후 조건을 달성하여 지연된 을묘원행(Late Procession)이 발동되었습니다. (%d년 %d월)" % [yr, cur_m])
		else:
			print_debug("[을묘원행 발동] 1795년 을묘원행 정규 발동. (%d년 %d월)" % [yr, cur_m])
		return start_eulmyo_event(sim, grid, citizens, time_manager, hud, panels, city_layer, camera)
	return false

## 조건 검증 및 디버그 로깅 함수 (프롬프트 사양 준수)
func check_eulmyo_conditions() -> bool:
	if sim == null or grid == null:
		print_debug("[을묘원행 조건 미달] sim 또는 grid 참조가 설정되지 않음")
		return false

	_update_facility_positions()

	var wall_ok: bool = false
	if grid.wall_loop_validator != null:
		var v_res: Dictionary = grid.wall_loop_validator.validate_loop(grid)
		wall_ok = bool(v_res.get("is_closed_loop", false)) or int(v_res.get("validated_progress", 0)) >= 100
	if not wall_ok and sim.fortress_progress >= 100:
		wall_ok = true
	if not wall_ok and grid.has_method("is_wall_loop_completed"):
		wall_ok = grid.is_wall_loop_completed()

	var gates_ok: bool = grid.are_all_four_gates_built() if grid.has_method("are_all_four_gates_built") else _check_all_four_gates(grid)
	var road_res: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(grid)
	var road_ok: bool = bool(road_res.get("ok", false))
	var haenggung_ok: bool = bool(road_res.get("haenggung_built", false))
	var gold_ok: bool = (sim.gold >= 200000)
	var food_ok: bool = (sim.rice >= 200000)
	var royal_power_ok: bool = (sim.authority >= 50)
	var morale_ok: bool = (sim.loyalty >= 80)
	var scholars_ok: bool = (
		bool(sim.retainers.get("chae_jegong", false))
		and bool(sim.retainers.get("jeong_yakyong", false))
		and bool(sim.retainers.get("kim_hongdo", false))
	)

	# 미달된 조건이 있다면 콘솔에 명확히 출력
	if not (wall_ok and gates_ok and haenggung_ok and road_ok and gold_ok and food_ok and royal_power_ok and morale_ok and scholars_ok):
		var err_msg: String = String(road_res.get("error_msg", ""))
		if err_msg != "":
			print(err_msg)
		print("[을묘원행 조건 미달] 성벽:", wall_ok, " 사대문:", gates_ok, " 행궁:", haenggung_ok, " 도로망:", road_ok, " 금화:", gold_ok, " 식량:", food_ok, " 왕권:", royal_power_ok, " 민심:", morale_ok, " 인재3인:", scholars_ok)
		return false
	return true

static func _check_all_four_gates(g: GameGrid) -> bool:
	if g == null:
		return false
	if g.has_method("are_all_four_gates_built"):
		return g.are_all_four_gates_built()
	var g_map: Dictionary = g.get_four_gates_positions()
	for k: String in ["jangan", "paldal", "hwaseo", "changryong"]:
		var p: Vector2i = g_map.get(k, Vector2i(-1, -1))
		if p.x < 0 or p.y < 0 or not g.in_bounds(p.x, p.y):
			return false
	return true

## =========================================================================
## 1. 발동 조건 검증 (can_trigger_eulmyo_event)
## =========================================================================
static func can_trigger_eulmyo_event(s: SimulationCore, g: GameGrid) -> Dictionary:
	var reasons: Array[String] = []
	var details: Dictionary = {
		"authority_ok": false,
		"loyalty_ok": false,
		"fortress_ok": false,
		"gates_ok": false,
		"road_connected_ok": false,
		"paved_road_ok": false,
		"gold_ok": false,
		"rice_ok": false,
		"retainers_ok": false
	}

	if s == null or g == null:
		return {"can_trigger": false, "reasons": ["조정 또는 지형 자료가 없습니다"], "details": details}

	# 1) 정치/도시 지표: 왕권 50점 이상, 민심 80점 이상
	details["authority_ok"] = (s.authority >= 50)
	if not details["authority_ok"]:
		reasons.append("왕권 부족 (현재: %d / 필요: 50)" % s.authority)

	details["loyalty_ok"] = (s.loyalty >= 80)
	if not details["loyalty_ok"]:
		reasons.append("민심 부족 (현재: %d / 필요: 80)" % s.loyalty)

	# 2) 성곽 인프라: 성곽 완성도 100% (사대문 완전 연결 폐곡선)
	var is_loop: bool = false
	if g.wall_loop_validator != null:
		var v_res: Dictionary = g.wall_loop_validator.validate_loop(g)
		is_loop = bool(v_res.get("is_closed_loop", false)) or int(v_res.get("validated_progress", 0)) >= 100
	if not is_loop and s.fortress_progress >= 100:
		is_loop = true # 포트 호환 fallback

	details["fortress_ok"] = is_loop
	if not details["fortress_ok"]:
		reasons.append("성곽 미완성 (사대문 완전 연결 폐곡선 100% 필요, 현재: " + str(s.fortress_progress) + "%)")

	# 사대문 완공 여부
	var gates_ok: bool = g.are_all_four_gates_built() if g.has_method("are_all_four_gates_built") else _check_all_four_gates(g)
	details["gates_ok"] = gates_ok
	if not details["gates_ok"]:
		reasons.append("사대문(장안문·팔달문·화서문·창룡문) 미완공")

	# 3) 자원: 금화 200,000냥 이상, 식량 200,000석 이상
	details["gold_ok"] = (s.gold >= 200000)
	if not details["gold_ok"]:
		reasons.append("국고 금화 부족 (현재: %d냥 / 필요: 200,000냥)" % s.gold)

	details["rice_ok"] = (s.rice >= 200000)
	if not details["rice_ok"]:
		reasons.append("군량 식량 부족 (현재: %d석 / 필요: 200,000석)" % s.rice)

	# 4) 필수 인재 풀: 체제공, 정약용, 김홍도 3인 모두 등용
	var chae: bool = bool(s.retainers.get("chae_jegong", false))
	var jeong: bool = bool(s.retainers.get("jeong_yakyong", false))
	var kim: bool = bool(s.retainers.get("kim_hongdo", false))
	details["retainers_ok"] = (chae and jeong and kim)
	if not details["retainers_ok"]:
		var missing_ret: Array[String] = []
		if not chae: missing_ret.append("체제공(총리대신)")
		if not jeong: missing_ret.append("정약용(성설/거중기)")
		if not kim: missing_ret.append("김홍도(자문각 화원)")
		reasons.append("필수 인재 미등용: %s" % [", ".join(missing_ret)])

	# 5) 도로망 및 행궁: 화성행궁 완공, 장안문-행궁-팔달문 도로 연속성 및 박석길 포장
	var road_check: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(g)
	details["haenggung_built_ok"] = bool(road_check.get("haenggung_built", false))
	details["road_connected_ok"] = bool(road_check.get("jangan_to_sinpung", false)) and bool(road_check.get("sinpung_to_paldal", false))
	details["paved_road_ok"] = bool(road_check.get("paved_stone", false))

	if not details["haenggung_built_ok"]:
		reasons.append(str(road_check.get("error_msg", "[을묘원행 발동 보류] 화성행궁(봉수당)이 축조되지 않았습니다.")))
	elif not details["road_connected_ok"]:
		reasons.append(str(road_check.get("error_msg", "[을묘원행 발동 보류] 장안문-행궁-팔달문 간 도로가 연결되지 않았습니다.")))
	elif not details["paved_road_ok"]:
		reasons.append(str(road_check.get("error_msg", "[을묘원행 발동 보류] 화성행궁 진입 도로는 박석길로 포장되어 있어야 합니다.")))

	var can_trig: bool = (
		details["authority_ok"] and details["loyalty_ok"] and details["fortress_ok"]
		and details["gates_ok"]
		and details["gold_ok"] and details["rice_ok"] and details["retainers_ok"]
		and details.get("haenggung_built_ok", false)
		and details["road_connected_ok"] and details["paved_road_ok"]
	)

	return {
		"can_trigger": can_trig,
		"reasons": reasons,
		"details": details
	}

## [도로 연결 필수 검증]: [장안문 ↔ 화성행궁(신풍루) ↔ 팔달문] 도로 연결 연속성 및 박석길 검증
static func verify_eulmyo_road_continuity(g: GameGrid) -> Dictionary:
	var res := {
		"ok": false,
		"haenggung_built": false,
		"jangan_to_sinpung": false,
		"sinpung_to_paldal": false,
		"paved_stone": false,
		"error_msg": ""
	}
	if g == null or g.grid.is_empty():
		res["error_msg"] = "지형 자료가 없습니다."
		return res

	# 시설 위치 식별 (BuildingManager SSOT)
	var jangan: Vector2i = BuildingManager.get_building_center_pos("jangan_gate", g)
	var paldal: Vector2i = BuildingManager.get_building_center_pos("paldal_gate", g)
	var sinpung: Vector2i = BuildingManager.get_building_center_pos("haenggung_sinpungru", g)
	var haenggung: Vector2i = BuildingManager.get_building_center_pos("haenggung_yard", g)

	if jangan.x < 0 and g.has_method("get_four_gates_positions"):
		jangan = g.get_four_gates_positions().get("jangan", Vector2i(-1, -1))
	if paldal.x < 0 and g.has_method("get_four_gates_positions"):
		paldal = g.get_four_gates_positions().get("paldal", Vector2i(-1, -1))

	# 1. 화성행궁 완공 여부 검사 (행궁 미축조 시 발동 유예)
	if haenggung.x < 0:
		res["error_msg"] = "[을묘원행 발동 보류] 화성행궁(봉수당)이 축조되지 않았습니다."
		return res
	res["haenggung_built"] = true

	if jangan.x < 0 or paldal.x < 0 or sinpung.x < 0:
		res["error_msg"] = "[을묘원행 발동 보류] 장안문, 신풍루 또는 팔달문 위치를 식별할 수 없습니다."
		return res

	# 신풍루 정문 앞 도로 타일 탐색
	var sinpung_road: Vector2i = _find_closest_road_cell(g, sinpung, 3)
	if sinpung_road.x < 0:
		sinpung_road = sinpung

	# 2. 장안문 -> 신풍루(행궁) 도로망 BFS 검증
	var j_to_s: bool = _is_road_connected_bfs(g, jangan, sinpung_road)
	res["jangan_to_sinpung"] = j_to_s

	# 3. 신풍루(행궁) -> 팔달문 도로망 BFS 검증
	var s_to_p: bool = _is_road_connected_bfs(g, sinpung_road, paldal)
	res["sinpung_to_paldal"] = s_to_p

	if not j_to_s or not s_to_p:
		res["error_msg"] = "[을묘원행 발동 보류] 장안문-행궁-팔달문 간 도로가 연결되지 않았습니다."
		return res

	# 4. 행궁 진입 도로 박석길(stone_road) 검증 (신풍루 주변 3칸 이내)
	var stone_found: bool = false
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cx: int = sinpung.x + dx
			var cy: int = sinpung.y + dy
			if g.in_bounds(cx, cy):
				var cell: Dictionary = g.grid[cy][cx]
				if (cell.get("building", "") == "road" or RoadNetwork.is_road_tile(cell)) and cell.get("road_type", "dirt") == "stone":
					stone_found = true
					break
		if stone_found:
			break

	res["paved_stone"] = stone_found
	if not stone_found:
		res["error_msg"] = "[을묘원행 발동 보류] 화성행궁 진입 도로는 박석길로 포장되어 있어야 합니다."
		return res

	res["ok"] = true
	return res

## 도로 BFS 연결 검사 헬퍼
static func _is_road_connected_bfs(g: GameGrid, start_pos: Vector2i, end_pos: Vector2i) -> bool:
	if not g.in_bounds(start_pos.x, start_pos.y) or not g.in_bounds(end_pos.x, end_pos.y):
		return false
	if start_pos == end_pos:
		return true

	var q: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {start_pos: true}

	while not q.is_empty():
		var curr: Vector2i = q.pop_front()
		if curr == end_pos or (absi(curr.x - end_pos.x) <= 1 and absi(curr.y - end_pos.y) <= 1):
			return true

		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = curr.x + d.x
			var ny: int = curr.y + d.y
			var npos: Vector2i = Vector2i(nx, ny)
			if not g.in_bounds(nx, ny) or visited.has(npos):
				continue
			var cell: Dictionary = g.grid[ny][nx]
			var b: String = str(cell.get("building", ""))
			var t: String = str(cell.get("terrain", ""))

			# 가옥/상점/공방/물 등은 엄격 통행 불가 (건물 관통 차단)
			if b in ["res", "house", "com", "ind", "shop", "farm", "agr"] or (t == "water" and not cell.get("is_bridge", false)):
				continue

			var is_walkable_road: bool = (
				RoadNetwork.is_road_tile(cell)
				or b in ["road", "gate", "bridge"]
				or bool(cell.get("is_bridge", false))
				or g.is_patrol_road(nx, ny)
				or b.begins_with("haenggung")
				or b.begins_with("jongnu")
				or (npos == end_pos)
			)
			if is_walkable_road:
				visited[npos] = true
				q.append(npos)
	return false

## 특정 좌표 주변 가장 가까운 도로 셀 탐색
static func _find_closest_road_cell(g: GameGrid, center: Vector2i, radius: int) -> Vector2i:
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var nx: int = center.x + dx
				var ny: int = center.y + dy
				if g.in_bounds(nx, ny):
					var cell: Dictionary = g.grid[ny][nx]
					if cell.get("building", "") == "road" or RoadNetwork.is_road_tile(cell):
						return Vector2i(nx, ny)
	return Vector2i(-1, -1)

## 하위 호환용 _check_road_and_paved 래퍼
static func _check_road_and_paved(g: GameGrid) -> Dictionary:
	var v_res: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(g)
	return {
		"connected": bool(v_res.get("jangan_to_sinpung", false)) and bool(v_res.get("sinpung_to_paldal", false)),
		"paved": bool(v_res.get("paved_stone", false)),
		"road_err": str(v_res.get("error_msg", "")),
		"paved_err": str(v_res.get("error_msg", ""))
	}

## =========================================================================
## 2. 을묘원행 발동 및 환경 전환 (start_eulmyo_event)
## =========================================================================
func start_eulmyo_event(
	s_core: SimulationCore,
	g_grid: GameGrid,
	c_mgr: CitizenManager,
	t_mgr: TimeManager,
	h_hud: HUDController = null,
	p_panels: PanelController = null,
	c_layer: CityLayer = null,
	cam: CameraController = null
) -> bool:
	sim = s_core
	grid = g_grid
	citizens = c_mgr
	time_manager = t_mgr
	hud = h_hud
	panels = p_panels
	city_layer = c_layer
	if cam:
		camera = cam

	_update_facility_positions()

	var check: Dictionary = can_trigger_eulmyo_event(sim, grid)
	if not check["can_trigger"]:
		var reason: String = check["reasons"][0] if not check["reasons"].is_empty() else "조건 미달"
		print_debug("[을묘원행 발동 거부] %s" % reason)
		if hud:
			hud._show_toast("을묘원행 조건 미달: " + reason, "⚠️")
		return false

	eulmyo_triggered = true

	# 1) 원자적 자원 차감 및 왕권 극대화
	sim.gold -= 200000
	sim.rice -= 200000
	sim.authority = 100
	sim.is_time_frozen = true
	sim.is_eulmyo_active = true

	# 2) 시간 일시정지 (PROCESS_MODE_ALWAYS로 행렬 및 UI는 지속 구동)
	if time_manager:
		_orig_time_speed = int(time_manager.current_speed)
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)

	# 3) 적대 개체 및 스폰 전면 억제
	sim.bandit_active = false
	if citizens:
		citizens.tiger_spawned = false
		_suppress_predators_and_hostiles()
		_switch_citizens_to_cheering_mode()

	# 4) 행렬 웨이포인트 경로 계산 및 유닛 풀링 초기화
	_build_procession_waypoints()
	_init_procession_units()
	_build_spectator_crowd()

	# 5) 1단계(진입 능행차) 개시
	current_phase = Phase.ENTRY_PROCESSION
	phase_timer = 0.0
	lead_distance_traveled = 0.0

	emit_signal("eulmyo_started")
	emit_signal("eulmyo_phase_changed", "ENTRY_PROCESSION", "1795년 을묘원행: 한양-화성 능행차 진입")

	if hud:
		hud._show_toast("1795년 을묘원행 거행! 정조 대왕과 혜경궁 홍씨의 어가 행렬이 장안문으로 입성합니다.", "🥁")

	queue_redraw()
	return true

## 적대 개체(호랑이, 도적) 숨김
func _suppress_predators_and_hostiles() -> void:
	if not citizens: return
	_hidden_predators.clear()
	for a: Dictionary in citizens.agents:
		var k: String = str(a.get("kind", ""))
		if k in ["tiger", "wolf", "bandit", "thief"]:
			a["_eulmyo_orig_visible"] = a.get("visible", true)
			a["visible"] = false
			_hidden_predators.append(a)

## 마을 백성들을 길가 환호/부복 모드로 강제 전이
func _switch_citizens_to_cheering_mode() -> void:
	if not citizens: return
	_backup_agent_states.clear()
	var cheer_words: Array[String] = [
		"상감마마 만세!", "자궁 마마 만수무강하소서!", "성군의 은덕이옵니다!", "태평성대로다!", "천세 천세 천천세!"
	]
	for a: Dictionary in citizens.agents:
		var k: String = str(a.get("kind", ""))
		if k in ["commoner", "farmer", "merchant", "artisan", "scholar", "jungin", "ajeon", "butcher"]:
			_backup_agent_states.append({
				"agent": a,
				"orig_state": a.get("state", "idle"),
				"orig_talk": a.get("talk", "")
			})
			a["state"] = "cheering"
			a["talk"] = cheer_words[randi() % cheer_words.size()]
			a["is_bowing"] = (randf() < 0.4) # 40% 부복, 60% 환호

## =========================================================================
## 3. 능행차 경로 생성 및 유닛 풀링 (도로망 엄격 추종: Strict Road Following)
## =========================================================================

## 도로망 기반 최단 경로 타일 목록 탐색 (BFS - 가옥 관통 엄격 차단)
func _find_road_path_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if grid == null or grid.grid.is_empty():
		return [start_cell]
	if start_cell == end_cell:
		return [start_cell]

	var q: Array[Vector2i] = [start_cell]
	var parent: Dictionary = {start_cell: start_cell}
	var found: bool = false

	while not q.is_empty():
		var curr: Vector2i = q.pop_front()
		if curr == end_cell:
			found = true
			break

		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = curr + d
			if not grid.in_bounds(n.x, n.y) or parent.has(n):
				continue
			var cell: Dictionary = grid.grid[n.y][n.x]
			var b: String = str(cell.get("building", ""))
			var t: String = str(cell.get("terrain", ""))

			# 가옥/상점/공방/물 등은 엄격히 통행 불가 (건물 관통 절대 차단)
			if b in ["res", "house", "com", "ind", "shop", "farm", "agr"] or (t == "water" and not cell.get("is_bridge", false)):
				if n != end_cell:
					continue

			var is_road: bool = (
				RoadNetwork.is_road_tile(cell)
				or b in ["road", "gate", "bridge"]
				or bool(cell.get("is_bridge", false))
				or grid.is_patrol_road(n.x, n.y)
				or b.begins_with("haenggung")
				or b.begins_with("jongnu")
				or (n == end_cell)
			)
			if is_road:
				parent[n] = curr
				q.append(n)

	if not found:
		# Fallback: 도로가 연결되지 않은 경우 대각선 가옥 관통을 절대 허용하지 않고 시작 셀 반환
		print_debug("[을묘원행 경로 오류] %s -> %s 간 도로 경로 탐색 실패 (가옥 관통 차단)" % [start_cell, end_cell])
		return [start_cell]

	var path: Array[Vector2i] = []
	var curr_p: Vector2i = end_cell
	while curr_p != start_cell:
		path.append(curr_p)
		curr_p = parent[curr_p]
	path.append(start_cell)
	path.reverse()
	return path

func _convert_cells_to_waypoints(cells: Array[Vector2i]) -> void:
	waypoints.clear()
	if cells.is_empty(): return
	if cells.size() == 1:
		waypoints.append(_cell_to_world(float(cells[0].x), float(cells[0].y)))
		return

	for i in range(cells.size() - 1):
		var p0: Vector2 = _cell_to_world(float(cells[i].x), float(cells[i].y))
		var p1: Vector2 = _cell_to_world(float(cells[i + 1].x), float(cells[i + 1].y))
		var dist: float = p0.distance_to(p1)
		var steps: int = maxi(2, int(dist / 8.0)) # 8px 단위 부드러운 정밀 보간
		for s in range(steps):
			var t: float = float(s) / float(steps)
			waypoints.append(p0.lerp(p1, t))
	waypoints.append(_cell_to_world(float(cells[-1].x), float(cells[-1].y)))

## 북쪽 외곽 -> 장안문 -> 신풍루(행궁 앞마당) 도로망 엄격 추종 경로 생성
func _build_procession_waypoints() -> void:
	_update_facility_positions()

	# 1. 장안문 위치 식별
	var jangan_target: Vector2i = jangan_pos
	if jangan_target.x < 0 and grid != null and grid.has_method("get_four_gates_positions"):
		var g_map: Dictionary = grid.get_four_gates_positions()
		jangan_target = g_map.get("jangan", Vector2i(26, 6))

	# 2. 북쪽 외곽 도로 시작점 (y=0~4)
	var north_start: Vector2i = Vector2i(jangan_target.x, 0)
	if grid != null and not grid.grid.is_empty():
		for y in range(mini(5, grid.size)):
			if RoadNetwork.is_road_tile(grid.grid[y][jangan_target.x]):
				north_start = Vector2i(jangan_target.x, y)
				break

	# 3. 신풍루 및 행궁 앞마당 도로 타일 식별
	var sinpung_target: Vector2i = sinpungru_pos
	if grid != null and not grid.grid.is_empty():
		var road_pos: Vector2i = _find_closest_road_cell(grid, sinpungru_pos, 3)
		if road_pos.x >= 0:
			sinpung_target = road_pos

	# 4. 도로망 기반 최단 경로 추출 (외곽 -> 장안문 -> 신풍루)
	var path_to_gate: Array[Vector2i] = _find_road_path_cells(north_start, jangan_target)
	var path_to_palace: Array[Vector2i] = _find_road_path_cells(jangan_target, sinpung_target)

	var full_cells: Array[Vector2i] = []
	for c: Vector2i in path_to_gate:
		full_cells.append(c)
	for i in range(1, path_to_palace.size()):
		full_cells.append(path_to_palace[i])

	_convert_cells_to_waypoints(full_cells)

	trail_history.clear()
	if not waypoints.is_empty():
		for j in range(400):
			trail_history.append(waypoints[0])

## 6개 제대 능행차 행렬 유닛 37기 풀링 초기화
func _init_procession_units() -> void:
	procession_units.clear()
	# 1) 제1제대: 경기감사 및 선도 기병대 (5기)
	_add_unit("gyeonggi_governor", "경기감사 서유대", Color("34495e"), true, false, 28.0)
	for i in range(4):
		_add_unit("lead_cavalry", "선도 기병", Color("2c3e50"), true, false, 28.0)

	# 2) 제2제대: 황의 취타대 (6기)
	var instruments: Array[String] = ["나발", "태평소", "용고", "자바라", "징", "대각"]
	for inst: String in instruments:
		_add_unit("chwita", "취타악사 (%s)" % inst, Color("f39c12"), false, false, 20.0)

	# 3) 제3제대: 총리대신 체제공 및 조정 대신 (5기)
	_add_unit("chae_jegong", "총리대신 체제공", Color("27ae60"), false, false, 20.0)
	for i in range(4):
		_add_unit("minister", "조정 대신", Color("16a085"), false, false, 20.0)

	# 4) 제4제대: 혜경궁 홍씨 자궁가마 (옥교 가마 1 + 가마꾼 4 + 호위상궁 4 = 9기)
	_add_unit("hyegyeong_palanquin", "자궁가마(慈宮駕轝)", Color("c0392b"), false, true, 44.0)
	for i in range(4):
		_add_unit("palanquin_bearer", "가마꾼", Color("7f8c8d"), false, false, 18.0)
	for i in range(4):
		_add_unit("court_lady", "호위 상궁", Color("8e44ad"), false, false, 18.0)

	# 5) 제5제대: 정조 대왕 기마 행렬 (황금 갑주 정조 + 어기 2 + 근위 기병 4 = 7기)
	_add_unit("jeongjo_king", "정조 대왕 (황금 갑주)", Color("d4af37"), true, false, 32.0)
	_add_unit("royal_flag", "황룡 어기수", Color("f1c40f"), false, false, 20.0)
	_add_unit("royal_flag", "봉황 어기수", Color("e67e22"), false, false, 20.0)
	for i in range(4):
		_add_unit("royal_guard_horse", "장용영 근위 기병", Color("2980b9"), true, false, 28.0)

	# 6) 제6제대: 장용영 친위 정예 대열 (조총병 6 + 살수 4 + 기포병 2 = 12기)
	for i in range(6):
		_add_unit("posu", "장용영 포수(조총)", Color("34495e"), false, false, 20.0)
	for i in range(4):
		_add_unit("salsu", "장용영 살수(당파)", Color("2c3e50"), false, false, 20.0)
	for i in range(2):
		_add_unit("gipo", "장용영 기포병(불랑기포)", Color("7f8c8d"), false, false, 22.0)

func _add_unit(role: String, title: String, col: Color, is_horse: bool, is_palanquin: bool = false, spacing: float = 20.0) -> void:
	var init_p: Vector2 = waypoints[0] if not waypoints.is_empty() else Vector2.ZERO
	procession_units.append({
		"role": role,
		"title": title,
		"color": col,
		"is_horse": is_horse,
		"is_palanquin": is_palanquin,
		"spacing": spacing,
		"pos": init_p,
		"prev_pos": init_p,
		"dir": 0,
		"visible": true
	})

const TRAIL_LOOK := 40.0 # 행렬 방향을 볼 때 앞뒤로 보는 거리(약 1.5칸)

## 지금 방향(0 오른쪽 아래, 1 왼쪽 아래, 2 오른쪽 위, 3 왼쪽 위)이 흐름 v와 뚜렷이 어긋날 때만 바꾼다
func _stable_dir(cur: int, v: Vector2) -> int:
	var n := v.normalized()
	var sx: float = 1.0 if cur == 0 or cur == 2 else -1.0
	var sy: float = 1.0 if cur == 0 or cur == 1 else -1.0
	if n.x * sx > -0.3 and n.y * sy > -0.3:
		return cur
	return _compute_dir_from_vector(v)

func _compute_dir_from_vector(d: Vector2) -> int:
	if d.y >= 0.0:
		return 0 if d.x >= 0.0 else 1
	else:
		return 2 if d.x >= 0.0 else 3

## =========================================================================
## 4. 메인 프로세스 루프 (PROCESS_MODE_ALWAYS)
## =========================================================================
func _process(delta: float) -> void:
	if current_phase == Phase.NONE:
		return

	phase_timer += delta

	# 격쟁/상언 돌발 이벤트 FSM이 진행 중인 경우 (행렬 이동 일시 정지 및 액션 처리)
	if petition_fsm != PetitionFSM.NONE:
		_update_petition_fsm(delta)
		_update_spectators(delta)
		queue_redraw()
		return

	# 모달이 열려있을 때는 행렬 이동 멈춤 (도열 백성 모션은 유지)
	if _is_modal_open:
		_update_spectators(delta)
		queue_redraw()
		return

	match current_phase:
		Phase.ENTRY_PROCESSION:
			_update_entry_procession(delta)
		Phase.CEREMONY_BONGSU:
			_update_ceremony_bongsu(delta)
		Phase.CEREMONY_NAKNAM:
			_update_ceremony_naknam(delta)
		Phase.CEREMONY_SINPUNG:
			_update_ceremony_sinpung(delta)
		Phase.SEOJANGDAE_YAJO:
			_update_seojangdae_yajo(delta)
		Phase.YEONMUDAE_ARCHERY:
			_update_yeonmudae_archery(delta)
		Phase.BYEOLSI_EXAM:
			_update_byeolsi_exam(delta)
		Phase.EXIT_PROCESSION:
			_update_exit_procession(delta)
		Phase.FINISHED:
			pass

	queue_redraw()

## 1단계: 진입 능행차 행렬 이동 및 격쟁/상언 트리거 (Snake 리더-팔로워 추종)
func _update_entry_procession(delta: float) -> void:
	_update_spectators(delta)

	var total_len: float = _get_waypoints_total_length()

	# 격쟁(진행도 30%) 및 상언(진행도 70%) 돌발 인터랙션 발동 검사
	var progress_ratio: float = clampf(lead_distance_traveled / maxf(1.0, total_len), 0.0, 1.0)
	if progress_ratio >= 0.30 and not has_meta("g_triggered"):
		set_meta("g_triggered", true)
		_start_petition_fsm("gyeokjaeng")
		return
	elif progress_ratio >= 0.70 and not has_meta("s_triggered"):
		set_meta("s_triggered", true)
		_start_petition_fsm("sangeon")
		return

	lead_distance_traveled += MARCH_SPEED * delta

	# 선두 위치 산출
	var lead_pos: Vector2 = _get_point_at_distance(lead_distance_traveled)

	# 트레일 궤적 기록 (최신 위치를 앞에 삽입)
	trail_history.insert(0, lead_pos)
	if trail_history.size() > 1500:
		trail_history.resize(1500)

	# Snake 대열 유닛 추종 및 방향 계산
	_update_snake_units()

	# 신풍루 정문 앞마당 도착 판정
	if lead_distance_traveled >= total_len:
		current_phase = Phase.CEREMONY_BONGSU
		phase_timer = 0.0
		emit_signal("eulmyo_phase_changed", "CEREMONY_BONGSU", "제1의례: 봉수당 진찬연(奉壽堂 進饌宴)")
		if hud:
			hud._show_toast("어가 행렬이 화성행궁에 당도하여 봉수당 진찬연이 거행됩니다!", "👑")

## 2단계: 봉수당 진찬연 (혜경궁 홍씨 회갑연, 궁중 정재 여령 헌무)
func _update_ceremony_bongsu(delta: float) -> void:
	_update_spectators(delta)
	if phase_timer <= delta and camera and haenggung_pos.x >= 0:
		camera.focus_on_coordinate(_gw(float(haenggung_pos.x) + 0.5, float(haenggung_pos.y) + 0.5), true, 1.0)
	if phase_timer >= BONGSU_SEC: # 봉수당 진찬연 연출 시간
		sim.loyalty = mini(100, sim.loyalty + 15)
		sim.authority = mini(100, sim.authority + 10)
		current_phase = Phase.CEREMONY_NAKNAM
		phase_timer = 0.0
		emit_signal("eulmyo_phase_changed", "CEREMONY_NAKNAM", "제2의례: 낙남헌 양로연(洛南軒 養老宴)")
		if hud:
			hud._show_toast("봉수당 진찬연 성료(민심 +15, 왕권 +10). 낙남헌에서 70세 이상 노인들을 위한 양로연이 열립니다.", "🍶")

## 3단계: 낙남헌 양로연 (고을 노인 초청, 쌀과 비단 및 비둘기 구장 하사)
func _update_ceremony_naknam(delta: float) -> void:
	_update_spectators(delta)
	if phase_timer <= delta and camera and haenggung_pos.x >= 0:
		camera.focus_on_coordinate(_gw(float(haenggung_pos.x) - 1.5, float(haenggung_pos.y) + 0.5), true, 1.0)
	if phase_timer >= NAKNAM_SEC:
		sim.rice = maxi(0, sim.rice - 2000)
		sim.gold = maxi(0, sim.gold - 1000)
		sim.loyalty = mini(100, sim.loyalty + 20)
		current_phase = Phase.CEREMONY_SINPUNG
		phase_timer = 0.0
		emit_signal("eulmyo_phase_changed", "CEREMONY_SINPUNG", "제3의례: 신풍루 사미(新豊樓 賜米 - 진휼)")
		if hud:
			hud._show_toast("낙남헌 양로연 성료(민심 +20, 식량 -2천석, 금화 -1천냥). 70세 이상 노인들에게 쌀과 비단, 비둘기 지팡이를 하사하였습니다.", "🌾")

## 4단계: 신풍루 사미 (구휼미 1만석 방출, 민심 +15)
func _update_ceremony_sinpung(_delta: float) -> void:
	if phase_timer >= 6.0:
		sim.rice = maxi(0, sim.rice - 10000)
		sim.loyalty = mini(100, sim.loyalty + 15)
		current_phase = Phase.SEOJANGDAE_YAJO
		phase_timer = 0.0
		night_alpha = 0.0
		emit_signal("eulmyo_phase_changed", "SEOJANGDAE_YAJO", "제4행사: 서장대 사열과 야조(西將臺 城操·夜操)")
		if hud:
			hud._show_toast("신풍루 사미 완료(식량 -1만석, 민심 +15). 정조 대왕께서 서장대에 올라 장용영 군사를 사열하십니다!", "⚔️")

## 5단계: 서장대 야조 (야간 조명, 성곽 횃불, 신포 사격, 장용영 기동)
func _update_seojangdae_yajo(delta: float) -> void:
	if phase_timer <= delta:
		var s_world: Vector2 = _cell_to_world(float(seojangdae_pos.x), float(seojangdae_pos.y), 4.0)
		if camera:
			camera.focus_on_coordinate(s_world, true, 1.0)

	if phase_timer < REVIEW_SEC:
		return # 낮: 서장대 사열(성조) — _draw_seojangdae_review
	if phase_timer - REVIEW_SEC <= delta and hud:
		hud._show_toast("사열을 마치니 날이 저뭅니다. 서장대 야조(야간 군사 훈련)가 시작됩니다!", "🔥")
	night_alpha = minf(0.72, night_alpha + delta * 0.4) # 야간 어두움 페이드인
	_torch_flicker = sin(phase_timer * 10.0) * 0.15 + 0.85
	_cannon_flash = maxf(0.0, _cannon_flash - delta * 2.0)

	# 2초마다 5대 포루 신포 발사 섬광 연출
	if fmod(phase_timer, 2.0) < delta:
		_cannon_flash = 1.0

	if phase_timer >= YAJO_END:
		sim.military_power = mini(100, sim.military_power + 25)
		sim.defense_power = mini(1000, sim.defense_power + 100)
		phase_timer = 0.0

		# 연무대 완공 여부 확인 (완공 시 활쏘기 사열 진행, 미완공 시 건너뛰고 별시로 전이)
		if yeonmudae_pos.x >= 0 and grid != null and grid.in_bounds(yeonmudae_pos.x, yeonmudae_pos.y):
			current_phase = Phase.YEONMUDAE_ARCHERY
			emit_signal("eulmyo_phase_changed", "YEONMUDAE_ARCHERY", "제5행사: 연무대(동장대) 사열 및 정조 대왕 친림 활쏘기")
			if hud:
				hud._show_toast("서장대 야조 성료! 날이 밝아 연무대(동장대)에서 정조 대왕 친림 활쏘기가 거행됩니다.", "🏹")
		else:
			current_phase = Phase.BYEOLSI_EXAM
			emit_signal("eulmyo_phase_changed", "BYEOLSI_EXAM", "제5행사: 화성 별시(華城 別試 - 문무 과거시험)")
			if hud:
				hud._show_toast("서장대 야조 성료(국방력 +25, 방호력 +100). 이튿날 아침 화성 문무 별시가 거행됩니다.", "🏹")

## 5-B단계: 연무대 사열 및 정조 대왕 활쏘기 (득중정 어사도 고증 연출)
func _update_yeonmudae_archery(delta: float) -> void:
	if phase_timer <= delta:
		var ym_world: Vector2 = _cell_to_world(float(yeonmudae_pos.x), float(yeonmudae_pos.y), 2.0)
		if camera:
			camera.focus_on_coordinate(ym_world, true, 1.0)

	night_alpha = maxf(0.0, night_alpha - delta * 0.8) # 주간 밝기 회복

	if phase_timer >= ARCHERY_SEC:
		sim.military_power = mini(100, sim.military_power + 15)
		sim.authority = mini(100, sim.authority + 5)
		current_phase = Phase.BYEOLSI_EXAM
		phase_timer = 0.0
		emit_signal("eulmyo_phase_changed", "BYEOLSI_EXAM", "제6행사: 화성 별시(華城 別試 - 문무 과거시험)")
		if hud:
			hud._show_toast("연무대 사열 성료(국방력 +15, 왕권 +5). 득중정에서 4발 중 3발 명중! 낙남헌에서 화성 별시가 거행됩니다.", "🎯")

## 6단계: 화성 별시 (문무 과거시험, 어사화 수여)
func _update_byeolsi_exam(delta: float) -> void:
	night_alpha = maxf(0.0, night_alpha - delta * 0.6) # 주간 밝기 복귀
	if phase_timer <= delta and camera and haenggung_pos.x >= 0:
		camera.focus_on_coordinate(_gw(float(haenggung_pos.x) + 2.5, float(haenggung_pos.y) + 0.5), true, 1.0)
	if phase_timer >= BYEOLSI_SEC:
		sim.academic = mini(100, sim.academic + 15)
		current_phase = Phase.EXIT_PROCESSION
		phase_timer = 0.0
		_build_exit_waypoints() # 팔달문 퇴장 경로 산출
		lead_distance_traveled = 0.0
		trail_history.clear()
		for j in range(200):
			trail_history.append(waypoints[0])
		emit_signal("eulmyo_phase_changed", "EXIT_PROCESSION", "제6행사: 팔달문 출정 및 융릉 참배 퇴장")
		if hud:
			hud._show_toast("화성 별시 장원 급제(학문력 +15). 정조 대왕께서 팔달문을 거쳐 현륭원(융릉)으로 출정하십니다.", "🏇")

## 7단계: 팔달문 출정 및 퇴장 (도로망 엄격 추종: 행궁 -> 팔달문 -> 남쪽 융릉 방면)
func _build_exit_waypoints() -> void:
	_update_facility_positions()

	# 1. 행궁 앞마당 도로 타일 식별
	var sinpung_target: Vector2i = sinpungru_pos
	if grid != null and not grid.grid.is_empty():
		var road_pos: Vector2i = _find_closest_road_cell(grid, sinpungru_pos, 3)
		if road_pos.x >= 0:
			sinpung_target = road_pos

	# 2. 팔달문 위치 식별
	var paldal_target: Vector2i = paldal_pos
	if paldal_target.x < 0 and grid != null and grid.has_method("get_four_gates_positions"):
		var g_map: Dictionary = grid.get_four_gates_positions()
		paldal_target = g_map.get("paldal", Vector2i(26, 46))

	# 3. 남쪽 외곽 융릉(현륭원) 방면 도로 끝 타일
	var south_exit: Vector2i = Vector2i(paldal_target.x, mini(grid.size - 1, 60))
	if grid != null and not grid.grid.is_empty():
		for y in range(grid.size - 1, paldal_target.y, -1):
			if RoadNetwork.is_road_tile(grid.grid[y][paldal_target.x]):
				south_exit = Vector2i(paldal_target.x, y)
				break

	# 4. 도로망 기반 최단 경로 추출 (신풍루 -> 팔달문 -> 남쪽 외곽)
	var path_to_gate: Array[Vector2i] = _find_road_path_cells(sinpung_target, paldal_target)
	var path_to_south: Array[Vector2i] = _find_road_path_cells(paldal_target, south_exit)

	var full_cells: Array[Vector2i] = []
	for c: Vector2i in path_to_gate:
		full_cells.append(c)
	for i in range(1, path_to_south.size()):
		full_cells.append(path_to_south[i])

	_convert_cells_to_waypoints(full_cells)

func _update_snake_units() -> void:
	var cum_dist: float = 0.0
	for i: int in range(procession_units.size()):
		var u: Dictionary = procession_units[i]
		if i > 0:
			var prev_u: Dictionary = procession_units[i - 1]
			var gap: float = (float(prev_u.get("spacing", 20.0)) + float(u.get("spacing", 20.0))) * 0.5
			cum_dist += gap
		var u_pos: Vector2 = _get_point_on_trail(cum_dist)
		var prev_p: Vector2 = u.get("pos", u_pos)
		var delta_p: Vector2 = u_pos - prev_p
		if delta_p.length_squared() > 0.04:
			# PORT-TRACE [행차 도리도리]: 길이 격자 계단(오른쪽 아래·왼쪽 아래 번갈아)이라 칸마다 몸이 좌우로 돌았다 —
			# 앞뒤 TRAIL_LOOK만큼 떨어진 두 점으로 큰 흐름을 보고, 지금 방향과 뚜렷이 어긋날 때만 돈다
			var flow: Vector2 = _get_point_on_trail(maxf(0.0, cum_dist - TRAIL_LOOK)) - _get_point_on_trail(cum_dist + TRAIL_LOOK)
			if flow.length_squared() < 1.0:
				flow = delta_p
			u["dir"] = _stable_dir(int(u.get("dir", _compute_dir_from_vector(flow))), flow)
		u["prev_pos"] = prev_p
		u["pos"] = u_pos

func _update_exit_procession(delta: float) -> void:
	lead_distance_traveled += MARCH_SPEED * delta
	var total_len: float = _get_waypoints_total_length()
	var lead_pos: Vector2 = _get_point_at_distance(lead_distance_traveled)

	trail_history.insert(0, lead_pos)
	if trail_history.size() > 1500:
		trail_history.resize(1500)

	_update_snake_units()

	if lead_distance_traveled >= total_len:
		_complete_eulmyo_event()

## =========================================================================
## 5. 이벤트 완수 및 롤백 (_complete_eulmyo_event)
## =========================================================================
func _complete_eulmyo_event() -> void:
	current_phase = Phase.FINISHED
	sim.is_time_frozen = false
	sim.is_eulmyo_active = false
	sim.is_eulmyo_completed = true
	sim.authority = 100 # 왕권 100점 확정 보장

	# 백성 NPC 원래 일상 및 거점 롤백
	for b: Dictionary in _backup_agent_states:
		var a: Dictionary = b.get("agent", {})
		if not a.is_empty():
			a["state"] = b.get("orig_state", "idle")
			a["talk"] = b.get("orig_talk", "")
			a["is_bowing"] = false

	# 숨겼던 적대 개체 복구
	for p: Dictionary in _hidden_predators:
		p["visible"] = p.get("_eulmyo_orig_visible", true)

	# 연도 도열 백성 및 돌발 이벤트 엔티티 안전 정리
	crowd_spectators.clear()
	petition_fsm = PetitionFSM.NONE
	petition_actor.clear()
	king_speech_text = ""

	# 도적 및 맹수 스폰 억제 쿨타임 설정 (인게임 2년=8턴 평온 버프)
	sim.bandit_suppression_turns = 24 # 2년(24개월)
	sim.tiger_cooldown_turns = 24

	# 시간 속도 복구
	if time_manager:
		time_manager.set_speed(time_manager.SpeedMode.NORMAL)

	emit_signal("eulmyo_completed")
	_show_completion_modal()

	if hud:
		hud._show_toast("1795년 을묘원행 국책 대기록 완수! 실록에 길이 남을 태평성대를 이루었습니다.", "📜")

## =========================================================================
## 6. 트레일 추종 헬퍼 함수
## =========================================================================
func _get_waypoints_total_length() -> float:
	var total: float = 0.0
	for i in range(waypoints.size() - 1):
		total += waypoints[i].distance_to(waypoints[i + 1])
	return total

func _get_point_at_distance(dist: float) -> Vector2:
	if waypoints.is_empty(): return Vector2.ZERO
	if dist <= 0.0: return waypoints[0]

	var acc: float = 0.0
	for i in range(waypoints.size() - 1):
		var seg_len: float = waypoints[i].distance_to(waypoints[i + 1])
		if acc + seg_len >= dist:
			var remain: float = dist - acc
			var t: float = remain / maxf(0.001, seg_len)
			return waypoints[i].lerp(waypoints[i + 1], t)
		acc += seg_len
	return waypoints[-1]

func _get_point_on_trail(dist: float) -> Vector2:
	if trail_history.is_empty(): return Vector2.ZERO
	if dist <= 0.0: return trail_history[0]

	var acc: float = 0.0
	for i in range(trail_history.size() - 1):
		var seg: float = trail_history[i].distance_to(trail_history[i + 1])
		if acc + seg >= dist:
			var remain: float = dist - acc
			var t: float = remain / maxf(0.001, seg)
			return trail_history[i].lerp(trail_history[i + 1], t)
		acc += seg
	return trail_history[-1]

func _cell_to_world(x: float, y: float, elev: float = 0.0) -> Vector2:
	if city_layer != null and city_layer.has_method("cell_center"):
		return city_layer.cell_center(x, y, elev)
	# Fallback Isometric 공식
	return Vector2((x - y) * 32.0, (x + y) * 16.0 - elev * 12.0)

## =========================================================================
## 6-B. 연도(沿道) 백성 도열 시스템 (_build_spectator_crowd & _update_spectators)
## =========================================================================
func _build_spectator_crowd() -> void:
	crowd_spectators.clear()
	if waypoints.is_empty() or grid == null:
		return

	var candidate_map: Dictionary = {}
	var step_stride: int = maxi(1, int(float(waypoints.size()) / 40.0))

	for i in range(0, waypoints.size(), step_stride):
		var wp: Vector2 = waypoints[i]
		# Iso 공식 역산으로 그리드 좌표 근사
		var gx_f: float = (wp.x / 32.0 + wp.y / 16.0) * 0.5
		var gy_f: float = (wp.y / 16.0 - wp.x / 32.0) * 0.5
		var gx: int = roundi(gx_f)
		var gy: int = roundi(gy_f)

		# 주변 8방향 타일 중 도로가 아닌 안전한 지표면 탐색 (도로 양옆 도열)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var nx: int = gx + dx
				var ny: int = gy + dy
				var key: Vector2i = Vector2i(nx, ny)
				if candidate_map.has(key): continue
				if not grid.in_bounds(nx, ny): continue

				var cell: Dictionary = grid.grid[ny][nx]
				var b: String = str(cell.get("building", ""))
				var t: String = str(cell.get("terrain", ""))
				# 도로 타일이나 물, 성벽에는 도열 백성 배치 금지 (도로 통행 및 지형 무결성 보장)
				if RoadNetwork.is_road_tile(cell) or b in ["road", "gate", "bridge"] or grid.is_patrol_road(nx, ny):
					continue
				if t in ["water", "wall"] or b == "wall":
					continue

				candidate_map[key] = true
				if candidate_map.size() >= 48:
					break
			if candidate_map.size() >= 48:
				break
		if candidate_map.size() >= 48:
			break

	# 수집된 타일 위치에 도열 백성 인스턴스화
	var roles_pool: Array[String] = ["spectator_bow", "spectator_bow", "spectator_cheer"]
	for k: Vector2i in candidate_map.keys():
		var cell_w: Vector2 = _cell_to_world(float(k.x), float(k.y))
		var jitter: Vector2 = Vector2(randf_range(-4.0, 4.0), randf_range(-2.0, 2.0))
		var r_role: String = roles_pool[randi() % roles_pool.size()]
		var dir_to_center: int = 0 if cell_w.x < 0.0 else 1

		crowd_spectators.append({
			"pos": cell_w + jitter,
			"grid_pos": k,
			"role": r_role,
			"default_role": r_role,
			"dir": dir_to_center,
			"talk": "",
			"talk_timer": 0.0,
			"anim_frame": randi() % 2,
			"anim_timer": randf() * 2.0
		})

func _update_spectators(delta: float) -> void:
	if crowd_spectators.is_empty():
		return

	_spectator_talk_timer += delta

	# 정조 대왕과 자궁가마 위치
	var king_pos: Vector2 = Vector2.ZERO
	var palanquin_pos: Vector2 = Vector2.ZERO
	for u: Dictionary in procession_units:
		if u.get("role", "") == "jeongjo_king":
			king_pos = u.get("pos", Vector2.ZERO)
		elif u.get("role", "") == "hyegyeong_palanquin":
			palanquin_pos = u.get("pos", Vector2.ZERO)

	var lead_p: Vector2 = _get_point_at_distance(lead_distance_traveled)

	for sp: Dictionary in crowd_spectators:
		sp["anim_timer"] += delta
		sp["anim_frame"] = int(sp["anim_timer"] * 3.0) % 2

		if sp["talk_timer"] > 0.0:
			sp["talk_timer"] -= delta
			if sp["talk_timer"] <= 0.0:
				sp["talk"] = ""

		# 거리 기반 상태 전이: 정조나 가마가 55px 이내로 지나갈 때 부복/환호
		var p: Vector2 = sp.get("pos", Vector2.ZERO)
		var d_k: float = p.distance_to(king_pos) if king_pos != Vector2.ZERO else 999.0
		var d_pal: float = p.distance_to(palanquin_pos) if palanquin_pos != Vector2.ZERO else 999.0
		var d_lead: float = p.distance_to(lead_p)
		var min_d: float = minf(d_k, d_pal)

		if min_d < 50.0:
			# 정조 대왕/자궁가마 바로 앞: 50% 부복, 50% 환호
			var hash_val: int = int(p.x * 7.0 + p.y * 13.0)
			sp["role"] = "spectator_prostrate" if (hash_val % 2 == 0) else "spectator_cheer"
		elif d_lead < 90.0 or min_d < 90.0:
			# 행렬 접근 중: 공손히 읍(揖)
			sp["role"] = "spectator_bow"
		else:
			# 평시: 기본 상태
			sp["role"] = sp.get("default_role", "spectator_bow")

	# 2.2초마다 행렬 근처 도열 백성 중 1~2명이 환호 말풍선 발화
	if _spectator_talk_timer >= 2.2:
		_spectator_talk_timer = 0.0
		var cheers: Array[String] = [
			"상감마마 만세!", "자궁 마마 만수무강하소서!", "성군의 은덕이옵니다!", "태평성대로다!", "천세 천세 천천세!"
		]
		var candidates: Array[Dictionary] = []
		for sp: Dictionary in crowd_spectators:
			var p: Vector2 = sp.get("pos", Vector2.ZERO)
			if p.distance_to(lead_p) < 140.0:
				candidates.append(sp)

		if not candidates.is_empty():
			var pick: Dictionary = candidates[randi() % candidates.size()]
			pick["talk"] = cheers[randi() % cheers.size()]
			pick["talk_timer"] = 2.0

## =========================================================================
## 7. 격쟁 및 상언 돌발 이벤트 FSM 시스템
## =========================================================================
func _start_petition_fsm(cat: String) -> void:
	_pending_petition_cat = cat
	petition_fsm = PetitionFSM.RUNNING_IN
	petition_fsm_timer = 0.0
	_petition_auto_timer = 4.0 # 4초 후 자동 진행 가드

	var total_len: float = _get_waypoints_total_length()
	var lead_p: Vector2 = _get_point_at_distance(lead_distance_traveled)
	var next_p: Vector2 = _get_point_at_distance(minf(total_len, lead_distance_traveled + 30.0))
	var road_dir: Vector2 = (next_p - lead_p).normalized()
	if road_dir.length_squared() < 0.01:
		road_dir = Vector2(1, 0.5).normalized()

	# 도로 수직 측면 벡터 (옆길 스폰 위치)
	var perp: Vector2 = Vector2(-road_dir.y, road_dir.x)
	var target_pos: Vector2 = lead_p + road_dir * 18.0
	var side_spawn: Vector2 = target_pos + perp * 36.0

	var is_gyeokjaeng: bool = (cat == "gyeokjaeng")
	var r_role: String = "gyeokjaeng_citizen" if is_gyeokjaeng else "sangeon_scholar"
	var r_shout: String = "원통하옵니다! 임금님, 백성의 억울함을 굽어살펴 주옵소서!" if is_gyeokjaeng else "성상 전하, 만백성의 상소를 통촉하여 주옵소서!"

	petition_actor = {
		"role": r_role,
		"cat": cat,
		"pos": side_spawn,
		"spawn_pos": side_spawn,
		"target_pos": target_pos,
		"side_pos": side_spawn,
		"dir": _compute_dir_from_vector(target_pos - side_spawn),
		"shout": r_shout,
		"shout_timer": 3.5,
		"frame": 0
	}

func _update_petition_fsm(delta: float) -> void:
	petition_fsm_timer += delta

	if king_speech_timer > 0.0:
		king_speech_timer -= delta
		if king_speech_timer <= 0.0:
			king_speech_text = ""

	match petition_fsm:
		PetitionFSM.RUNNING_IN:
			# 0.8초 동안 길가에서 도로 중앙으로 달려나옴
			var t: float = clampf(petition_fsm_timer / 0.8, 0.0, 1.0)
			var sp: Vector2 = petition_actor.get("spawn_pos", Vector2.ZERO)
			var tp: Vector2 = petition_actor.get("target_pos", Vector2.ZERO)
			petition_actor["pos"] = sp.lerp(tp, t)
			petition_actor["frame"] = int(petition_fsm_timer * 6.0) % 2
			if petition_fsm_timer >= 0.8:
				petition_fsm = PetitionFSM.DIALOGUE
				petition_fsm_timer = 0.0
				petition_actor["pos"] = tp
				# 정조 대왕의 어명 대사 설정
				if petition_actor.get("cat", "") == "gyeokjaeng":
					king_speech_text = "어허, 징을 치는 자를 막지 말고 데려오너라. 백성의 억울함을 듣고자 함이다!"
				else:
					king_speech_text = "도승지는 저 백성의 상소문을 즉시 거두어 올리라!"
				king_speech_timer = 4.0
				# 모달 팝업 표시
				_trigger_random_petition(_pending_petition_cat)

		PetitionFSM.DIALOGUE:
			petition_actor["frame"] = int(petition_fsm_timer * 4.0) % 2
			_petition_auto_timer -= delta
			# 4초 경과 시 데드락 방지용 자동 윤허
			if _petition_auto_timer <= 0.0 and _is_modal_open:
				_resolve_petition(true)

		PetitionFSM.RESOLVING:
			petition_actor["frame"] = 0
			if petition_fsm_timer >= 0.8:
				petition_fsm = PetitionFSM.STEPPING_BACK
				petition_fsm_timer = 0.0

		PetitionFSM.STEPPING_BACK:
			# 도로 중앙에서 도로변으로 물러남
			var t: float = clampf(petition_fsm_timer / 0.8, 0.0, 1.0)
			var tp: Vector2 = petition_actor.get("target_pos", Vector2.ZERO)
			var sp: Vector2 = petition_actor.get("side_pos", Vector2.ZERO)
			petition_actor["pos"] = tp.lerp(sp, t)
			petition_actor["frame"] = int(petition_fsm_timer * 4.0) % 2
			if petition_fsm_timer >= 0.8:
				petition_actor["pos"] = sp
				petition_actor["role"] = "spectator_prostrate" # 길가에서 엎드려 큰절
				petition_fsm = PetitionFSM.NONE
				petition_fsm_timer = 0.0

func _trigger_random_petition(cat: String) -> void:
	var pool: Array[Dictionary] = petitions_gyeokjaeng if cat == "gyeokjaeng" else petitions_sangeon
	if pool.is_empty(): return
	var chosen: Dictionary = pool[randi() % pool.size()]
	_active_petition = chosen
	_is_modal_open = true
	emit_signal("petition_triggered", chosen)
	_show_petition_modal(chosen)

func _resolve_petition(accept: bool) -> void:
	if _active_petition.is_empty():
		_close_modal()
		petition_fsm = PetitionFSM.STEPPING_BACK
		petition_fsm_timer = 0.0
		return

	var eff: Dictionary = _active_petition.get("effects_accept" if accept else "effects_reject", {})
	sim.loyalty = clamp(sim.loyalty + int(eff.get("loyalty", 0)), 0, 100)
	sim.gold = max(0, sim.gold + int(eff.get("gold", 0)))
	sim.rice = max(0, sim.rice + int(eff.get("rice", 0)))
	sim.authority = clamp(sim.authority + int(eff.get("authority", 0)), 0, 100)
	sim.academic = clamp(sim.academic + int(eff.get("academic", 0)), 0, 100)
	sim.defense_power = clamp(sim.defense_power + int(eff.get("defense", 0)), 0, 1000)

	var feedback: String = str(_active_petition.get("accept_text" if accept else "reject_text", ""))
	if hud:
		hud._show_toast(feedback, "⚖️")

	if not petition_actor.is_empty():
		petition_actor["shout"] = "성은이 망극하옵니다! 성상 전하 만세!" if accept else "원통함을 굽어살펴 주옵소서..."
		petition_actor["shout_timer"] = 2.0

	_active_petition.clear()
	_close_modal()

	petition_fsm = PetitionFSM.RESOLVING
	petition_fsm_timer = 0.0

## =========================================================================
## 8. 모달 UI 및 야간 오버레이 구축
## =========================================================================
func _setup_ui_layer() -> void:
	if _ui_layer: return
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "RoyalProcessionUILayer"
	_ui_layer.layer = 120
	add_child(_ui_layer)

	# 야간 오버레이 (서장대 야조용)
	_night_rect = ColorRect.new()
	_night_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_rect.color = Color(0.12, 0.16, 0.32, 0.0) # 남청색 밤하늘 틴트
	_night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_night_rect)

	# 모달 다이얼로그 컨테이너
	_modal_panel = PanelContainer.new()
	_modal_panel.visible = false
	_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_modal_panel.custom_minimum_size = Vector2(560, 280)
	_modal_panel.offset_left = -280
	_modal_panel.offset_top = -140
	_modal_panel.offset_right = 280
	_modal_panel.offset_bottom = 140

	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7f3e9") # 조선 전통 한지 아이보리
	style.border_color = Color("2c3e50")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_modal_panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(_modal_panel)

func _show_petition_modal(pet: Dictionary) -> void:
	if not _modal_panel: return
	for child in _modal_panel.get_children():
		child.queue_free()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_modal_panel.add_child(vb)

	# 제목 줄
	var title_lbl := Label.new()
	title_lbl.text = "[%s] %s" % [pet.get("type", "탄원"), pet.get("title", "")]
	title_lbl.add_theme_color_override("font_color", Color("8b0000"))
	title_lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(title_lbl)

	# 상소자
	var pet_lbl := Label.new()
	pet_lbl.text = "상소인: %s" % pet.get("petitioner", "고을 백성")
	pet_lbl.add_theme_color_override("font_color", Color("2c3e50"))
	pet_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(pet_lbl)

	# 본문
	var desc_lbl := Label.new()
	desc_lbl.text = pet.get("desc", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color("1c1917"))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(desc_lbl)

	# 선택 버튼 HBox
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)

	var btn_accept := Button.new()
	btn_accept.text = "윤허(允許)한다"
	btn_accept.custom_minimum_size = Vector2(160, 36)
	btn_accept.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_accept.pressed.connect(func(): _resolve_petition(true))
	hb.add_child(btn_accept)

	var btn_reject := Button.new()
	btn_reject.text = "기각(棄却)한다"
	btn_reject.custom_minimum_size = Vector2(160, 36)
	btn_reject.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_reject.pressed.connect(func(): _resolve_petition(false))
	hb.add_child(btn_reject)

	_modal_panel.visible = true

func _show_completion_modal() -> void:
	if not _modal_panel: return
	for child in _modal_panel.get_children():
		child.queue_free()

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_modal_panel.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = "《원행을묘정리의궤》 대역사 완수!"
	title_lbl.add_theme_color_override("font_color", Color("8b0000"))
	title_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "1795년 을묘년, 정조 대왕과 혜경궁 홍씨의 8일간 화성 능행차가 성대히 완수되었습니다.\n봉수당 진찬연, 낙남헌 양로연, 신풍루 구휼 사미, 서장대 야조, 화성 별시를 무사히 거행하여\n조선의 왕권은 확고히 서고(왕권 100점 확정), 만백성이 태평성대를 노래합니다!"
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color("1c1917"))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(desc_lbl)

	var ok_btn := Button.new()
	ok_btn.text = "조선의 태평성대를 확인한다"
	ok_btn.custom_minimum_size = Vector2(220, 38)
	ok_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ok_btn.pressed.connect(_close_modal)
	vb.add_child(ok_btn)

	_modal_panel.visible = true

func _close_modal() -> void:
	if _modal_panel:
		_modal_panel.visible = false
	_is_modal_open = false

## =========================================================================
## 9. 2.5D 시각 연출 (_draw)
## =========================================================================
func _draw() -> void:
	if current_phase == Phase.NONE:
		return

	# 야간 오버레이 알파 동기화
	if _night_rect:
		_night_rect.color.a = night_alpha

	# A. 연도 도열 백성 렌더링 (뷰포트 컬링 및 앰비언트 말풍선)
	if current_phase in [Phase.ENTRY_PROCESSION, Phase.EXIT_PROCESSION]:
		for sp: Dictionary in crowd_spectators:
			var sp_pos: Vector2 = sp.get("pos", Vector2.ZERO)
			var sp_role: String = str(sp.get("role", "spectator_bow"))
			var sp_dir: int = int(sp.get("dir", 0))
			var sp_f: int = int(sp.get("anim_frame", 0))
			_draw_spectator(sp_pos, sp, sp_role, sp_dir, sp_f)

			# 환호 앰비언트 말풍선
			var talk: String = str(sp.get("talk", ""))
			if talk != "" and float(sp.get("talk_timer", 0.0)) > 0.0:
				_draw_ambient_speech_bubble(sp_pos + Vector2(0.0, -28.0), talk, false)

	# B. 진입 및 출정 행렬 유닛 렌더링
	if current_phase in [Phase.ENTRY_PROCESSION, Phase.EXIT_PROCESSION]:
		for u: Dictionary in procession_units:
			if not u.get("visible", true): continue
			var p: Vector2 = u.get("pos", Vector2.ZERO)
			_draw_procession_unit(p, u)

			# 정조 대왕 어명 말풍선
			if u.get("role", "") == "jeongjo_king" and king_speech_text != "" and king_speech_timer > 0.0:
				_draw_ambient_speech_bubble(p + Vector2(0.0, -38.0), king_speech_text, true)

	# C. 격쟁 / 상언 돌발 이벤트 액터 렌더링
	if petition_fsm != PetitionFSM.NONE and not petition_actor.is_empty():
		var act_pos: Vector2 = petition_actor.get("pos", Vector2.ZERO)
		var act_role: String = str(petition_actor.get("role", "gyeokjaeng_citizen"))
		var act_dir: int = int(petition_actor.get("dir", 0))
		var act_f: int = int(petition_actor.get("frame", 0))
		ProcessionUnitArt.draw_unit(self, act_pos, act_role, act_dir, act_f, 1.0, false)

		# 백성의 격쟁/상언 호소 말풍선
		var shout: String = str(petition_actor.get("shout", ""))
		if shout != "" and float(petition_actor.get("shout_timer", 0.0)) > 0.0:
			_draw_ambient_speech_bubble(act_pos + Vector2(0.0, -30.0), shout, false)

	# D. 각 의례별 행궁 및 서장대 시각 효과
	match current_phase:
		Phase.CEREMONY_BONGSU:
			_draw_bongsu_ceremony()
		Phase.CEREMONY_NAKNAM:
			_draw_naknam_ceremony()
		Phase.CEREMONY_SINPUNG:
			_draw_sinpung_ceremony()
		Phase.SEOJANGDAE_YAJO:
			if phase_timer < REVIEW_SEC:
				_draw_seojangdae_review()
			else:
				_draw_seojangdae_yajo_visuals()
		Phase.YEONMUDAE_ARCHERY:
			_draw_yeonmudae_archery_visuals()
		Phase.BYEOLSI_EXAM:
			_draw_byeolsi_visuals()

## PORT-TRACE [연도 백성 새 그림]: 막대 인형 같던 옛 그림 대신 거리 백성과 같은 흰옷 조합 백성(PeopleVariety) —
## 만세(들썩), 절(고개 끄덕), 부복(몸을 낮춤) — 바로 선 채로, 가까운 길(행렬)을 바라본다. 그림이 없으면 옛 그림.
func _draw_spectator(p: Vector2, sp: Dictionary, role: String, dir: int, f: int) -> void:
	var pv: Dictionary = sp.get("_pv", {})
	if pv.is_empty():
		pv = PeopleVariety.pick(int(p.x * 7.0 + p.y * 13.0))
		sp["_pv"] = pv
	# 행렬이 지나는 가장 가까운 길을 바라본다(게임 방향 0 +x, 1 +y, 2 -y, 3 -x)
	if not sp.has("_gd"):
		var gd := -1
		var k: Vector2i = sp.get("grid_pos", Vector2i(-1, -1))
		if grid != null and k.x >= 0:
			for r in range(1, 4):
				for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
					var q := k + d * r
					if gd < 0 and grid.in_bounds(q.x, q.y) and String(grid.grid[q.y][q.x].get("building", "")) in ["road", "gate"]:
						gd = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)].find(d)
				if gd >= 0:
					break
		sp["_gd"] = gd if gd >= 0 else (1 if dir == 0 else 0)
	var gdir: int = int(sp["_gd"])
	# 바로 선 채로: 만세는 들썩, 절은 고개를 숙였다 듦(끄덕), 부복은 몸을 낮춤 — 몸을 기울이지 않는다
	var sy := 1.0
	var hop := 0.0
	match role:
		"spectator_cheer":
			hop = 2.0 * float(f)
		"spectator_bow":
			sy = 0.9 if f == 1 else 1.0
		"spectator_prostrate":
			sy = 0.66
	draw_set_transform(p, 0.0, Vector2(1.0, sy))
	if not PeopleVariety.draw(self, Vector2(0, -hop), pv, gdir, 0):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ProcessionUnitArt.draw_unit(self, p, role, dir, f, 1.0, false)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
## PORT-TRACE [행렬 새 그림]: 걷는 사람 역할은 거리 NPC와 같은 그림(4방향 걸음)으로, 말·가마는 옛 그림 그대로
const UNIT_KIND := {"minister": "official", "chae_jegong": "named_chae_jegong", "court_lady": "lady", "palanquin_bearer": "bearer",
	"chwita": "pungmul", "posu": "posu", "salsu": "salsu", "royal_flag": "soldier"}
func _draw_procession_unit(p: Vector2, u: Dictionary) -> void:
	var role: String = str(u.get("role", "posu"))
	var dir: int = int(u.get("dir", 0))
	var anim_frame: int = int(lead_distance_traveled / 14.0) % 2
	# PORT-TRACE [행렬이 뒤를 봄]: 행렬 방향(_compute_dir_from_vector)은 0 = 화면 오른쪽 아래(격자 +x)인데, 말·가마 그림 시트는
	# 줄 0 = 앞-왼쪽. 그대로 넘겨 기병·어가가 좌우·앞뒤가 뒤바뀌어 보였다 → 그림 줄 번호로 바꿔 넘긴다(걷는 사람 NPC는 게임 방향 그대로)
	var art_dir: int = [1, 0, 3, 2][clampi(dir, 0, 3)]
	if UNIT_KIND.has(role) and not bool(u.get("is_horse", false)) and not NpcSprites.sheet_for(String(UNIT_KIND[role])).is_empty():
		NpcSprites.draw_kind(self, p, String(UNIT_KIND[role]), 0, false, clampi(dir, 0, 3), anim_frame)
		if role == "royal_flag": # 황룡·봉황 어기
			draw_line(p + Vector2(4, -6), p + Vector2(4, -40), Color("5c3a21"), 1.4)
			draw_rect(Rect2(p + Vector2(4, -40), Vector2(12, 10)), Color(u.get("color", Color("f1c40f"))))
			draw_rect(Rect2(p + Vector2(4, -40), Vector2(12, 10)), Color("3b2d22"), false, 0.7)
		return
	ProcessionUnitArt.draw_unit(self, p, role, art_dir, anim_frame, 1.0, false)

## =========================================================================
## PORT-TRACE [을묘원행 의례 장면 v2]: 행궁 배치표(CityLayer.HAENGGUNG_LAYOUT)의 트인 자리에서만 그린다.
## 행궁 기준 칸 a는 한가운데, 정문 신풍루는 격자 +x. 봉수당 = (a.x-1, a.y), 그 앞 마당 = x가 a.x인 한 줄(y: a.y-1 ~ a.y+1),
## 좌익문 = (a.x+1, a.y), 낙남헌 = (a.x-2, a.y), 낙남헌 양옆 후원 = (a.x-2, a.y-1)·(a.x-2, a.y+1).
## 서장대 사열은 서장대 묶음 바깥 앞 산자락(화면 아래쪽)에서. 지붕 위에 사람을 세우지 않는다.
## =========================================================================
const BONGSU_SEC := 24.0  # 봉수당 진찬연 길이(초)
const NAKNAM_SEC := 22.0  # 낙남헌 양로연
const REVIEW_SEC := 13.0  # 서장대 낮 사열(성조) — 이어서 밤 야조
const YAJO_END := 26.0    # 사열 + 야조 전체

## 격자 좌표(칸 단위, 칸 중심은 +0.5) → 화면 좌표(그 칸의 높이 반영)
func _gw(fx: float, fy: float) -> Vector2:
	var ix := clampi(int(floor(fx)), 0, grid.size - 1) if grid else 0
	var iy := clampi(int(floor(fy)), 0, grid.size - 1) if grid else 0
	var el: float = float(grid.grid[iy][ix].get("elevation", 1.0)) if grid else 1.0
	return _cell_to_world(fx, fy, el)

## 서 있는 정조 대왕(역사 인물 4방향 시트). dir: 0 = 화면 왼쪽 아래, 1 = 오른쪽 아래, 2 = 왼쪽 위, 3 = 오른쪽 위
func _draw_king_standing(p: Vector2, dir: int, step: int = 0) -> void:
	var tex: Texture2D = SpriteCacheManager.get_named_character_texture("named_jeongjo")
	if tex == null:
		ProcessionUnitArt.draw_unit(self, p, "minister", dir, 0, 1.0, false)
		return
	var s := 0.92
	var src := Rect2(float(step % 2) * 48.0, float(clampi(dir, 0, 3)) * 48.0, 48.0, 48.0)
	draw_texture_rect_region(tex, Rect2(p.x - 24.0 * s, p.y - 42.0 * s, 48.0 * s, 48.0 * s), src)

## 붉은 방석·주칠 상 같은 마당 위 평면(격자 사각형 → 마름모)
func _gpoly(x0: float, y0: float, x1: float, y1: float, col: Color, lift: float = 0.0) -> void:
	var up := Vector2(0, -lift)
	draw_colored_polygon(PackedVector2Array([_gw(x0, y0) + up, _gw(x1, y0) + up, _gw(x1, y1) + up, _gw(x0, y1) + up]), col)

## 고임상(높이 쌓은 음식 + 수파련 꽃)
func _feast_table(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 5.0, p.y - 4.0, 10.0, 4.0), Color("8b1a1a"))
	draw_rect(Rect2(p.x - 4.0, p.y - 9.0, 8.0, 5.0), Color("e8a23a"))
	draw_rect(Rect2(p.x - 3.0, p.y - 13.0, 6.0, 4.0), Color("d35400"))
	draw_circle(Vector2(p.x, p.y - 15.0), 2.4, Color("e74c3c"))
	draw_circle(Vector2(p.x, p.y - 17.0), 1.3, Color("fff176"))

## ------------------------------------------------------------------ 봉수당 진찬연
## 봉수당 대청 앞(월대)에 혜경궁 보좌, 정조가 술잔을 올리는 헌수(6~10초·14~18초), 마당 붉은 모전 위 여령 6인의 정재,
## 좌우 문무백관, 고임상 4기, 악공, 차일(기둥 + 반투명 천). 처음 4초는 백관이 좌익문 쪽에서 걸어 들어와 자리를 잡는다.
func _draw_bongsu_ceremony() -> void:
	if haenggung_pos.x < 0:
		return
	var ax := float(haenggung_pos.x)
	var ay := float(haenggung_pos.y) + 0.5 # 마당 가로 중심(칸 중심)
	var t := phase_timer
	var fr := int(t * 3.0) % 2
	# 마당 좌표: v = 봉수당 앞(0) → 좌익문 앞(1), u = 마당 가로(-1.5 ~ 1.5)
	var Y := func(v: float, u: float) -> Vector2: return _gw(ax + v, ay + u)
	# 1) 붉은 모전 + 고임상
	_gpoly(ax + 0.38, ay - 0.75, ax + 0.72, ay + 0.75, Color("9b111e"))
	for u: float in [-0.95, -0.55, 0.55, 0.95]:
		_feast_table(Y.call(0.24, u))
	# 2) 혜경궁 보좌(봉수당 월대) + 정조 헌수
	_gpoly(ax + 0.02, ay - 0.42, ax + 0.16, ay - 0.12, Color("c0392b"), 2.0)
	ProcessionUnitArt.draw_unit(self, Y.call(0.1, -0.27), "court_lady", 1, 0, 1.0, false)
	var offering := (t >= 6.0 and t < 10.0) or (t >= 14.0 and t < 18.0)
	var king_v := 0.2 if offering else 0.3
	var king_p: Vector2 = Y.call(king_v, 0.12)
	_draw_king_standing(king_p, 2, 0) # 봉수당(왼쪽 위)을 향함
	if offering:
		var lift := clampf(fmod(t, 4.0) / 1.5, 0.0, 1.0)
		draw_circle(king_p + Vector2(-7.0, -14.0 - lift * 4.0), 2.2, Color("d4af37")) # 금잔
	# 3) 여령 6인: 모전 위에서 두 줄로 돌며 한삼을 뿌림(봉수당 쪽을 바라봄)
	for i in range(6):
		var ang := t * 0.9 + float(i) * TAU / 6.0
		var dp: Vector2 = Y.call(0.55 + sin(ang) * 0.12, cos(ang) * 0.55)
		ProcessionUnitArt.draw_unit(self, dp, "court_dancer", 2 if cos(ang) < 0.0 else 3, fr, 1.0, false)
	# 4) 문무백관: 처음 4초 동안 좌익문 쪽에서 걸어 들어와 마당 양끝에 세 줄씩
	var enter := clampf(t / 4.0, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		for j in range(3):
			var goal := Vector2(0.28 + 0.2 * float(j), 1.28 * side)
			var start := Vector2(0.85, 0.9 * side)
			var mp := start.lerp(goal, enter)
			ProcessionUnitArt.draw_unit(self, Y.call(mp.x, mp.y), "minister", 3 if side > 0.0 else 2, fr if enter < 1.0 else 0, 1.0, false)
	# 5) 악공(마당 앞쪽 양끝)
	for side2: float in [-1.0, 1.0]:
		for k in range(2):
			var mpos: Vector2 = Y.call(0.78, side2 * (0.95 + 0.22 * float(k)))
			ProcessionUnitArt.draw_unit(self, mpos, "chwita", 3 if side2 > 0.0 else 2, fr, 1.0, false)
	# 6) 차일: 네 귀퉁이 붉은 기둥 + 반투명 흰 천(사람을 가리지 않게 옅게)
	var aw := 34.0
	var corners: Array[Vector2] = [Y.call(0.04, -1.45), Y.call(0.04, 1.45), Y.call(0.86, 1.45), Y.call(0.86, -1.45)]
	for c: Vector2 in corners:
		draw_line(c, c + Vector2(0, -aw), Color("8b0000"), 2.0)
	var top := PackedVector2Array()
	for c2: Vector2 in corners:
		top.append(c2 + Vector2(0, -aw))
	draw_colored_polygon(top, Color(0.97, 0.95, 0.9, 0.22))
	top.append(top[0])
	draw_polyline(top, Color(0.12, 0.25, 0.42, 0.6), 1.2)
	# 7) 꽃잎
	for f in range(10):
		var ph := fmod(t * 0.25 + float(f) * 0.1, 1.0)
		var fp: Vector2 = Y.call(0.2 + 0.6 * fmod(float(f) * 0.37, 1.0), -1.2 + 2.4 * fmod(float(f) * 0.61, 1.0))
		draw_circle(fp + Vector2(sin(t + float(f)) * 3.0, -40.0 + ph * 40.0), 1.4, Color(1.0, 0.75, 0.85, 0.9 * (1.0 - ph)))
	# 8) 말풍선
	if t >= 6.0 and t < 9.0:
		_draw_ambient_speech_bubble(king_p + Vector2(0, -40), "어마마마, 회갑을 감축드리옵니다. 만수무강하소서!", true)
	elif t >= 9.0 and t < 12.0:
		_draw_ambient_speech_bubble(Y.call(0.1, -0.27) + Vector2(0, -34), "주상의 효성이 지극하니 이 어미는 여한이 없소.", false)
	elif t >= 14.0 and t < 17.0:
		_draw_ambient_speech_bubble(Y.call(0.3, 1.28) + Vector2(0, -34), "자궁 마마께 두 번째 잔을 올리시오!", false)
	elif t >= 20.0:
		_draw_ambient_speech_bubble(Y.call(0.5, 0.0) + Vector2(0, -44), "천세! 천세! 천천세!", false)

## ------------------------------------------------------------------ 낙남헌 양로연
## 낙남헌 양옆 후원 두 칸에 노인 넷씩 상을 받고 앉음. 궁녀가 상을 나르고(후원 안에서만 오감), 8~16초엔 정조가
## 노인들 앞을 차례로 지나며 비둘기 지팡이(구장)를 하사, 하사품(쌀가마·비단) 더미, 마지막엔 잔을 들어 "천세!".
func _draw_naknam_ceremony() -> void:
	if haenggung_pos.x < 0:
		return
	var gx := float(haenggung_pos.x) - 2.0 # 낙남헌 줄(후원 칸의 x)
	var gys: Array[float] = [float(haenggung_pos.y) - 1.0, float(haenggung_pos.y) + 1.0] # 양옆 후원 칸의 y
	var t := phase_timer
	var fr := int(t * 3.0) % 2
	var seats: Array[Vector2] = [] # 노인 자리(격자)
	for gy: float in gys:
		_gpoly(gx + 0.12, gy + 0.12, gx + 0.88, gy + 0.88, Color(0.85, 0.78, 0.6, 0.85)) # 돗자리
		for k in range(4):
			var sp := Vector2(gx + 0.3 + 0.4 * float(k % 2), gy + 0.3 + 0.4 * floorf(float(k) / 2.0))
			seats.append(sp)
	# 상 + 노인 (상은 노인 앞=격자 +x 쪽)
	for i in seats.size():
		var sp2: Vector2 = seats[i]
		var tp := _gw(sp2.x + 0.12, sp2.y)
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -4), tp + Vector2(5, -1.5), tp + Vector2(0, 1), tp + Vector2(-5, -1.5)]), Color("c0392b"))
		draw_circle(tp + Vector2(-2, -1.5), 1.2, Color.WHITE)
		var cheers := t >= 17.0
		ProcessionUnitArt.draw_unit(self, _gw(sp2.x, sp2.y), "elder_citizen", 1 if i % 2 == 0 else 0, fr if cheers else 0, 1.0, false)
		if cheers:
			draw_circle(_gw(sp2.x, sp2.y) + Vector2(4, -22 - absf(sin(t * 3.0 + float(i))) * 3.0), 1.6, Color("f39c12")) # 잔
	# 궁녀: 후원마다 한 명이 상 사이를 오감
	for g in range(2):
		var gy2: float = gys[g]
		var cyc := fmod(t * 0.25 + float(g) * 0.5, 1.0)
		var k2 := cyc * 2.0 if cyc < 0.5 else (1.0 - cyc) * 2.0
		var lp := Vector2(gx + 0.15, gy2 + 0.1).lerp(Vector2(gx + 0.15, gy2 + 0.9), k2)
		ProcessionUnitArt.draw_unit(self, _gw(lp.x, lp.y), "court_lady", 0 if cyc < 0.5 else 3, fr, 1.0, false)
		draw_rect(Rect2(_gw(lp.x, lp.y) + Vector2(-3, -21), Vector2(6, 2)), Color("c0392b")) # 이고 가는 소반
	# 정조: 8~16초 동안 첫 후원의 노인들 앞을 차례로 지나며 구장 하사, 그 밖엔 낙남헌 옆에 섬
	var king_g := Vector2(gx + 0.95, gys[0] + 0.5)
	var giving := t >= 8.0 and t < 16.0
	var target := -1
	if giving:
		target = clampi(int((t - 8.0) / 2.0), 0, 3)
		var s3: Vector2 = seats[target]
		king_g = Vector2(s3.x + 0.32, s3.y + 0.05)
	var king_p := _gw(king_g.x, king_g.y)
	_draw_king_standing(king_p, 2 if giving else 0, int(t * 2.0) % 2 if giving else 0)
	if giving:
		var cane_to: Vector2 = _gw(seats[target].x, seats[target].y)
		draw_line(king_p + Vector2(-6, -12), cane_to + Vector2(4, -14), Color("8b5a2b"), 1.4) # 비둘기 지팡이
		draw_circle(cane_to + Vector2(4, -15), 1.6, Color("e8e8e8")) # 지팡이 머리 비둘기
	# 하사품: 둘째 후원 앞쪽 모서리에 쌀가마·비단
	var gp := _gw(gx + 0.9, gys[1] + 0.85)
	for r in range(3):
		draw_rect(Rect2(gp.x - 10.0 + float(r) * 7.0, gp.y - 5.0, 6.0, 4.0), Color("d4a359"))
	draw_rect(Rect2(gp.x - 6.0, gp.y - 9.0, 6.0, 3.0), Color("2980b9"))
	draw_rect(Rect2(gp.x + 1.0, gp.y - 9.0, 6.0, 3.0), Color("c0392b"))
	if t >= 2.0 and t < 6.0:
		_draw_ambient_speech_bubble(king_p + Vector2(0, -40), "노인을 공경함이 곧 효의 근본이니, 마음껏 드시오.", true)
	elif giving and fmod(t - 8.0, 2.0) < 1.6:
		var s4: Vector2 = seats[target]
		if target % 2 == 0:
			_draw_ambient_speech_bubble(king_p + Vector2(0, -40), "이 지팡이 짚고 오래오래 사시오.", true)
		else:
			_draw_ambient_speech_bubble(_gw(s4.x, s4.y) + Vector2(0, -32), "성은이 망극하옵니다!", false)
	elif t >= 17.0:
		_draw_ambient_speech_bubble(_gw(gx + 0.5, gys[1] + 0.5) + Vector2(0, -36), "천세! 천세! 상감마마 천세!", false)

## ------------------------------------------------------------------ 서장대 사열(성조)
## 서장대 앞(묶음 바깥 산자락)에 오방색 깃발을 든 다섯 진(陣)이 늘어서고, 정조가 서장대 앞 섬돌에서 사열.
## 4초마다 방진 → 일자진 → 원진으로 대열이 바뀌며(1초 동안 걸어서 이동), 9~12초 포수 일제 사격(총구 불꽃·연기).
func _seojangdae_frame() -> Array:
	var a := seojangdae_pos
	var n := 1
	if grid and grid.in_bounds(a.x, a.y):
		var tt: Dictionary = grid.grid[a.y][a.x]
		a = tt.get("site_anchor", a)
		if grid.in_bounds(a.x, a.y):
			var st: Variant = grid.grid[a.y][a.x].get("site_tiles", null)
			if st is Array and (st as Array).size() >= 4:
				n = 2
			elif grid.in_bounds(a.x + 1, a.y + 1) and String(grid.grid[a.y + 1][a.x + 1].get("building", "")).begins_with("seojangdae"):
				n = 2
	return [Vector2(float(a.x + n), float(a.y + n))] # 앞 모서리(격자)

func _formation_slot(kind: int, i: int) -> Vector2:
	# 진 하나 = 6명. 반환: (앞쪽 방향 거리, 옆 방향 거리) 칸 단위
	match kind:
		0: return Vector2(floorf(float(i) / 3.0) * 0.24, (float(i % 3) - 1.0) * 0.24)       # 방진 2x3
		1: return Vector2(0.12, (float(i) - 2.5) * 0.18)                           # 일자진
		_:
			var ang := TAU * float(i) / 6.0
			return Vector2(0.12 + cos(ang) * 0.22, sin(ang) * 0.22)               # 원진

func _draw_seojangdae_review() -> void:
	if seojangdae_pos.x < 0:
		return
	var F: Vector2 = _seojangdae_frame()[0]
	var t := phase_timer
	var fwd := Vector2(1, 1).normalized()  # 서장대에서 멀어지는 쪽(화면 아래)
	var side := Vector2(-1, 1).normalized() # 화면 가로
	var colors: Array[Color] = [Color("1f5fa8"), Color("c0392b"), Color("e8b820"), Color("f4f0e4"), Color("1c1c1c")]
	var roles: Array[String] = ["posu", "sasu", "salsu"]
	var kind := int(t / 4.0) % 3
	var prev := (kind + 2) % 3
	var blend := clampf(fmod(t, 4.0), 0.0, 1.0)
	var fire := t >= 9.0 and t < 12.0
	var fr := int(t * 4.0) % 2 if blend < 1.0 else 0
	var units: Array = []
	for b in range(5):
		var sb := (float(b) - 2.0) * 0.95
		var base := F + fwd * (1.35 + absf(float(b) - 2.0) * 0.25) + side * sb
		# 깃발
		var flag_g := base - fwd * 0.12 - side * 0.4
		units.append([_gw(flag_g.x, flag_g.y), "flag", colors[b]])
		for i in range(6):
			var s0 := _formation_slot(prev, i)
			var s1 := _formation_slot(kind, i)
			var sl := s0.lerp(s1, blend)
			var g := base + fwd * sl.x + side * sl.y
			units.append([_gw(g.x, g.y), roles[(b + i) % 3], b, i])
	units.sort_custom(func(p: Array, q: Array) -> bool: return (p[0] as Vector2).y < (q[0] as Vector2).y)
	for u: Array in units:
		var up: Vector2 = u[0]
		if String(u[1]) == "flag":
			draw_line(up, up + Vector2(0, -30), Color("3a2a1a"), 1.2)
			var wv := sin(t * 3.0 + up.x * 0.1) * 2.0
			draw_colored_polygon(PackedVector2Array([up + Vector2(0, -30), up + Vector2(11 + wv, -27), up + Vector2(0, -22)]), u[2])
			continue
		ProcessionUnitArt.draw_unit(self, up, String(u[1]), 2 if up.x > _gw(F.x, F.y).x else 3, fr, 1.0, true)
		if fire and String(u[1]) == "posu":
			var since := fmod(t - 9.0, 1.5)
			if since < 0.25:
				draw_circle(up + Vector2(-6, -16), 3.0, Color("ffd060"))
			draw_circle(up + Vector2(-8, -18 - since * 8.0), 3.0 + since * 4.0, Color(0.95, 0.95, 0.92, 0.6 * (1.0 - since / 1.5)))
	# 정조(서장대 앞 섬돌) + 깃발 신호수 + 북
	var kp := F - fwd * 0.12
	var king_p := _gw(kp.x, kp.y)
	_draw_king_standing(king_p, 1, 0)
	var sig := F - fwd * 0.05 + side * 0.45
	var sig_p := _gw(sig.x, sig.y)
	ProcessionUnitArt.draw_unit(self, sig_p, "royal_flag", 1, int(t * 2.0) % 2, 1.0, true)
	var dr := F - fwd * 0.05 - side * 0.45
	var drum_p := _gw(dr.x, dr.y)
	draw_circle(drum_p + Vector2(0, -6), 5.0, Color("8b1a1a"))
	draw_circle(drum_p + Vector2(0, -6), 3.2, Color("e8d8b0"))
	if absf(sin(t * 6.0)) > 0.9:
		draw_arc(drum_p + Vector2(0, -6), 8.0, 0.0, TAU, 16, Color(1, 1, 1, 0.5), 1.0)
	var cmds := ["북을 울려라! 오방진(五方陣)을 펼쳐라!", "일자진(一字陣)으로 늘어서라!", "원진(圓陣)으로 둘러싸라!"]
	if fire:
		_draw_ambient_speech_bubble(sig_p + Vector2(0, -40), "포수는 일제히 방포하라!", false)
	elif t >= 12.0:
		_draw_ambient_speech_bubble(king_p + Vector2(0, -42), "군율이 엄정하니 과인의 마음이 든든하도다!", true)
	elif fmod(t, 4.0) < 2.0:
		_draw_ambient_speech_bubble(sig_p + Vector2(0, -40), cmds[kind], false)

## 공용 한지 말풍선 드로잉 함수
func _draw_ambient_speech_bubble(p: Vector2, text: String, is_king: bool = false) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11 if not is_king else 12
	# PORT-TRACE [어명 말풍선]: 긴 어명이 한 줄로 화면을 가로질렀다 → 너비 220px에서 줄을 바꾼다
	var wrap_w := 220.0
	var one: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if one.x > wrap_w:
		var str_size_m: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, font_size)
		var pad_m := Vector2(6.0, 4.0)
		var rect_m := Rect2(p.x - (str_size_m.x + pad_m.x * 2.0) * 0.5, p.y - (str_size_m.y + pad_m.y * 2.0), str_size_m.x + pad_m.x * 2.0, str_size_m.y + pad_m.y * 2.0)
		var bg_m: Color = Color("fffdf5") if not is_king else Color("fff9d6")
		draw_rect(rect_m, bg_m, true)
		draw_rect(rect_m, Color("2c3e50") if not is_king else Color("8b0000"), false, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - 3.0, rect_m.end.y), Vector2(p.x + 3.0, rect_m.end.y), Vector2(p.x, rect_m.end.y + 4.0)]), bg_m)
		draw_multiline_string(font, rect_m.position + Vector2(pad_m.x, pad_m.y + font_size - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, font_size, -1, Color("1c1917") if not is_king else Color("8b0000"))
		return
	var str_size: Vector2 = one
	var pad: Vector2 = Vector2(6.0, 4.0)
	var bubble_w: float = str_size.x + pad.x * 2.0
	var bubble_h: float = str_size.y + pad.y * 2.0
	var bubble_rect := Rect2(p.x - bubble_w * 0.5, p.y - bubble_h, bubble_w, bubble_h)

	var bg_col: Color = Color("fffdf5") if not is_king else Color("fff9d6") # 왕은 은은한 황금빛 한지
	var border_col: Color = Color("2c3e50") if not is_king else Color("8b0000") # 왕은 주홍빛 테두리
	draw_rect(bubble_rect, bg_col, true)
	draw_rect(bubble_rect, border_col, false, 1.5)

	# 말풍선 꼬리표
	var tail: PackedVector2Array = [
		Vector2(p.x - 3.0, bubble_rect.position.y + bubble_rect.size.y),
		Vector2(p.x + 3.0, bubble_rect.position.y + bubble_rect.size.y),
		Vector2(p.x, bubble_rect.position.y + bubble_rect.size.y + 4.0)
	]
	draw_colored_polygon(tail, bg_col)

	var text_col: Color = Color("1c1917") if not is_king else Color("8b0000")
	var text_pos := Vector2(bubble_rect.position.x + pad.x, bubble_rect.position.y + pad.y + font_size - 2.0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

## 신풍루 사미(賑恤米) 연출: 화성능행도 병풍 <신풍루사미도(新豊樓賜米圖)> 완벽 고증
## - 신풍루 2층 문루 위 대형 정조 대왕(32x44)의 친림과 구휼 어명
## - 1층 마당 대형 쌀 뒤주 & 아전들의 됫박 배급 + 줄지어 선 백성들
func _draw_sinpung_ceremony() -> void:
	var target_sinpung: Vector2i = sinpungru_pos
	if target_sinpung.x < 0 or target_sinpung.y < 0:
		target_sinpung = haenggung_pos + Vector2i(3, 0)
	if target_sinpung.x < 0 or target_sinpung.y < 0:
		return

	var p: Vector2 = _cell_to_world(float(target_sinpung.x), float(target_sinpung.y))
	var anim_frame: int = int(phase_timer * 3.0) % 2

	# 1) 신풍루 2층 문루 난간 위 대형 정조 대왕 (진홍 철릭 융복 + 옥공작령 전립)
	ProcessionUnitArt.draw_unit(self, p + Vector2(0.0, -32.0), "jeongjo_king", 0, anim_frame, 1.0, true)

	# 2) 1층 마당 대형 쌀 뒤주 (원목 궤짝)
	var chest_rect := Rect2(p.x - 18.0, p.y - 4.0, 14.0, 10.0)
	draw_rect(chest_rect, Color("5c3a21"))
	draw_rect(Rect2(p.x - 17.0, p.y - 7.0, 12.0, 4.0), Color("d4a359")) # 수북이 쌓인 쌀
	# 관원(아전)이 됫박으로 쌀을 퍼서 나누어주는 모션
	ProcessionUnitArt.draw_unit(self, p + Vector2(-6.0, 2.0), "minister", 0, 0, 1.0, false)

	# 3) 줄지어 선 백성들 (쌀자루를 받아 든 백성들)
	ProcessionUnitArt.draw_unit(self, p + Vector2(10.0, 4.0), "spectator_bow", 1, anim_frame, 1.0, false)
	ProcessionUnitArt.draw_unit(self, p + Vector2(24.0, 8.0), "elder_citizen", 1, anim_frame, 1.0, false)

	# 4) 쌓인 쌀가마니 더미
	for i in range(5):
		var rx: float = p.x - 34.0 + float(i) * 6.0
		var ry: float = p.y + 6.0
		draw_rect(Rect2(rx, ry, 7.0, 5.0), Color("d4a359"))
		draw_line(Vector2(rx, ry + 2.0), Vector2(rx + 7.0, ry + 2.0), Color("8b5a2b"), 1.0)

## 서장대 야조 연출: 화성능행도 병풍 <서장대성조도(西將臺城操圖)> 완벽 고증
## - 서장대 2층 누각 위 대형 정조 대왕(32x44)의 등채 지휘
## - 성벽 앞마당 장용영 조총수 2열 교대 사격 (1열 무릎 쏴, 2열 서서 쏴 일제 사격) + 총구 화염 및 백색 연막
## - 장용영 기포병(불랑기포) 굉음 포격 화염 + 서장대/성곽 횃불 일렁임 + 밤하늘 오색 신포(신호탄) 섬광
func _draw_seojangdae_yajo_visuals() -> void:
	if seojangdae_pos.x < 0 or seojangdae_pos.y < 0:
		return
	var p: Vector2 = _cell_to_world(float(seojangdae_pos.x), float(seojangdae_pos.y), 4.0)
	var anim_frame: int = int(phase_timer * 4.0) % 2

	# 1) 서장대 2층 누각 위 대형 정조 대왕 (32x44 규격, 진홍 철릭 융복 + 옥공작령 + 등채 지휘)
	ProcessionUnitArt.draw_unit(self, p + Vector2(0.0, -28.0), "jeongjo_king", 0, anim_frame, 1.0, true)

	# 2) 서장대 앞마당 장용영 조총수 4인: 2열 교대 사격 (1열 무릎 쏴 frame=0, 2열 서서 쏴 frame=1)
	for i in range(4):
		var ox: float = -28.0 + float(i) * 18.0
		var posu_frame: int = 0 if (i % 2 == anim_frame) else 1
		ProcessionUnitArt.draw_unit(self, p + Vector2(ox, 8.0), "posu", 0, posu_frame, 1.0, true)

	# 3) 장용영 기포병 (불랑기포 포병) 배치 및 포격 화염
	ProcessionUnitArt.draw_unit(self, p + Vector2(-46.0, 4.0), "gipo", 0, anim_frame, 1.0, true)

	# 4) 성벽 살수 및 사수 도열
	ProcessionUnitArt.draw_unit(self, p + Vector2(-36.0, -6.0), "salsu", 0, anim_frame, 1.0, true)
	ProcessionUnitArt.draw_unit(self, p + Vector2(36.0, -6.0), "sasu", 1, anim_frame, 1.0, true)

	# 5) 서장대 횃불 (붉고 주황빛 타오름)
	draw_circle(p + Vector2(-16.0, -24.0), 5.0 * _torch_flicker, Color("ff4500"))
	draw_circle(p + Vector2(16.0, -24.0), 5.0 * _torch_flicker, Color("ff4500"))
	draw_circle(p + Vector2(-16.0, -24.0), 2.5 * _torch_flicker, Color("fff176"))
	draw_circle(p + Vector2(16.0, -24.0), 2.5 * _torch_flicker, Color("fff176"))

	# 6) 성곽 횃불들
	for i in range(6):
		var fx: float = p.x - 44.0 + float(i) * 18.0
		var fy: float = p.y - 8.0
		draw_circle(Vector2(fx, fy), 3.5 * _torch_flicker, Color("ffa500"))

	# 7) 오색 신포(신호탄 로켓) 궤적 및 밤하늘 불꽃 섬광
	if _cannon_flash > 0.05:
		# 대포 발사 섬광
		draw_circle(p + Vector2(-40.0, 2.0), 25.0 * _cannon_flash, Color(1.0, 1.0, 0.8, _cannon_flash * 0.9))
		draw_circle(p + Vector2(-35.0, -4.0), 16.0, Color(0.95, 0.95, 0.95, _cannon_flash * 0.6))
		# 밤하늘로 솟구치는 오색 신포 불꽃
		var rocket_y: float = -40.0 - (1.0 - _cannon_flash) * 35.0
		draw_line(p + Vector2(0.0, -20.0), p + Vector2(8.0, rocket_y), Color("fff275"), 2.0)
		draw_circle(p + Vector2(8.0, rocket_y), 8.0 * _cannon_flash, Color("ff3838"))
		draw_circle(p + Vector2(8.0, rocket_y), 4.0 * _cannon_flash, Color("ffffff"))

## ------------------------------------------------------------------ 연무대 친림 활쏘기
## PORT-TRACE [연무대 활쏘기 v2]: 연무대 5x5는 성벽 쪽(wall_dir)에 따라 돌아가므로 CityLayer.ym_pt(가로 r, 성벽 쪽 f)로만 자리를 잡는다
## (일상 장면과 같은 좌표계: 사대 f≈1.7, 과녁은 성 밖 f=6.2). 4발(1.5·5·8.5·12초에 시위를 놓음, 셋째만 빗나감),
## 화살 포물선 0.5초, 관원 "관중이오!", 연병장에 늘어선 군사들이 사대 쪽을 지켜보고 마지막에 "천세!".
const ARCHERY_SEC := 18.0
const BYEOLSI_SEC := 18.0
const SHOT_HITS := [true, true, false, true]

func _ym_info() -> Dictionary:
	if grid == null or not grid.in_bounds(yeonmudae_pos.x, yeonmudae_pos.y):
		return {}
	var tt: Dictionary = grid.grid[yeonmudae_pos.y][yeonmudae_pos.x]
	if tt.has("ym5"):
		return tt["ym5"]
	var a: Vector2i = tt.get("site_anchor", yeonmudae_pos)
	if grid.in_bounds(a.x, a.y):
		return grid.grid[a.y][a.x].get("ym5", {})
	return {}

## 화면에서 from → to 쪽을 바라보는 스프라이트 행(0 왼쪽 아래, 1 오른쪽 아래, 2 왼쪽 위, 3 오른쪽 위)
func _face_row(from: Vector2, to: Vector2) -> int:
	var d := to - from
	if d.y >= 0.0:
		return 1 if d.x >= 0.0 else 0
	return 3 if d.x >= 0.0 else 2

func _draw_yeonmudae_archery_visuals() -> void:
	var info := _ym_info()
	if info.is_empty() or city_layer == null:
		return
	var t := phase_timer
	var P := func(r: float, f: float) -> Vector2: return city_layer.ym_pt(info, r, f)
	var king_p: Vector2 = P.call(0.0, 1.7)
	var target_p: Vector2 = P.call(0.0, 6.2)
	var face := _face_row(king_p, target_p)
	# 1) 연병장 군사: 두 줄로 서서 사대 쪽을 지켜봄
	for row in range(2):
		for i in range(5):
			var sp: Vector2 = P.call(-1.6 + 0.8 * float(i), -0.6 + 0.5 * float(row))
			ProcessionUnitArt.draw_unit(self, sp, ["posu", "salsu", "sasu"][(i + row) % 3], _face_row(sp, king_p), 0, 1.0, true)
	# 2) 사대 좌우 관원·사수
	for side: float in [-1.0, 1.0]:
		var mp: Vector2 = P.call(0.8 * side, 1.4)
		ProcessionUnitArt.draw_unit(self, mp, "minister", _face_row(mp, target_p), 0, 1.0, false)
		var sp2: Vector2 = P.call(1.45 * side, 1.9)
		ProcessionUnitArt.draw_unit(self, sp2, "sasu", face, 0, 1.0, true)
	# 3) 정조 활쏘기: 쏠 차례(k)와 그 안의 시간(lt)
	var k := clampi(int((t - 1.5) / 3.5), 0, 3)
	var lt := t - 1.5 - 3.5 * float(k)
	var frame := 0
	if t >= 14.0:
		frame = 3
	elif t >= 1.5:
		if lt < 0.6:
			frame = 0
		elif lt < 1.2:
			frame = 1
		elif lt < 1.5:
			frame = 2
		else:
			frame = 3
	ProcessionUnitArt.draw_unit(self, king_p, "jeongjo_archery", face, frame, 1.0, true)
	# 4) 화살 비행(시위를 놓은 뒤 0.5초)
	var hits_so_far := 0
	for s in range(4):
		var land_t := 1.5 + 3.5 * float(s) + 1.7
		if t >= land_t and bool(SHOT_HITS[s]):
			hits_so_far += 1
	if t >= 1.5 and t < 14.0 and lt >= 1.2 and lt < 1.7:
		var u := (lt - 1.2) / 0.5
		var aim: Vector2 = target_p + Vector2(0, -14) + (Vector2.ZERO if bool(SHOT_HITS[k]) else Vector2(14, -6))
		var cur: Vector2 = (king_p + Vector2(0, -20)).lerp(aim, u)
		cur.y -= sin(u * PI) * 22.0
		var dirv := (aim - king_p).normalized()
		draw_line(cur - dirv * 5.0, cur + dirv * 4.0, Color("8b5a2b"), 2.0)
		draw_circle(cur + dirv * 4.0, 1.3, Color("1c1917"))
	# 5) 과녁(꽂힌 화살 수) + 명중 섬광
	ProcessionUnitArt.draw_unit(self, target_p, "archery_target", 0, hits_so_far, 1.0, true)
	if t >= 1.5 and t < 14.0 and lt >= 1.7 and lt < 2.0 and bool(SHOT_HITS[k]):
		draw_circle(target_p + Vector2(0, -14), 5.5, Color("fff9d6"))
		draw_circle(target_p + Vector2(0, -14), 3.0, Color("d4af37"))
	# 6) 말풍선
	var judge: Vector2 = P.call(0.8, 1.4)
	if t < 1.5:
		_draw_ambient_speech_bubble(judge + Vector2(0, -34), "전하께서 친히 활을 잡으시오! 모두 예를 갖추라!", false)
	elif t < 14.0 and lt >= 1.7 and lt < 3.2:
		_draw_ambient_speech_bubble(judge + Vector2(0, -34), "관중(貫中)이오!" if bool(SHOT_HITS[k]) else "아깝사옵니다, 살짝 비켜 갔사옵니다!", false)
	elif t >= 14.0 and t < 16.5:
		_draw_ambient_speech_bubble(king_p + Vector2(0, -42), "네 발에 세 발이라, 과인의 활 솜씨가 아직 녹슬지 않았구나!", true)
	elif t >= 16.5:
		_draw_ambient_speech_bubble(P.call(0.0, -0.4) + Vector2(0, -34), "천세! 천세! 천천세!", false)

## ------------------------------------------------------------------ 화성 별시(낙남헌 방방 → 행궁 앞뜰)
## PORT-TRACE [별시 v2]: 신풍루와 좌익문 사이 앞뜰(x: a.x+2 ~ a.x+3)에서만. 정조가 좌익문 앞 차일 아래 서고, 유생 여덟이 두 줄로
## 엎드려 답안을 쓰며(0~8초), 시관이 줄을 따라 시권을 거두고(8~12초), 장원을 부르면(12~15초) 장원이 정조 앞으로 걸어가
## 어사화를 받는다(15~18초).
func _draw_byeolsi_visuals() -> void:
	if haenggung_pos.x < 0:
		return
	var ax := float(haenggung_pos.x)
	var cy := float(haenggung_pos.y) + 0.5
	var t := phase_timer
	var fr := int(t * 3.0) % 2
	var king_p := _gw(ax + 2.12, cy)
	# 1) 왕의 차일(파란 천, 옅게) + 기둥
	var aw := 30.0
	var cs: Array[Vector2] = [_gw(ax + 2.02, cy - 0.35), _gw(ax + 2.02, cy + 0.35), _gw(ax + 2.3, cy + 0.35), _gw(ax + 2.3, cy - 0.35)]
	for c: Vector2 in cs:
		draw_line(c, c + Vector2(0, -aw), Color("5c3a21"), 1.6)
	# 2) 유생 여덟(두 줄), 앞에 시권
	var seats: Array[Vector2] = []
	for row in range(2):
		for i in range(4):
			seats.append(Vector2(ax + 2.5 + 0.28 * float(row), cy + (-0.85 + 0.57 * float(i))))
	var winner := 1
	for i2 in range(seats.size()):
		var sg: Vector2 = seats[i2]
		if i2 == winner and t >= 15.0:
			continue # 장원은 앞으로 걸어 나감
		var sp := _gw(sg.x, sg.y)
		var paper := _gw(sg.x - 0.12, sg.y)
		var collected := t >= 8.0 + float(i2 % 4) * 1.0
		if not collected:
			draw_rect(Rect2(paper.x - 4.0, paper.y - 3.0, 8.0, 4.0), Color("f4f0e4"))
			if t < 8.0 and int(t * 4.0 + float(i2)) % 3 == 0:
				draw_line(paper + Vector2(-2, -2), paper + Vector2(2, -1), Color("1c1917"), 1.0) # 붓질
		ProcessionUnitArt.draw_unit(self, sp, "sangeon_scholar", 2, fr if t < 8.0 else 0, 1.0, false)
	# 3) 시관: 8~12초 줄을 따라 걸으며 시권을 거둠, 그 밖엔 왕 옆에 섬
	var off_p := _gw(ax + 2.25, cy + 0.75)
	if t >= 8.0 and t < 12.0:
		var g := Vector2(ax + 2.38, cy - 0.85).lerp(Vector2(ax + 2.38, cy + 0.85), (t - 8.0) / 4.0)
		off_p = _gw(g.x, g.y)
		ProcessionUnitArt.draw_unit(self, off_p, "minister", 0, int(t * 4.0) % 2, 1.0, false)
		draw_rect(Rect2(off_p.x + 3.0, off_p.y - 16.0, 5.0, 4.0), Color("f4f0e4")) # 거둔 시권 뭉치
	else:
		ProcessionUnitArt.draw_unit(self, off_p, "minister", 1, 0, 1.0, false)
	# 4) 정조(차일 아래, 유생 쪽을 바라봄)
	_draw_king_standing(king_p, 1, 0)
	# 5) 장원: 정조 앞으로 걸어가 어사화를 받음
	if t >= 15.0:
		var wg: Vector2 = seats[winner]
		var go := Vector2(wg.x, wg.y).lerp(Vector2(ax + 2.38, cy), clampf((t - 15.0) / 1.5, 0.0, 1.0))
		var wp := _gw(go.x, go.y)
		ProcessionUnitArt.draw_unit(self, wp, "sangeon_scholar", 2, int(t * 4.0) % 2 if t < 16.5 else 0, 1.0, false)
		if t >= 16.5: # 어사화: 모자 뒤로 늘어진 꽃가지
			for k in range(5):
				draw_circle(wp + Vector2(-3.0 - float(k) * 2.0, -24.0 + float(k) * 3.0), 1.4, [Color("e74c3c"), Color("f1c40f"), Color("9b59b6")][k % 3])
	# 6) 차일 천(사람 위로 옅게)
	var top := PackedVector2Array()
	for c2: Vector2 in cs:
		top.append(c2 + Vector2(0, -aw))
	draw_colored_polygon(top, Color(0.16, 0.5, 0.73, 0.3))
	# 7) 말풍선
	if t >= 1.0 and t < 4.5:
		_draw_ambient_speech_bubble(off_p + Vector2(0, -34), "시제(試題)는 '화성을 쌓은 뜻을 논하라'이니라!", false)
	elif t >= 12.0 and t < 15.0:
		_draw_ambient_speech_bubble(off_p + Vector2(0, -34), "장원 급제는 수원 고을 유생이로다! 앞으로 나오라!", false)
	elif t >= 16.5:
		_draw_ambient_speech_bubble(king_p + Vector2(0, -40), "그대의 학문을 백성을 위해 쓰라. 어사화를 내리노라.", true)
