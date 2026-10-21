extends RefCounted
class_name AcademyQuizManager

## [수원향교·서원·서당 학문 강독 퀴즈 매니저]
## 1. 시설별 퀴즈 주제 및 어투:
##    - 수원향교(hyanggyo): 실학 관련 퀴즈 (근엄한 경어체, 교수/대사성 아바타, 60문제 풀)
##    - 서원(seowon): 수원화성 관련 퀴즈 (친절한 선생님 말투, 훈도 아바타, 60문제 풀)
##    - 서당(seodang): 세시풍속 관련 퀴즈 (아랫것들에게 호통치는 훈장님 말투, 훈장 아바타, 60문제 풀)
## 2. 쿨타임: 1년(인게임 1년 = 12턴)마다 1회 응시 가능
## 3. 채점 규칙:
##    - 한번에 3문제 출제
##    - 3개 정답 (3/3): 학문력 +2 가산
##    - 2개 정답 (2/3): 학문력 +1 가산
##    - 1개 정답 (1/3): 0점 (가산 없음)
##    - 0개 정답 (0/3): 학문력 -1 감점

static var instance: AcademyQuizManager = null

var last_quiz_years: Dictionary = {
	"hyanggyo": -1,
	"seowon": -1,
	"seodang": -1
}

# 1문제 정답 시 가산 점수 (기본 0점, 사용자 지시문 8점 대응 슬롯)
var score_1_correct: int = 0

func _init() -> void:
	instance = self

static func get_instance() -> AcademyQuizManager:
	if instance == null:
		instance = AcademyQuizManager.new()
	return instance

## 1년 쿨타임 검사 (현재 연도 > 마지막 응시 연도)
func can_take_quiz(facility_type: String, current_year: int) -> bool:
	var last_y: int = int(last_quiz_years.get(facility_type, -1))
	return current_year > last_y

## 마지막 응시 연도 조회
func get_last_quiz_year(facility_type: String) -> int:
	return int(last_quiz_years.get(facility_type, -1))

## 퀴즈 완료 기록 갱신
func record_quiz_completed(facility_type: String, current_year: int) -> void:
	last_quiz_years[facility_type] = current_year

## 점수(학문력 변동치) 산출
func calculate_score_delta(correct_count: int) -> int:
	match correct_count:
		3: return 2
		2: return 1
		1: return score_1_correct # 0점 가산 (변동 없음)
		_: return -1

## 시설별 전체 문제 풀 조회 (각 60문항 이상)
static func get_question_pool(facility_type: String) -> Array[Dictionary]:
	match facility_type:
		"hyanggyo":
			return AcademyQuizDatabase.get_hyanggyo_questions()
		"seowon":
			return AcademyQuizDatabase.get_seowon_questions()
		"seodang":
			return AcademyQuizDatabase.get_seodang_questions()
		_:
			return []

## 퀴즈 데이터베이스 맵
static var QUIZ_DATA: Dictionary = _build_quiz_data()

static func _build_quiz_data() -> Dictionary:
	return {
		"hyanggyo": {
			"title": "수원향교 대성전 [실학 강독 시험]",
			"speaker_name": "수원향교 대사성",
			"speaker_title": "향교 교수",
			"portrait_key": "scholar",
			"speech_greeting": "어서 오시오. 이곳은 성현의 도를 기리고 백성을 교화하는 수원향교요. 오늘 실용적인 학문, 실학(實學)에 대한 경의 식견을 시험해 보겠소.",
			"speech_correct": "훌륭하오! 실사구시(實事求是)의 정신을 깊이 새겼구려!",
			"speech_wrong": "틀렸소! 책상물림에 머물지 말고 실질적인 지혜를 더 닦아야 하오.",
			"questions": AcademyQuizDatabase.get_hyanggyo_questions(),
			"results": {
				3: "만점이오! 실사구시의 진리를 온전히 통달하여 조선의 미래를 밝힐 훌륭한 학자요! (학문력 +2)",
				2: "우수한 성적이오. 배움의 도리에 정성을 다했음을 칭찬하오. (학문력 +1)",
				1: "기본 식견은 있으나 아직 배움이 부족하오. 더 정진하시오. (학문력 변동 없음)",
				0: "실망스럽소! 학문의 도를 이토록 소홀히 하다니, 깊이 반성하고 서책을 다시 펴시오! (학문력 -1)"
			}
		},
		"seowon": {
			"title": "화민서원 강당 [수원화성 역사 퀴즈]",
			"speaker_name": "화민서원 훈도",
			"speaker_title": "서원 선생님",
			"portrait_key": "seowon",
			"speech_greeting": "안녕! 우리 고장의 자랑스러운 보물, 수원화성에 대해 함께 배워볼까요? 어렵지 않으니 차근차근 풀어보세요!",
			"speech_correct": "와, 정답이에요! 수원화성의 역사를 아주 꼼꼼하게 기억하고 있군요!",
			"speech_wrong": "아쉽지만 틀렸어요. 다음 문제에선 꼭 맞출 수 있을 거예요, 힘내요!",
			"questions": AcademyQuizDatabase.get_seowon_questions(),
			"results": {
				3: "모두 맞췄어요! 수원화성 역사 박사님이 탄생했네요, 참 잘했어요! (학문력 +2)",
				2: "두 문제나 맞췄어요! 조금만 더 공부하면 완벽한 역사 박사님이 될 거예요! (학문력 +1)",
				1: "한 문제를 맞췄네요! 다음 해에는 조금 더 힘내서 풀어봐요, 파이팅! (학문력 변동 없음)",
				0: "이번엔 아쉽게 다 틀렸지만, 선생님과 함께 다시 복습해보면 금방 잘할 수 있어요! (학문력 -1)"
			}
		},
		"seodang": {
			"title": "팔달서당 훈장실 [세시풍속 문답 퀴즈]",
			"speaker_name": "팔달서당 훈장님",
			"speaker_title": "서당 훈장",
			"portrait_key": "seodang",
			"speech_greeting": "에헴! 학동 놈들아, 귀를 쫑긋 세우고 바른 자세로 앉거라! 오늘 훈장님이 우리네 세시풍속에 대해 물을 테니 똑똑히 답해야 할 게야!",
			"speech_correct": "허허! 제법이로구나! 종아리는 면했으니 기특하다, 껄껄!",
			"speech_wrong": "어허, 이런 돌머리 녀석들! 그게 정답이 아니란 걸 모른단 말이냐!",
			"questions": AcademyQuizDatabase.get_seodang_questions(),
			"results": {
				3: "허허허! 삼문 삼답을 모두 맞히다니, 훈장 눈에 눈물이 다 나는구나! 기특하다 기특해! (학문력 +2)",
				2: "음! 두 문제는 건졌으니 오늘 회초리는 넣어두겠다. 다음엔 만점을 맞도록 하거라! (학문력 +1)",
				1: "겨우 하나 맞히고 희희낙락하느냐? 종아리 한 대만 맞고 돌아가 서책을 백 번 소리 내어 읽어라! (학문력 변동 없음)",
				0: "어허! 셋 다 틀리다니, 네 놈들을 학동이라 부를 수도 없구나! 썩 종아리를 걷어올려라! (학문력 -1)"
			}
		}
	}

## 3문제 무작위 세션 추출 (60문항 풀에서 3문항 셔플 추출 및 보기 셔플)
func generate_quiz_session(facility_type: String) -> Array[Dictionary]:
	var q_pool: Array[Dictionary] = get_question_pool(facility_type)
	if q_pool.is_empty():
		return []

	var shuffled: Array = q_pool.duplicate()
	shuffled.shuffle()

	var selected: Array[Dictionary] = []
	for i in range(mini(3, shuffled.size())):
		var q_data: Dictionary = shuffled[i]
		selected.append(_shuffle_question_options(q_data))
	return selected

## 문제 보기(options) 및 정답 인덱스(answer) 무작위 셔플 (1번 편중 방지)
func _shuffle_question_options(q_dict: Dictionary) -> Dictionary:
	var q_copy: Dictionary = q_dict.duplicate(true)
	var orig_opts: Array = q_copy.get("options", [])
	var orig_ans_idx: int = int(q_copy.get("answer", 0))
	if orig_opts.is_empty() or orig_ans_idx < 0 or orig_ans_idx >= orig_opts.size():
		return q_copy

	var correct_text: String = str(orig_opts[orig_ans_idx])
	var new_opts: Array = orig_opts.duplicate()
	new_opts.shuffle()

	var new_ans_idx: int = new_opts.find(correct_text)
	if new_ans_idx == -1:
		new_ans_idx = 0

	q_copy["options"] = new_opts
	q_copy["answer"] = new_ans_idx
	return q_copy

## 직렬화
func serialize() -> Dictionary:
	return {
		"last_quiz_years": last_quiz_years.duplicate()
	}

## 역직렬화
func deserialize(data: Dictionary) -> void:
	if data.has("last_quiz_years") and data["last_quiz_years"] is Dictionary:
		var d: Dictionary = data["last_quiz_years"]
		for k in d.keys():
			last_quiz_years[str(k)] = int(d[k])
