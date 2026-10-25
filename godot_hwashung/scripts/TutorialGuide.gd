extends CanvasLayer
class_name TutorialGuide

## PORT-TRACE [튜토리얼·길잡이]: 사용자 요청 — "게임 시작 때 목적과 진행 방법을 초등학생도 알 수
## 있게 쉽게 설명하는 팝업을 띄우고, 건물을 순서대로 지을 수 있게 안내하라. 설명만 나오는 것보다
## 조선 관리 풍의 도우미 캐릭터가 말하는 것처럼". 길잡이 "김판관"이 말풍선으로 이야기한다.
## 1) 시작 인사(여러 쪽, 게임 일시정지, 건너뛰기 가능)
## 2) 어명 교지(QuestSystem) 순서대로 지금 할 일을 쉬운 말로 안내 + [도구 고르기][어디에?] 버튼
## 3) 교지를 마치면 칭찬하고 다음 할 일로
## 말풍선은 접었다 펼 수 있다. 게임 규칙에는 손대지 않고 QuestSystem 신호만 듣는다.

const GUIDE_NAME := "길잡이 김판관"
const SECRETARY_NAME := "비서실장 김종수"

## 대통령제(1897~)가 되면 길잡이는 비서실장 김종수가 된다
func _gname() -> String:
	return SECRETARY_NAME if GuidePortrait.is_secretary() else GUIDE_NAME

## 비서실장 말투: 궁중 말투(전하·~하옵소서·~사옵니다)를 현대 존댓말(대통령님·~하십시오·~습니다)로 바꾼다.
## 조언 문장은 그대로 두고 말풍선에 띄울 때만 바꾼다.
static var _rx_jeonha: RegEx = null
static var _rx_ob: RegEx = null
static func secretary_speech(t: String) -> String:
	if _rx_jeonha == null:
		_rx_jeonha = RegEx.create_from_string("(^|[^가-힣])전하(?=$|[^가-힣]|께)")
		_rx_ob = RegEx.create_from_string("([가-힣])옵니다")
	t = _rx_jeonha.sub(t, "$1대통령님", true)
	for pair in [["하시옵소서", "하십시오"], ["시옵소서", "십시오"], ["옵소서", "십시오"], ["소서", "십시오"],
			["사옵니다", "습니다"], ["이옵니다", "입니다"], ["하옵니다", "합니다"], ["되옵니다", "됩니다"],
			["사오니", "으니"], ["하오니", "하니"], ["이오니", "이니"], ["사옵고", "고"], ["옵고", "고"]]:
		t = t.replace(pair[0], pair[1])
	# 남은 "~옵니다": 앞 글자에 받침 ㅂ을 붙인다(지키옵니다 → 지킵니다, 떠나옵니다 → 떠납니다)
	var out := ""
	var last := 0
	for m in _rx_ob.search_all(t):
		var ch := m.get_string(1)
		var code := ch.unicode_at(0) - 0xAC00
		out += t.substr(last, m.get_start() - last)
		if code >= 0 and code % 28 == 0:
			out += String.chr(ch.unicode_at(0) + 17) + "니다"
		else:
			out += ch + "습니다"
		last = m.get_end()
	return out + t.substr(last)

func _gshort() -> String:
	return "김종수 실장" if GuidePortrait.is_secretary() else "김판관"
const GUIDE_TITLE := "수원부 판관"

const INTRO_PAGES := [
	"전하, 어서 오십시오! 저는 수원부의 판관, 김판관이옵니다.\n지금부터 전하 곁에서 차근차근 도와드릴게요.",
	"때는 1776년, 정조 임금님 시절이에요.\n전하께서는 수원에 튼튼한 성과 살기 좋은 새 도시, '수원 화성'을 만드셔야 해요!",
	"실제 화성은 먼저 관청을 겸한 행궁과 길을 내고, 그다음 성문을 세우고, 문 안에 장이 서자 사람들이 모여들었어요.\n우리도 그 순서대로 해 볼 거예요!",
	"우리가 할 일은 크게 세 가지예요.\n① 성곽을 빙 둘러 쌓아 도시를 지키기\n② 백성들이 모여 살 마을과 시장 만들기\n③ 논밭과 저수지로 먹을 쌀을 넉넉히 만들기",
	"짓는 방법은 아주 쉬워요.\n화면 아래 단추에서 짓고 싶은 것을 고르고, 땅을 콕 누르면 끝!\n길이나 성곽은 누른 채 쭉 끌면 한 번에 그어져요.",
	"무엇이든 지으려면 금(돈)과 쌀이 필요해요. 화면 맨 위에서 얼마나 있는지 볼 수 있어요.\n백성이 늘어나면 세금이 들어와서 금이 다시 모여요.",
	"시간은 한 달씩 흘러요. 달마다 세금을 거두고 나라 살림을 셈해요. 석 달이 모이면 계절이 바뀌어 봄·여름·가을·겨울이 돌아요.\n행궁이나 성곽 같은 큰 공사는 일꾼들이 여러 달에 걸쳐 짓는답니다.",
	"잘못 지었으면 '되돌리기' 단추를 누르면 돼요. 걱정 마세요!",
	"계절이 바뀔 때마다 그 시절에 실제로 있었던 일과, 지금 하면 좋은 일을 제가 알려드릴게요.\n그럼 첫 번째 할 일부터 저와 같이 해 볼까요?",
]

## 교지(퀘스트) id별 쉬운 안내
const STEP_TALK := {
	"haenggung": "첫 번째 할 일! '화성행궁'을 세워요. 임금님이 머무시는 궁궐이면서, 수원 고을 일을 보는 관청(동헌) 노릇도 했던 곳이에요.\n[행궁 터 잡기]를 누르고 넓고 평평한 초록 땅을 누르세요. 7×7칸이나 되는 큰 궁궐이라 네 계절 동안 지어요!",
	"road": "이제 길을 닦아요! [도로 닦기]를 누르고 행궁 앞에서 누른 채 끌어 길을 5칸 이상 그어 보세요.\n길이 있어야 사람과 수레가 오갈 수 있어요.",
	"gate": "실제로 화성을 지을 때는 '문'부터 세웠대요! 장안문·팔달문 같은 사대문이 먼저 서야 사람과 물자가 드나들 수 있으니까요.\n[성문 세우기]를 누르고 방금 닦은 길 위를 눌러 성문을 세워요. 두 계절이면 완성돼요!",
	"seojangdae": "팔달산 꼭대기에 군사를 지휘하는 '서장대'를 세워요.\n[서장대 축조]를 누르고 산 위, 높은 곳을 눌러 주세요. 한 달 동안 일꾼들이 지어요. 어디인지 모르겠으면 [어디에?]를 눌러 보세요!",
	"bongdon": "위험할 때 불과 연기로 소식을 알리는 '봉돈'을 지어요.\n봉돈은 성곽이나 성문 바로 옆에만 지을 수 있어요. 성문 옆에 짓거나, [화성성곽]으로 성곽을 몇 칸 먼저 쌓아 주세요.",
	"civil_zoning": "문이 열렸으니 이제 장이 설 차례예요! 성문 안쪽 길가에 [저잣거리]로 시장을 칠해 주세요. 시장이 생겨야 사람들이 오가기 시작해요.\n[방·리]로 집터, [대유둔전]으로 논밭도 칠하고, 마실 물을 뜨는 '우물'도 하나 파요.",
	"wall_build": "마지막 큰일이에요! 성곽으로 도시를 빙 둘러 싸요.\n[화성성곽]을 고르고 쭉 끌어서 그리면 일꾼들이 두 달 동안 돌을 쌓아요. 길과 성곽이 만나는 곳엔 성문이 생긴답니다!",
}

## 교지를 마쳤을 때 칭찬
const CHEER_TALK := {
	"haenggung": "와, 화성행궁이 완성됐어요! 신풍루 정문 안으로 봉수당·장락당이 늘어선 멋진 궁궐이에요. 이제 이곳에서 고을 일을 척척 볼 수 있어요.",
	"road": "길이 뚫렸어요! 이제 이 길목에 문을 세울 차례예요.",
	"gate": "성문이 우뚝 섰어요! 이제 성문 안에 시장이 서면 사람들이 드나들기 시작할 거예요.",
	"seojangdae": "서장대에서 온 도시가 한눈에 보여요. 멋져요!",
	"bongdon": "봉돈이 섰어요. 이제 위험이 오면 금방 알 수 있어요.",
	"civil_zoning": "장이 서고 백성들이 이사 오기 시작했어요. 길마다 사람들로 북적북적해요!",
	"wall_build": "성곽이 도시를 빙 둘렀어요! 수원 화성이 튼튼해졌어요.",
}

const FINAL_TALK := "전하, 해내셨어요! 일곱 가지 어명을 모두 마치셨어요.\n이제 시장과 논밭, 저수지를 더 가꿔서 백성들이 행복한 도시를 만들어 보세요. 저는 언제든 여기 있을게요!"

## 주요 건물 한글 명칭 및 완공 보고 전담 고증 대사
const BUILDING_NAMES: Dictionary = {
	"haenggung": "화성행궁", "haenggung_site": "화성행궁",
	"gwana": "관아·옥사", "gwana_site": "관아·옥사",
	"jongnu": "종루(여민각)", "jongnu_site": "종루(여민각)",
	"yeonghwajeong": "영화정", "yeonghwajeong_site": "영화정",
	"hyanggyo": "수원향교", "hyanggyo_site": "수원향교",
	"manseokgeo": "만석거", "manseokgeo_site": "만석거",
	"chukmanje": "축만제(서호)", "chukmanje_site": "축만제(서호)",
	"wall": "성곽 석축", "gate": "성문",
	"seojangdae": "서장대", "seojangdae_site": "서장대",
	"bongdon": "봉돈", "bongdon_site": "봉돈",
	"gongsimdon": "공심돈", "gongsimdon_site": "공심돈", "gongsimdon_wall": "공심돈",
	"poru": "포루", "poru_site": "포루",
	"yeonmudae": "연무대", "yeonmudae_site": "연무대", "yeonmudae_range": "연무대 활터", "dongjangdae": "연무대",
	"banghwasuryu": "방화수류정", "banghwasuryujeong": "방화수류정", "dongbuk_gakru": "방화수류정",
	"yongyeon": "용연",
	"hwahong": "화홍문(북수문)", "hwahongmun": "화홍문(북수문)", "hwahong_mun": "화홍문(북수문)", "buksumun": "화홍문(북수문)",
	"namsu": "남수문", "namsumun": "남수문", "namsu_mun": "남수문",
	"reservoir": "저수지", "levee": "석축제방", "patrol": "순라청",
	"firefighter": "멸화군", "guesthouse": "객사", "factory": "공방",
	"seodang": "서당", "seowon": "서원", "jinhulso": "진휼소",
	"maehyang_gyo": "매향교", "maehwang_gyo": "매향교", "well": "마을 우물", "canal": "관개수로"
}

const BUILDING_COMPLETION_TALK: Dictionary = {
	"haenggung": "전하, 화성행궁이 웅장하게 완공되었사옵니다!\n신풍루 정문 안으로 봉수당과 장락당이 위용을 드러내어, 이제 고을의 정무를 총괄하고 장용영 외영 군사를 호령할 수 있사옵니다.",
	"gwana": "전하, 관아와 옥사가 완공되었사옵니다!\n고을 백성의 송사를 공정히 다스리고, 도적과 죄인을 엄히 가두어 화성의 치안 질서를 바로잡겠사옵니다.",
	"jongnu": "전하, 종루(여민각)가 우뚝 섰사옵니다!\n새벽 인정(새벽 4시)과 밤 파루(밤 10시)에 장엄한 종소리를 울려 백성들에게 시간을 알리고 성문을 여닫는 기준이 마련되었사옵니다.",
	"yeonghwajeong": "전하, 영화정(迎華亭)이 완공되었사옵니다!\n신임 화성유수가 관인을 인계받고, 과거 시험과 활쏘기 무과 시험을 치르는 유서 깊은 누정이옵니다.",
	"hyanggyo": "전하, 수원향교가 낙성되었사옵니다!\n대성전에서 공자와 선현을 배향하고 명륜당에서 선비와 유생들을 가르쳐 화성의 학풍과 도덕을 크게 진작시키겠사옵니다.",
	"manseokgeo": "전하, 만석거 저수지가 축조되었사옵니다!\n북쪽 황무지에 물길을 가두어 광활한 대유둔전에 관개 수로를 열었사오니, 천석 만석의 쌀을 수확할 대풍년의 기틀이 섰사옵니다.",
	"chukmanje": "전하, 축만제(서호)가 완공되었사옵니다!\n서호의 너른 물길로 서쪽 들판에 생명수를 공급하고, 아름다운 서호낙조의 절경이 고을의 자랑이 되었사옵니다.",
	"wall": "전하, 화성 성곽의 견고한 석축이 완공되었사옵니다!\n규격화된 석재와 석회 모르타르로 쌓아올려 어떠한 외적의 침입에도 끄떡없는 철옹성이 되었사옵니다.",
	"gate": "전하, 성문이 위용을 드러내며 완공되었사옵니다!\n옹성과 문루를 갖춘 웅장한 관문이 열려 삼남대로의 물류와 백성이 번성하고 성곽의 방어력이 크게 신장되었사옵니다.",
	"seojangdae": "전하, 팔달산 정상에 서장대가 우뚝 솟았사옵니다!\n화성 전역과 사방 백 리를 한눈에 굽어보며 군사를 호령하고, 장용영 정예병의 야간 군사 훈련(야조)을 거행할 군사 최고 사령부이옵니다.",
	"bongdon": "전하, 봉돈(봉수대)이 완공되었사옵니다!\n벽돌로 정교하게 쌓은 5개의 화로에서 밤에는 횃불, 낮에는 연기로 변방의 위급 상황을 한양 조정까지 신속히 전파할 수 있사옵니다.",
	"gongsimdon": "전하, 공심돈(空心墩)이 우뚝 솟았사옵니다!\n속이 빈 전탑 구조로 내부에 나선형 계단을 두고 사방 총안에서 조총과 백자총통을 일제 사격하여 적을 섬멸할 수 있는 독창적 방어시설이옵니다.",
	"poru": "전하, 포루(砲樓)가 완공되었사옵니다!\n성벽에서 돌출된 치성 위에 화포를 배치하여 성벽에 접근하는 적을 정면과 측면에서 포격으로 격멸하옵니다.",
	"yeonmudae": "전하, 연무대(동장대)가 위용을 갖추었사옵니다!\n군사들이 무예를 연마하고 활쏘기와 창검술을 훈련하는 동북방 최고의 군사 훈련장이옵니다.",
	"banghwasuryu": "전하, 방화수류정(동북각루)이 완공되었사옵니다!\n용연 연못 절벽 위에 서서 빼어난 경치를 자랑하는 정자이면서도, 유사시 동북방을 감시하고 방어하는 요새 누각이옵니다.",
	"banghwasuryujeong": "전하, 방화수류정(동북각루)이 완공되었사옵니다!\n용연 연못 절벽 위에 서서 빼어난 경치를 자랑하는 정자이면서도, 유사시 동북방을 감시하고 방어하는 요새 누각이옵니다.",
	"dongbuk_gakru": "전하, 방화수류정(동북각루)이 완공되었사옵니다!\n용연 연못 절벽 위에 서서 빼어난 경치를 자랑하는 정자이면서도, 유사시 동북방을 감시하고 방어하는 요새 누각이옵니다.",
	"dongjangdae": "전하, 연무대(동장대)가 위용을 갖추었사옵니다!\n군사들이 무예를 연마하고 활쏘기와 창검술을 훈련하는 동북방 최고의 군사 훈련장이옵니다.",
	"hwahong": "전하, 화홍문(북수문) 7련 홍예교가 완공되었사옵니다!\n수원천의 거센 물길을 다스려 도성의 수해를 막고, 일곱 무지개 수문 위로 누각이 아름답게 솟았사옵니다.",
	"hwahongmun": "전하, 화홍문(북수문) 7련 홍예교가 완공되었사옵니다!\n수원천의 거센 물길을 다스려 도성의 수해를 막고, 일곱 무지개 수문 위로 누각이 아름답게 솟았사옵니다.",
	"namsu": "전하, 남수문(남쪽 수문)이 완공되었사옵니다!\n성벽과 결합된 수문 요새로 도성의 물길 배수를 원활히 하고 남쪽 방어선을 굳건히 지키옵니다.",
	"namsumun": "전하, 남수문(남쪽 수문)이 완공되었사옵니다!\n성벽과 결합된 수문 요새로 도성의 물길 배수를 원활히 하고 남쪽 방어선을 굳건히 지키옵니다.",
	"yongyeon": "전하, 방화수류정 아래 용연 연못이 아름답게 조성되었사옵니다!\n빼어난 풍광으로 백성과 군신의 마음을 달래고 수원천의 수위를 조절하는 연못이옵니다.",
	"reservoir": "전하, 저수지가 완공되었사옵니다!\n가뭄에 대비해 넉넉한 농업용수를 비축하고 인근 둔전에 물을 안정적으로 공급할 수 있사옵니다.",
	"levee": "전하, 수원천 석축제방이 튼튼히 완공되었사옵니다!\n여름철 집중호우와 범람을 원천 방어하여 도심과 논밭의 수해 피해를 막아내옵니다.",
	"patrol": "전하, 순라청이 건립되었사옵니다!\n야간 통행금지와 치안 순찰을 맡을 순라군이 상시 배치되어 화적의 침입을 억제하고 민생을 안전하게 지키겠사옵니다.",
	"firefighter": "전하, 멸화군 관청이 설치되었사옵니다!\n조종용수와 소화 장비를 갖추고 24시간 망을 보아 화재 발생 시 즉각 출동하여 불길을 진화하옵니다.",
	"guesthouse": "전하, 객사가 완공되었사옵니다!\n한양 조정에서 내려오는 관원과 외교 사절을 정중히 영접하고 왕명을 받드는 공공 숙소이옵니다.",
	"factory": "전하, 관영 공방이 완공되었사옵니다!\n무기와 농기구, 성곽 축성 도구를 정밀하게 생산하여 산업 생산력과 국방력을 동시에 끌어올리옵니다.",
	"seodang": "전하, 훈장님이 아이들을 가르칠 서당이 완공되었사옵니다!\n천자문과 소학을 낭독하는 아이들의 글소리가 골목마다 울려 퍼져 화성의 미래가 밝아졌사옵니다.",
	"seowon": "전하, 학문을 연마하고 선현을 기리는 서원이 건립되었사옵니다!\n선비와 유생들이 모여 경전을 강론하고 나라의 동량으로 자라나 화성의 학풍을 드높이옵니다.",
	"jinhulso": "전하, 흉년과 가난에 지친 백성을 보살필 진휼소가 설치되었사옵니다!\n굶주린 백성에게 죽과 구휼미를 베풀어 단 한 사람의 백성도 굶어 죽지 않도록 온정을 베푸옵니다.",
}

var quests: Node
var panels: PanelController
var hud: HUDController
var time_manager: TimeManager
var sim: SimulationCore
var court: CourtSystem
var grid: GameGrid

## PORT-TRACE [시기별 추천]: 사용자 요청 — "실제 역사적 시기에 맞게 할 일을 김판관이 알려주면
## 좋겠다(1795 을묘원행, 1796~ 원행을묘정리의궤·화성성역의궤, 현륭원 친림, 포호책 등)".
## 계절(턴)이 바뀔 때마다 _advise_for_turn()이 역사 연표 + 지금 상황(호환, 장마, 국고·군량·
## 민심)을 보고 조언을 골라 대기열에 넣고, 한 번에 하나씩 보여준다. 각 조언에는 해당 창을
## 여는 버튼(또는 도구 선택)이 달린다. 같은 조언은 한 번만(해마다 반복하는 것은 연도별로 한 번).
var _advice_queue: Array = []
var _advice_seen := {}
var _advice_now: Dictionary = {}
var _reported_unique_buildings: Dictionary = {}

var _affairs_list: Array[Dictionary] = []
var _affair_idx: int = 0
var _current_tab: String = "quest" # "quest" or "affairs"

var _dim: ColorRect
var _box: PanelContainer
var _portrait: GuidePortrait
var _name_lbl: Label
var _text_lbl: Label
var _page_lbl: Label
var _next_btn: Button
var _skip_btn: Button
var _tool_btn: Button
var _where_btn: Button
var _fold_btn: Button
var _reopen_btn: Button
var _tab_quest_btn: Button
var _tab_affairs_btn: Button
var _prev_advice_btn: Button
var _next_advice_btn: Button

var _mode := "intro" # intro / step / cheer / done / affairs / advice
var _page_i := 0
var _typing := 0.0
var _speed_before: int = TimeManager.SpeedMode.NORMAL
var _step_quest: Dictionary = {}
## PORT-TRACE [퀘스트 자동 정리]: 칭찬·"이미 마친 일" 말풍선은 이 시간이 지나면 저절로 닫히고 다음 할 일로(클릭 불필요)
var _auto_close := 0.0
var _recheck := 0.0
const SERIALIZE_COOLDOWN_DELAY: float = 5.0 # 사용자 종료 후 다음 조언/상황 생성까지 5초 직렬화 지연
var _is_user_folded: bool = false
var _advice_cooldown: float = 0.0

## [정무 조언 영구 무시 시스템]
## "알겠어요" 또는 "닫기"를 누른 key는 이 집합에 등록되어 해당 세션 동안 재출력하지 않는다.
## 단, 상태가 바뀐 조언(호환 새로 발생 등)은 별도 key로 생성되므로 자동 표시된다.
var _dismissed_affairs: Dictionary = {}
## PORT-TRACE [인구 조언 1년 1회]: 사용자 요청 — "인구 관련 조언은 확인한 뒤 1년 동안 다시 하지 않도록".
## 인구 수용 한계 조언을 마지막으로 보여 준 턴(저장됨). 그 뒤 12턴(1년) 동안은 목록에 올리지 않는다.
const POP_CAP_ADVICE_INTERVAL := 12
var _pop_cap_seen_turn: int = -9999
## 초야 인재 건의에서 [등용 안 함] — 누른 인재는 _dismissed_affairs에 올라 다시 건의되지 않는다(저장됨)
var _decline_btn: Button
## 조언 간 최소 간격(초) - 같은 조언이 연속으로 쏟아지지 않도록
const AFFAIRS_MIN_INTERVAL: float = 30.0
var _affairs_cooldown: float = 0.0
## 이번 턴에 이미 자동 표시한 조언 key (중복 방지)
var _affairs_shown_this_turn: Dictionary = {}

func setup(q: Node, p: PanelController, h: HUDController, tm: TimeManager, s: SimulationCore, c: CourtSystem, g: GameGrid, auto_start_intro: bool = false) -> void:
	quests = q
	panels = p
	hud = h
	time_manager = tm
	sim = s
	court = c
	grid = g
	layer = 20
	_build_ui()
	quests.quest_completed.connect(_on_quest_completed)
	court.scholar_appeared.connect(_on_scholar_appeared)
	if sim.tech_tree != null:
		sim.tech_tree.research_completed.connect(_on_research_completed)
		sim.tech_tree.prince_study_completed.connect(_on_prince_completed)
	if not sim.project_completed.is_connected(report_mega_project_completed):
		sim.project_completed.connect(report_mega_project_completed)
	quests.all_quests_completed.connect(_on_all_done)
	sim.turn_advanced.connect(_on_turn)
	if auto_start_intro:
		start_intro()

# ------------------------------------------------------------------ 시기별 추천
func _once(key: String) -> bool:
	if _advice_seen.has(key):
		return false
	_advice_seen[key] = true
	return true

func _is_advice_target_completed_or_in_progress(adv: Dictionary) -> bool:
	var key: String = adv.get("key", "")
	var target: String = adv.get("target", "")
	var text: String = adv.get("text", "")
	var kind: String = adv.get("kind", "")

	# 1. 수원천 석축 제방 대역사 (착공 또는 완공 시 추천 제외)
	if "levee" in key or "flood" in key or "수원천 석축 제방" in text:
		if _levee_started():
			return true

	# 2. 사대문 및 화홍문 (착공 또는 완공 시 추천 제외)
	if key.begins_with("gate_seq_") or (kind == "tool" and target == "gate"):
		var gate_id: String = key.trim_prefix("gate_seq_")
		if gate_id != "" and gate_id != key:
			for g in QuestSystem.GATE_ORDER:
				if g.get("id", "") == gate_id:
					if _is_gate_constructed_or_started(g):
						return true
		else:
			var ng := _get_next_unbuilt_gate()
			if ng.is_empty():
				return true

	# 3. 만석거 (착공/완공 시 추천 제외)
	if target == "manseokgeo" or "manseok" in key or "만석거" in text:
		if grid:
			for y in range(grid.size):
				for x in range(grid.size):
					var b: String = grid.grid[y][x].get("building", "")
					if b == "manseokgeo" or b == "manseokgeo_site":
						return true
		if sim:
			for p in sim.mega_projects:
				if p.get("id", "") == "manseok_reservoir" and (p.get("is_started", false) or p.get("is_completed", false) or p.get("is_disabled", false)):
					return true

	# 4. 성곽 (완공도 100% 또는 폐곡선 완성 시 추천 완전 제외)
	if target == "wall" or target == "wall_build" or "wall" in key or "y1794" in key or "y1796" in key or "성곽" in text:
		var is_wall_done := false
		if sim and sim.fortress_progress >= 100:
			is_wall_done = true
		if grid and (grid.fortress_progress >= 100 or (grid.has_method("is_wall_loop_completed") and grid.is_wall_loop_completed())):
			is_wall_done = true
		if quests and quests.has_method("is_quest_completed") and quests.is_quest_completed("wall_build"):
			is_wall_done = true
		if is_wall_done:
			return true

	# 5. 일반 국책 대역사 모달 추천
	if kind == "modal" and target == "mega_projects":
		# 모든 국책 대역사가 완료 또는 착공 상태이면 추천 제외
		if sim:
			var all_done := true
			for p in sim.mega_projects:
				if not p.get("is_started", false) and not p.get("is_completed", false) and not p.get("is_disabled", false):
					all_done = false
					break
			if all_done:
				return true

	return false

## PORT-TRACE [조언 큐 최적화]: 사용자 요청 — "미확인 조언이 수십 개 쌓이지 않게 최대 5개, 이미 해결됐거나 철 지난 조언은
## 띄우지 않고 조용히 버리고, 긴급한 최신 상황을 위로". 조언마다 만든 턴(turn)과 우선순위(prio: 3 긴급 재난·방호 위기,
## 2 그 철의 상황, 1 인재 천거, 0 역사 연표·일반)를 달고, 넣을 때·꺼낼 때·턴마다 만료(_advice_expired)를 걸러 낸다.
const ADVICE_MAX := 5
func _advice_prio(key: String) -> int:
	for p3: String in ["tiger_", "flood_", "siege", "defense_", "research_done_", "prince_study_done"]:
		if key.begins_with(p3):
			return 3
	for p2: String in ["gold_", "rice_", "loyal_", "hyo_", "eulmyo", "prince"]:
		if key.begins_with(p2):
			return 2
	if key.begins_with("scholar_"):
		return 1
	return 0

## 철 지난 조언: 그 턴(계절)의 상황 조언은 다음 턴이면 만료, 호환은 해결되면, 인재 천거는 후보가 떠나거나 등용되면,
## 국고·쌀·민심 경고는 이미 회복됐으면 만료
func _advice_expired(adv: Dictionary) -> bool:
	var key: String = adv.get("key", "")
	if key.begins_with("research_done_") or key == "prince_study_done":
		return false # 연구 완료 보고는 철 지나지 않는다
	var cur_turn: int = sim.turn if sim != null else 1
	var made: int = int(adv.get("turn", cur_turn))
	for p1: String in ["tiger_", "flood_", "gold_", "rice_", "loyal_", "hyo_"]:
		if key.begins_with(p1) and sim != null and sim.turn > made:
			return true
	var is_wall_adv: bool = bool(key.begins_with("wall") or adv.get("target", "") == "wall" or "성곽" in adv.get("text", "") or "y1794" in key or "y1796" in key)
	if is_wall_adv and ((sim and sim.fortress_progress >= 100) or (grid and (grid.fortress_progress >= 100 or (grid.has_method("is_wall_loop_completed") and grid.is_wall_loop_completed())))):
		return true
	if key.begins_with("tiger_") and not court.tiger.get("active", false):
		return true
	if key.begins_with("gold_") and sim.gold >= 300:
		return true
	if key.begins_with("rice_") and sim.rice >= 300:
		return true
	if key.begins_with("loyal_") and sim.loyalty >= 45:
		return true
	if key.begins_with("scholar_"):
		var cid: String = adv.get("cand", "")
		if ScholarManager.is_scholar_hired(cid, sim.retainers if sim != null else {}):
			return true
		var alive := false
		if court != null:
			for c in court.candidates:
				if c["id"] == cid:
					alive = true
		if not alive:
			return true
	if key == "eulmyo" and (court == null or not court.eulmyo.get("active", false)):
		return true
	var prince_invested: bool = (court != null and (court.crown_prince.get("invested", false) or court.crown_prince.get("education", 0) > 0))
	if sim != null and sim.crown_prince_manager != null and sim.crown_prince_manager.has_method("is_education_active") and sim.crown_prince_manager.is_education_active():
		prince_invested = true
	if key == "prince" and (prince_invested or CrownPrinceEducationManager.prince_affairs_closed(court.current_year if court != null else 1789)):
		return true # 1800년 엔딩(순조 즉위) 뒤에는 세자 책봉 권유도 철 지남
	var tomb_done: bool = (court != null and court.hyoryungwon.get("visited", false)) or CityStats.get_hyeonryungwon_visits() > 0 or (court != null and court.hyeonryungwon_visits > 0)
	if key.begins_with("hyo_") and tomb_done:
		return true
	return _is_advice_target_completed_or_in_progress(adv)

func _prune_advice() -> void:
	_advice_queue = _advice_queue.filter(func(a): return not _advice_expired(a))

func _push_advice(key: String, text: String, btn: String = "", kind: String = "", target: String = "", extra: Dictionary = {}) -> void:
	var adv := {"key": key, "text": text, "btn": btn, "kind": kind, "target": target, "turn": sim.turn, "prio": _advice_prio(key)}
	adv.merge(extra)
	if _advice_expired(adv):
		return
	if not _once(key):
		return
	_advice_queue.append(adv)
	# 우선순위 높은 것 먼저, 같으면 최신 것 먼저
	_advice_queue.sort_custom(func(a, b): return int(a["prio"]) > int(b["prio"]) or (int(a["prio"]) == int(b["prio"]) and int(a["turn"]) > int(b["turn"])))
	while _advice_queue.size() > ADVICE_MAX:
		_advice_queue.pop_back() # 가장 덜 급하고 오래된 것부터 버림

func _levee_started() -> bool:
	for p in sim.mega_projects:
		if p["id"] == "suwon_levee":
			return p["is_started"] or p["is_completed"] or bool(p.get("is_disabled", false))
	return true

func _on_turn(_turn: int, season_index: int, year: int) -> void:
	_prune_advice()
	_advise_for_turn(season_index, year)
	# 매 턴마다 이번 턴 표시 기록 초기화
	_affairs_shown_this_turn.clear()
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()
	if _name_lbl != null:
		_name_lbl.text = _gname()

	if _reopen_btn != null:
		var undismissed_count: int = 0
		for aff: Dictionary in _affairs_list:
			if not _dismissed_affairs.has(str(aff.get("key", ""))):
				undismissed_count += 1
		if undismissed_count > 0:
			_reopen_btn.text = ("🧑‍⚖️ %s (정무 조언 %%d건 💡)" % _gshort()) % undismissed_count
		else:
			_reopen_btn.text = "🧑‍⚖️ " + _gname()

	# [자동 표시]: prio 11+(도적·호환 실제 발생)만 자동 표시, 쿨다운+dismiss+이번턴 미표시 조건 모두 충족
	if _affairs_cooldown <= 0.0 and not _is_user_folded:
		var first_urgent: Dictionary = {}
		for aff: Dictionary in _affairs_list:
			var aff_key: String = str(aff.get("key", ""))
			if int(aff.get("prio", 0)) >= 11 and not _dismissed_affairs.has(aff_key) and not _affairs_shown_this_turn.has(aff_key):
				first_urgent = aff
				break
		if not first_urgent.is_empty():
			var idx: int = _affairs_list.find(first_urgent)
			_affairs_shown_this_turn[str(first_urgent.get("key", ""))] = true
			_affairs_cooldown = AFFAIRS_MIN_INTERVAL
			_unfold()
			_show_affairs_tab(idx)

	# 어명 큐 기반 조언은 쿨다운 지나면 한 건씩
	if _mode in ["step", "done"] and not _advice_queue.is_empty() and _advice_cooldown <= 0.0:
		_show_next_advice()

## ===================================================================
## [정무 관련 조언 전담 엔진 - 김판관 단일 체제]
## 인재 등용, 호포책, 현륭원 친림, 서장대 훈련, 도적떼 소탕 등 모든 정무 조언을 실시간 수집
## ===================================================================
func _collect_affairs_advices() -> Array[Dictionary]:
	if ModernizationManager.is_active():
		return _collect_modern_advices()
	var list: Array[Dictionary] = []
	var yr: int = court.current_year if court != null else 1789
	var s_idx: int = maxi(0, ["봄", "여름", "가을", "겨울"].find(time_manager.get_current_season())) if time_manager != null else 0

	# 1. 인재 등용 (조정 인사)
	if court != null:
		var unhired_cands: Array[Dictionary] = []
		var has_declined := false
		for cand: Dictionary in court.candidates:
			var cid: String = str(cand.get("id", ""))
			if not ScholarManager.is_scholar_hired(cid, sim.retainers if sim != null else {}):
				if _dismissed_affairs.has("affair_scholar_" + cid): # [등용 안 함]으로 물린 인재는 다시 건의하지 않는다
					has_declined = true
					continue
				unhired_cands.append(cand)
		if not unhired_cands.is_empty():
			var cand: Dictionary = unhired_cands[0]
			var cid: String = str(cand.get("id", ""))
			var info: Dictionary = CourtSystem.SCHOLARS.get(cid, {})
			var c_name: String = str(info.get("name", cand.get("name", cid)))
			var praise: String = str(cand.get("praise", "탁월한 경륜을 갖춘 인재이옵니다."))
			var sal: int = court.get_scholar_salary(cid) if court != null else CourtSystem.calculate_scholar_salary(int(info.get("salary", 200)))
			var acc: int = int(cand.get("acc", 80))
			list.append({
				"key": "affair_scholar_" + cid,
				"title": "초야 인재 등용",
				"text": "전하, 초야에 %s(이)라는 훌륭한 인재가 당도하여 조정의 부름을 기다리고 있사옵니다.\n\"%s\"\n(녹봉 매달 %d냥 · 신의 천거 정확도 %d%%)\n[조정 인사]에서 등용하시어 국정을 맡기시옵소서!" % [c_name, praise, sal, acc],
				"btn": "👥 인재 등용",
				"kind": "modal",
				"target": "court",
				"cand": cid,
				"prio": 10
			})
		elif not has_declined and (sim != null and sim.retainers.values().count(true) < 3):
			list.append({
				"key": "affair_court_hire",
				"title": "인재 발탁 권고",
				"text": "조정에 사대부 인재가 부족하여 정무 자문과 학문 연구에 어려움이 있사옵니다.\n[조정 인사]를 열어 초야의 실학자와 무관을 두루 천거받으시옵소서.",
				"btn": "👥 조정 인사",
				"kind": "modal",
				"target": "court",
				"prio": 5
			})

	# 1-1. 재정 조언: 지난 한 달 국고가 줄었으면 까닭(세수 부족/유지비 과다)과 버틸 수 있는 달 수를 아뢴다
	# 국고가 이미 바닥나 이달 유지비를 다 못 냈으면(달마다 민심 -6·왕권 -4) 그것부터 아뢴다 — 이때는 국고가 0 근처에서
	# 오르내려 석 달 합으로는 적자가 잘 드러나지 않는다
	var unpaid: int = int(sim.last_maintenance_result.get("shortage_gold", 0)) if (sim != null and sim.last_maintenance_result is Dictionary) else 0
	if sim != null and unpaid > 0:
		var tax_sum_u: int = sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military
		list.append({
			"key": "affair_finance_unpaid_%d" % int(float(sim.turn) / 3.0), # 석 달마다 다시 아뢴다
			"title": "운영자금 체납",
			"text": "전하, 국고가 바닥나 이달 공공시설 유지비 가운데 %d냥을 치르지 못했사옵니다! 체납이 이어지면 달마다 민심 -6, 왕권 -4가 깎이고 녹봉 밀린 신하가 떠나옵니다.\n%s\n3대 조세의 합을 6%% 이상으로 올리시거나, 삼남 교역에서 곳간의 곡식을 내다 파시옵소서." % [unpaid, ("3대 조세의 합이 %d%%로 너무 낮아 세수가 유지비를 감당하지 못하고 있사옵니다." % tax_sum_u) if tax_sum_u < 6 else "세수보다 공공시설 유지비와 녹봉·공사비가 더 많이 나가고 있사옵니다."],
			"btn": "⚖️ 호조 조세",
			"kind": "modal",
			"target": "tax",
			"prio": 12
		})
	elif sim != null and sim.get_recent_season_gold_delta() < 0:
		var season_loss: int = -sim.get_recent_season_gold_delta()
		var loss: int = int(ceil(float(season_loss) / 3.0)) # 한 달 평균
		var months_left: int = int(floor(float(sim.gold) / float(loss))) if loss > 0 else 999
		var tax_sum: int = sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military
		var why: String
		if tax_sum < 6:
			why = "3대 조세의 합이 %d%%로 너무 낮아 세수가 공공시설 유지비를 감당하지 못하고 있사옵니다." % tax_sum
		else:
			why = "세수보다 공공시설 유지비(특히 인구에 비례하는 화성행궁 운영비)와 녹봉·공사비가 더 많이 나가고 있사옵니다."
		list.append({
			"key": "affair_finance_deficit_%d" % int(float(sim.turn) / 6.0), # 반년마다 다시 아뢴다
			"title": "국고 적자 경고",
			"text": "전하, 지난 석 달 동안 국고가 달마다 평균 %d냥씩 줄었사옵니다. 이대로면 %s 뒤에 국고가 바닥나옵니다.\n%s\n3대 조세의 합을 6%% 이상으로 올리시거나, 삼남 교역에서 곳간의 곡식을 내다 파시거나, 녹봉이 비싼 신하를 정리하시옵소서.\n국고가 바닥나면 운영자금 체납으로 민심·왕권이 깎이고 녹봉 밀린 신하가 떠나옵니다." % [loss, ("약 %d달" % months_left) if months_left < 999 else "머지않아", why],
			"btn": "⚖️ 호조 조세",
			"kind": "modal",
			"target": "tax",
			"prio": 11 if months_left <= 12 else 8
		})
	# 1-2. 인구 상한: 도시가 감당할 수 있는 인구에 이르렀으면 무엇이 막고 있는지 아뢴다
	if sim != null and sim.pop_manager != null and bool(sim.pop_manager.last_pop_cap.get("at_cap", false)) 			and sim.turn - _pop_cap_seen_turn >= POP_CAP_ADVICE_INTERVAL:
		var pc: Dictionary = sim.pop_manager.last_pop_cap
		var tax_cap: int = int(pc.get("tax_cap", 0))
		var prod_cap: int = int(pc.get("prod_cap", 0))
		var cap_why: String
		if tax_cap < prod_cap:
			cap_why = "세율이 높아 백성이 %d명 넘게는 모여들지 않사옵니다. 세율을 낮추면 더 모이나 세수가 줄어 국고가 적자가 될 수 있사옵니다." % tax_cap
		else:
			cap_why = "집·저잣거리·공방·대유둔전이 %d명까지만 먹여 살릴 수 있사옵니다. 빈 땅이 있으면 방·리, 저잣거리, 공방, 둔전을 더 지으시옵소서." % prod_cap
			# 땅이 다 찼으면 더 지을 수 없으니, 같은 땅에서 더 많이 먹여 살리는 길(근대 개편)을 아뢴다
			if UrbanEvolutionManager.is_active():
				cap_why += "
땅이 다 찼다면, 도시가 석조(1.25배)·다층 건물(2배)로 개편될수록 같은 땅에서 더 많은 백성이 살 수 있사옵니다. 서학 진척과 근대 과학 연구, 외교로 근대화를 앞당기시옵소서. (지금 도시 평균 %.2f배)" % float(pc.get("modern_mult", 1.0))
			else:
				cap_why += "
땅이 다 찼다면 지금의 기와·초가로는 더 늘리기 어렵사옵니다. 훗날 근대 기술로 석조·다층 건물이 들어서면 같은 땅에서 더 많은 백성이 살 수 있사옵니다."
		list.append({
			"key": "affair_pop_cap_%d" % sim.turn,
			"title": "인구 수용 한계",
			"text": "전하, 화성의 인구가 도시가 감당할 수 있는 한계(%d명)에 이르렀사옵니다.\n%s" % [int(pc.get("cap", 0)), cap_why],
			"btn": "⚖️ 호조 조세",
			"kind": "modal",
			"target": "tax",
			"prio": 6
		})

	# 2. 호포책 (팔달산 호환 대책) — 호환이 실제 발생했을 때만 표시
	if court != null:
		if court.tiger.get("active", false):
			list.append({
				"key": "affair_tiger_active",
				"title": "팔달산 포호책(捕虎策) 결단",
				"text": "팔달산에 맹호가 출몰하여 백성들이 큰 불안과 공포에 떨고 있사옵니다!\n[포호책]을 결단하시어 착호갑사를 급파하고 산을 개간해 호환을 종식시키시옵소서.",
				"btn": "🐯 포호책 시행",
				"kind": "modal",
				"target": "tiger",
				"prio": 12
			})
		# 호환 없을 때 미리 점검 조언은 하지 않음 (이미 실행했거나 아직 발생 안 한 사안 조언 금지)

	# 3. 현륭원 친림 참배
	if court != null:
		var visited: bool = bool(court.hyoryungwon.get("visited", false)) or CityStats.get_hyeonryungwon_visits() > 0 or court.hyeonryungwon_visits > 0
		if yr >= 1789 and not visited:
			list.append({
				"key": "affair_hyoryungwon",
				"title": "현륭원 친림 참배",
				"text": "선대왕 사도세자께서 잠드신 현륭원에 친림 참배하시옵소서.\n임금의 지극한 효심을 천하에 널리 보이시면 백성의 민심이 크게 오르고 왕권이 공고해질 것이옵니다.",
				"btn": "🙏 현륭원 친림",
				"kind": "modal",
				"target": "hyoryungwon",
				"prio": 9
			})

	# 4. 서장대 훈련 (야조)
	# key를 sim.turn 기반으로 생성 → 쿨타임 종료 후 새 훈련 시기마다 새 key가 만들어져
	# dismiss가 정상 동작함(한 번 무시하면 다음 쿨타임 종료 전까지 재표시 없음)
	# 쿨타임 중인 "군비 점검" 항목은 플레이어에게 불필요한 정보라 표시하지 않음
	if grid != null and grid.count_completed("seojangdae") > 0:
		var cd_m: int = sim.seojangdae_drill_cd_months if sim != null else 0
		if cd_m <= 0:
			var drill_turn: int = sim.turn if sim != null else 0
			list.append({
				"key": "affair_seojangdae_r%d" % drill_turn,
				"title": "서장대 야조(夜操) 군사 훈련",
				"text": "팔달산 서장대에서 장용영 정예병들의 야간 군사 훈련(야조)을 거행할 때이옵니다!\n조총 일제사격과 야간 신호로 군세를 떨치고 국방력을 대폭 신장시키시옵소서.",
				"btn": "⚔️ 서장대 훈련",
				"kind": "modal",
				"target": "seojangdae_drill",
				"prio": 8
			})
	elif grid != null and grid.count_completed("seojangdae") == 0:
		list.append({
			"key": "affair_build_seojangdae",
			"title": "서장대 축조 권고",
			"text": "팔달산 정상에 군사를 총지휘할 군사령부 '서장대'를 축조해야 하옵니다.\n서장대가 완공되면 장용영 군사를 훈련시키고 화성 전역의 방위를 호령할 수 있사옵니다.",
			"btn": "🏯 서장대 축조",
			"kind": "tool",
			"target": "seojangdae",
			"prio": 6
		})

	# 5. 도적떼 소탕 및 치안 방비
	var bandit_active: bool = (sim != null and sim.bandit_active) or (sim != null and sim.bandit_manager != null and (sim.bandit_manager.has_method("has_active_bandits") and sim.bandit_manager.has_active_bandits()))
	if bandit_active:
		list.append({
			"key": "affair_bandit_active",
			"title": "화적(도적) 소탕 및 토벌",
			"text": "수원 화성 외곽에 흉악한 도적 떼가 출몰하여 백성의 양식과 재물을 노리고 있사옵니다!\n순라군을 급파하고 [도적 소탕]을 결단하여 도적 소굴을 일망타진하시옵소서.",
			"btn": "🛡️ 도적 소탕",
			"kind": "modal",
			"target": "bandit",
			"prio": 11
		})
	else:
		var has_patrol: bool = grid.count_completed("patrol") > 0 if grid != null else false
		if not has_patrol:
			list.append({
				"key": "affair_patrol_needed",
				"title": "치안 순라청 축조",
				"text": "고을에 순라청이 없어 밤길 치안이 불안하고 도적의 침입에 취약하옵니다.\n[방·리] 인근에 순라청을 지어 군포 순라군을 상시 순찰케 하시옵소서.",
				"btn": "🛡️ 치안 방비",
				"kind": "modal",
				"target": "bandit",
				"prio": 6
			})

	# 6. 세자 서연 (제왕학 교육)
	var p_active: bool = court != null and (court.crown_prince.get("invested", false) or court.crown_prince.get("education", 0) > 0)
	if sim != null and sim.crown_prince_manager != null and sim.crown_prince_manager.has_method("is_education_active") and sim.crown_prince_manager.is_education_active():
		p_active = true
	if yr >= 1790 and not p_active and not CrownPrinceEducationManager.prince_affairs_closed(yr): # 1800년 엔딩(순조 즉위) 뒤에는 권하지 않음
		list.append({
			"key": "affair_prince",
			"title": "시강원 세자서연",
			"text": "1790년 원자께서 태어나셨사오니, 시강원에서 훌륭한 스승을 모셔 제왕학 서연을 열어야 하옵니다.\n세자 교육을 철저히 하여 나라의 만년 대계를 세우소서.",
			"btn": "👑 세자서연",
			"kind": "modal",
			"target": "crown_prince",
			"prio": 7
		})

	# 7. 실학 연구
	if sim != null and sim.tech_tree != null and sim.tech_tree.current_researching == "" and sim.tech_tree.has_remaining_research(): # 다 마쳤으면 권하지 않음
		list.append({
			"key": "affair_research",
			"title": "실학 학문 연구",
			"text": "규장각과 수원향교 유생들에게 새로운 실학 연구를 명하시옵소서.\n거중기, 농서, 병법 등을 연구하면 축성과 농업 생산이 비약적으로 발전하옵니다.",
			"btn": "📖 실학 연구",
			"kind": "modal",
			"target": "research",
			"prio": 4
		})

	# 8. 재정(금) 및 군량(쌀) 정무
	if sim != null:
		if sim.gold < 400:
			list.append({
				"key": "affair_gold_low",
				"title": "호조 재정 확충",
				"text": "나라 곳간(금)이 부족하옵니다! 저잣거리 상업을 진흥하고 사대문 교역로를 열어야 합니다.\n[조세]에서 탕평 세율을 조율하시옵소서.",
				"btn": "⚖️ 조세 조율",
				"kind": "modal",
				"target": "tax",
				"prio": 7
			})
		if sim.rice < 400:
			list.append({
				"key": "affair_rice_low",
				"title": "대유둔전 군량 확보",
				"text": "군량미가 부족하여 백성과 군졸이 주리고 있사옵니다!\n성 밖 대유평에 둔전을 넓히고 수로를 내어 곡식을 비축하시옵소서.",
				"btn": "🌾 둔전 만들기",
				"kind": "tool",
				"target": "zone_agr",
				"prio": 7
			})

	# 9. 치수 방재 (여름 장마 대비)
	if s_idx == 1 and sim != null and sim.flood_defense < 60 and not _levee_started():
		list.append({
			"key": "affair_levee",
			"title": "수원천 석축 제방 축조",
			"text": "여름 장마철에 수원천이 범람하면 애써 지은 민가와 논밭이 침수되옵니다.\n[국책대역사]에서 '수원천 석축 제방'을 서둘러 착공하시옵소서.",
			"btn": "🏗️ 국책대역사",
			"kind": "modal",
			"target": "mega_projects",
			"prio": 8
		})

	# 우선순위 높은 순 정렬
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("prio", 0)) > int(b.get("prio", 0))
	)
	# [dismiss 필터]: 플레이어가 "알겠어요"로 무시한 key는 목록에서 제외
	# 단, prio 11+는 긴급 상황이므로 dismiss 후에도 상태가 다시 바뀌면 새 key로 재생성됨
	list = list.filter(func(a: Dictionary) -> bool:
		var k: String = str(a.get("key", ""))
		return not _dismissed_affairs.has(k)
	)
	return list

func _switch_tab(tab_name: String, by_user: bool = false) -> void:
	_current_tab = tab_name
	if tab_name == "quest":
		_show_quest_tab()
	else:
		_show_affairs_tab(0, by_user)

func _update_tab_buttons() -> void:
	if _tab_quest_btn == null or _tab_affairs_btn == null:
		return
	var count: int = _affairs_list.size()
	if count > 0:
		_tab_affairs_btn.text = "🏛️ 정무 조언 (%d)" % count
	else:
		_tab_affairs_btn.text = "🏛️ 정무 조언"

	if _current_tab == "quest":
		_set_btn_style(_tab_quest_btn, Color(0.18, 0.44, 0.22))
		_set_btn_style(_tab_affairs_btn, Color(0.40, 0.35, 0.30))
	else:
		_set_btn_style(_tab_quest_btn, Color(0.40, 0.35, 0.30))
		_set_btn_style(_tab_affairs_btn, Color(0.65, 0.25, 0.15))

## by_user: 플레이어가 [정무 조언] 탭을 직접 눌렀을 때만 true
func _show_affairs_tab(idx: int = 0, by_user: bool = false) -> void:
	if not GameSettings.is_judge_advice_enabled():
		if _box != null: _box.visible = false
		return
	_current_tab = "affairs"
	_mode = "affairs"
	_affairs_list = _collect_affairs_advices()
	_affair_idx = clampi(idx, 0, maxi(0, _affairs_list.size() - 1))
	_update_tab_buttons()

	if _affairs_list.is_empty():
		# PORT-TRACE [할 일 없으면 안 뜸]: 사용자 요청 — "할 일이 없으면 김판관 팝업이 안 떴으면".
		# 인재 천거·어명 완수 뒤 등 저절로 정무 조언을 열었는데 목록이 비었으면 "평온" 화면을 띄우지 않고 조용히 접는다.
		# (플레이어가 탭을 직접 누르면 그대로 "평온"을 보여 준다)
		if not by_user:
			_hide_when_idle()
			return
		_page_lbl.text = "🏛️ 정무 조언 (평온)"
		_say("전하, 현재 시급히 결단하실 정무 과제는 없사옵니다.\n수원 화성 성곽 축성과 신도시 번영에 힘써 주시옵소서!")
		_set_buttons(false, false, false, true, false)
		if _prev_advice_btn: _prev_advice_btn.visible = false
		if _next_advice_btn: _next_advice_btn.visible = false
		return

	var cur: Dictionary = _affairs_list[_affair_idx]
	_advice_now = cur
	if str(cur.get("key", "")).begins_with("affair_pop_cap") and sim != null:
		_pop_cap_seen_turn = sim.turn
	_page_lbl.text = "🏛️ %s (%d/%d)" % [str(cur.get("title", "정무 조언")), _affair_idx + 1, _affairs_list.size()]
	_say(str(cur.get("text", "")))

	var btn_txt: String = str(cur.get("btn", ""))
	_set_buttons(false, btn_txt != "", false, true, false)
	if btn_txt != "" and _tool_btn != null:
		_tool_btn.text = btn_txt
	if _decline_btn != null:
		_decline_btn.visible = str(cur.get("cand", "")) != ""
	if _prev_advice_btn != null:
		_prev_advice_btn.visible = (_affairs_list.size() > 1)
	if _next_advice_btn != null:
		_next_advice_btn.visible = (_affairs_list.size() > 1)

func _show_quest_tab() -> void:
	_current_tab = "quest"
	_update_tab_buttons()
	if _prev_advice_btn != null:
		_prev_advice_btn.visible = false
	if _next_advice_btn != null:
		_next_advice_btn.visible = false

	if quests != null and quests.is_all_completed:
		_on_all_done()
	elif quests != null:
		_show_step(quests.get_current_quest())
	else:
		_mode = "step"

## [등용 안 함]: 이 인재를 건의 목록에서 영구히 뺀다(조정 인사 창에서 직접 등용하는 것은 그대로 가능)
func _on_decline_scholar() -> void:
	var cid: String = str(_advice_now.get("cand", ""))
	if cid == "":
		return
	_dismissed_affairs["affair_scholar_" + cid] = true
	_affairs_list = _collect_affairs_advices()
	if _affairs_list.is_empty():
		_show_affairs_tab(0)
	else:
		_show_affairs_tab(clampi(_affair_idx, 0, _affairs_list.size() - 1))

func _on_prev_advice() -> void:
	if _affairs_list.is_empty():
		return
	_affair_idx = (_affair_idx - 1 + _affairs_list.size()) % _affairs_list.size()
	_show_affairs_tab(_affair_idx)

func _on_next_advice() -> void:
	if _affairs_list.is_empty():
		return
	_affair_idx = (_affair_idx + 1) % _affairs_list.size()
	_show_affairs_tab(_affair_idx)

func _set_btn_style(btn: Button, col: Color) -> void:
	if btn == null:
		return
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(6)
	st.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate() as StyleBoxFlat
	sh.bg_color = col.lightened(0.18)
	btn.add_theme_stylebox_override("hover", sh)

func _advise_for_turn(season_index: int, year: int) -> void:
	# 근대화 시대(1820~)에는 1800년 본편의 시기별 조언 대신 근대화 업무를 안내한다
	if ModernizationManager.is_active():
		_push_advice("modern_intro",
			"전하, 1820년 근대화의 시대가 열렸사옵니다! 이제 해야 할 일이 바뀌었사옵니다.
① [정무 → 🔬 서학 진흥]에서 근대 과학 연구를 착수하시고, 서양 서적과 해외 유학으로 연구 속도를 높이시옵소서.
② 서양 열강이 1~2년마다 화성을 침공하옵니다. 성곽 방호·장용영·순라청으로 국방력을 키우시옵소서.
③ 첫 침공을 격퇴하면 [정무 → 🌐 외교]와 사대문에서 국제외교 회담을 열 수 있사옵니다.",
			"🔬 서학 진흥 열기", "modal", "west_promo")
		return
	# 1) 지금 벌어진 정무 과제 — 가장 먼저
	if court != null and court.tiger.get("active", false):
		_push_advice("tiger_%d_%d" % [year, season_index],
			"큰일이에요! 팔달산에 호랑이(맹호)가 나타나 백성들이 무서워해요.\n[포호책]에서 착호군을 보내거나, 산을 개간해 호랑이를 쫓아내요.",
			"🐯 포호책 열기", "modal", "tiger")
	if court != null and court.eulmyo.get("active", false):
		_push_advice("eulmyo",
			"1795년 을묘년이에요! 정조 임금님께서 어머니 혜경궁 홍씨의 회갑(환갑) 잔치를 화성행궁 봉수당에서 여세요. 이것이 '을묘원행'이에요.\n행차 길에 백성들이 징을 치며 억울함을 호소(격쟁)해요. [을묘원행]에서 들어 주세요.",
			"🎉 을묘원행 열기", "modal", "eulmyo")
	var p_active: bool = court != null and (court.crown_prince.get("invested", false) or court.crown_prince.get("education", 0) > 0)
	if sim != null and sim.crown_prince_manager != null and sim.crown_prince_manager.has_method("is_education_active") and sim.crown_prince_manager.is_education_active():
		p_active = true
	if year >= 1790 and not p_active and not CrownPrinceEducationManager.prince_affairs_closed(year): # 1800년 엔딩(순조 즉위) 뒤에는 권하지 않음
		_push_advice("prince",
			"1790년, 원자(훗날의 순조 임금)께서 태어나셨어요!\n[세자서연]에서 훌륭한 스승을 정해 세자로 책봉해 주세요.",
			"👑 세자서연 열기", "modal", "crown_prince")

	# 2) 해마다 할 일: 새해 현륭원 참배 (현륭원은 1789년에 조성)
	var t_visited: bool = court != null and (court.hyoryungwon.get("visited", false) or CityStats.get_hyeonryungwon_visits() > 0 or court.hyeonryungwon_visits > 0)
	if year >= 1789 and season_index == 0 and not t_visited:
		_push_advice("hyo_%d" % year,
			"새해가 밝았어요. 정조 임금님은 해마다 아버지 사도세자가 잠든 현륭원을 찾아 참배하셨어요.\n[현륭원]에서 친림 참배를 하면 민심과 왕권이 올라가요.",
			"🙏 현륭원 친림", "modal", "hyoryungwon")

	# 3) 서장대 야조 훈련
	if grid != null and grid.count_completed("seojangdae") > 0:
		var cd_m: int = sim.seojangdae_drill_cd_months if sim != null else 0
		if cd_m <= 0:
			_push_advice("seojangdae_drill_%d_%d" % [year, season_index],
				"팔달산 서장대에서 장용영 군사들의 야간 군사 훈련(야조)을 거행할 때입니다!\n[서장대 훈련]으로 군세를 떨치고 국방력을 대폭 신장시키십시오.",
				"⚔️ 서장대 훈련", "modal", "seojangdae_drill")

	# 4) 도적 소탕 및 치안 방비
	var b_act: bool = (sim != null and sim.bandit_active) or (sim != null and sim.bandit_manager != null and (sim.bandit_manager.has_method("has_active_bandits") and sim.bandit_manager.has_active_bandits()))
	if b_act:
		_push_advice("bandit_active_%d_%d" % [year, season_index],
			"수원 화성 외곽에 도적 무리가 출몰하여 양민을 약탈하고 있습니다!\n[도적 소탕]을 결단하여 순라군을 급파하고 소굴을 토벌하십시오.",
			"🛡️ 도적 소탕", "modal", "bandit")

	# 5) 역사 연표
	if year >= 1789:
		_push_advice("y1789",
			"1789년, 사도세자의 묘를 수원 화산으로 옮겨 '현륭원'이라 했어요. 그래서 원래 수원 고을은 팔달산 아래 새 터로 옮겨 왔답니다.\n새 수원을 멋지게 가꿔 봐요!")
	if year >= 1793:
		_push_advice("y1793",
			"1793년, 수원이 '화성유수부'로 높아졌어요! 곧 성을 쌓을 때가 와요.\n금과 쌀을 넉넉히 모아 두세요. 세금은 [조세]에서 살펴볼 수 있어요.",
			"⚖️ 조세 보기", "modal", "tax")
	var wall_complete: bool = bool((sim and sim.fortress_progress >= 100) or (grid and (grid.fortress_progress >= 100 or (grid.has_method("is_wall_loop_completed") and grid.is_wall_loop_completed()))) or (quests and quests.has_method("is_quest_completed") and quests.is_quest_completed("wall_build")))
	if year >= 1794 and not wall_complete:
		_push_advice("y1794",
			"1794년 봄, 드디어 화성 축성이 시작됐어요! 이때도 사대문(장안문·팔달문 등)을 먼저 세우고 성곽을 이어 쌓았어요. 정약용이 만든 거중기로 무거운 돌을 척척 들어 올렸지요.\n[화성성곽]으로 성을 쌓고, [국책대역사]도 착공해 보세요.",
			"🧱 성곽 쌓기", "tool", "wall")
	if year >= 1795 and grid != null and grid.count_buildings("manseokgeo") == 0:
		_push_advice("y1795_manseok",
			"1795년에는 성 북쪽에 큰 저수지 '만석거'를 만들고, 그 물로 국영 농장 '대유평'을 일궜어요.\n성 밖 들판에 만석거를 지어 보세요. 가까운 논밭까지 수로가 저절로 생겨요!",
			"💧 만석거 짓기", "tool", "manseokgeo")
	if year >= 1796:
		if wall_complete:
			_push_advice("y1796",
				"1796년 가을, 실제 역사에서도 이때 화성이 완성되었어요! 2년 9개월 만이었답니다.\n이제 이 큰 공사를 기록으로 남길 차례예요.")
		else:
			_push_advice("y1796",
				"1796년은 실제로 화성이 완공된 해예요. 아직 성곽이 남았다면 서둘러 쌓아요!",
				"🧱 성곽 쌓기", "tool", "wall")
	if year >= 1796 and court != null and court.uigwe_block_reason("wonhaeng") == "":
		_push_advice("uigwe_wonhaeng",
			"을묘원행의 모든 과정을 그림과 글로 기록한 책 《원행을묘정리의궤》를 펴낼 때예요!\n'정리자'라는 금속활자로 찍어 여러 곳에 나눠 보관했답니다.",
			"📚 의궤 편찬", "modal", "uigwe")
	if year >= 1796 and court != null and court.uigwe_block_reason("seongyeok") == "":
		_push_advice("uigwe_seongyeok",
			"《화성성역의궤》를 펴내요! 화성을 어떻게 지었는지 설계도, 일꾼 이름, 들어간 돈까지 모두 적은 책이에요.\n이 책 덕분에 오늘날에도 화성을 옛 모습대로 복원할 수 있답니다.",
			"📚 의궤 편찬", "modal", "uigwe")
	if year >= 1797:
		_push_advice("renaissance_pop",
			"대조선 문예 부흥(참 결말)을 보려면 성곽·학문·민심 같은 여러 조건에 더해 인구가 100만이 넘어야 해요!\n민가를 늘리고 우물·멸화군·진휼소로 백성이 살기 좋게 가꿔 주세요.",
			"👥 인구 작업 보기", "modal", "stat_pop")
	if year >= 1798:
		_push_advice("y1798",
			"1798년에는 '만년제', 1799년에는 '축만제(서호)'라는 저수지를 더 만들어 둔전에 물을 댔어요.\n성 밖에 저수지와 둔전을 더 넓혀 봐요.",
			"🌊 저수지 짓기", "tool", "reservoir")

	# 6) 지금 상황
	var next_g := _get_next_unbuilt_gate()
	if not next_g.is_empty():
		_push_advice("gate_seq_" + String(next_g.get("id", "")),
			"화성 축성의 요체는 사대문을 든든히 세우는 것입니다!\n이제 [%s]을(를) 축조하여 관문을 여십시오." % next_g.get("name", "성문"),
			"🚪 성문 세우기", "tool", "gate")
	if season_index == 1 and sim != null and sim.flood_defense < 50 and not _levee_started():
		_push_advice("flood_%d" % year,
			"여름 장마철이에요! 수원천이 넘쳐 논밭과 집이 잠길 수 있어요.\n[국책대역사]에서 '수원천 석축 제방'을 착공해 두면 든든해요.",
			"🏗️ 국책대역사", "modal", "mega_projects")
	if sim != null and sim.gold < 300:
		_push_advice("gold_%d" % year,
			"나라 곳간(금)이 거의 비었어요!\n저잣거리를 늘리고 성문 쪽 교역로를 열어 보세요. [조세]에서 세금도 살펴봐요.",
			"⚖️ 조세 보기", "modal", "tax")
	if sim != null and sim.rice < 300:
		_push_advice("rice_%d" % year,
			"쌀이 부족해요! 백성과 군사가 배고파해요.\n[대유둔전]으로 논밭을 더 일구고, 저수지 곁이라면 수로로 물을 받아 소출이 늘어나요.",
			"🌾 둔전 만들기", "tool", "zone_agr")
	if sim != null and sim.loyalty < 45:
		_push_advice("loyal_%d" % year,
			"백성들의 마음(민심)이 떠나고 있어요.\n[조세]에서 세금을 조금 낮추거나, 현륭원 참배로 효심을 보여 주세요.",
			"⚖️ 조세 보기", "modal", "tax")

func _show_next_advice() -> void:
	if not GameSettings.is_judge_advice_enabled():
		if _box != null: _box.visible = false
		return
	while not _advice_queue.is_empty():
		var cand: Dictionary = _advice_queue.pop_front()
		if _advice_expired(cand):
			continue # 큐에 대기 중인 사이에 이미 완공/착공되었으면 스킵
		_advice_now = cand
		_mode = "advice"
		if _is_user_folded:
			# 사용자가 접어두었으면 강제로 화면을 덮지 않고 재오픈 버튼에 알림 배지만 표시
			if _reopen_btn != null:
				_reopen_btn.text = "🧑‍⚖️ %s (새 조언 💡)" % _gshort()
			return
		_unfold()
		var btn: String = _advice_now.get("btn", "")
		_set_buttons(false, btn != "", false, true, true)
		if btn != "" and _tool_btn != null:
			_tool_btn.text = btn
		if _next_btn != null:
			_next_btn.text = "알겠어요 ▶"
		if _page_lbl != null:
			var yr: int = court.current_year if court != null else 1789
			_page_lbl.text = "%s의 조언 (%d년)" % [_gshort(), yr]
		_say(_advice_now.get("text", ""))
		return

func _do_advice_action() -> void:
	var kind: String = _advice_now.get("kind", "")
	var target: String = _advice_now.get("target", "")
	if kind == "modal" and panels:
		if _dim != null:
			_dim.visible = false # 팝업이 어두운 막 아래에 갇히지 않게
		panels.open_action_modal(target)
	elif kind == "tool" and panels:
		panels.select_tool(target)
		var pos: Vector2i = quests.find_hint_position(target) if quests else Vector2i(-1, -1)
		if pos.x >= 0 and hud:
			hud.jump_to_grid(pos)
			_say("좋아요! 추천 자리로 화면을 옮겼어요. 여기에 지어 보세요.")
			hud._show_toast("추천 위치로 이동했습니다. 이곳에 건설하십시오!", "📍")
		else:
			_say("좋아요! 이제 지도에서 알맞은 땅을 골라 주세요.")

## 근대화 시대 정무 조언: 서학 진흥·국방·외교
func _collect_modern_advices() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var mm: ModernizationManager = ModernizationManager.instance
	if mm.current_field == "" and mm.western_progress() < 100:
		list.append({"key": "modern_research", "title": "근대 과학 연구 착수",
			"text": "지금 진행 중인 근대 과학 연구가 없사옵니다.
[서학 진흥]에서 포술·화학·증기기관·의학·측량 가운데 하나를 골라 착수하시옵소서. 연구비는 매달 %d냥이옵니다." % ModernizationManager.RESEARCH_TURN_COST,
			"btn": "🔬 서학 진흥", "kind": "modal", "target": "west_promo", "prio": 9})
	elif mm.research_paused:
		list.append({"key": "modern_research_paused", "title": "근대 과학 연구 중단",
			"text": "국고가 모자라 근대 과학 연구가 멈췄사옵니다. 매달 %d냥이 필요하옵니다.
조세를 조율하시거나 외교 회담으로 차관을 들여오시옵소서." % ModernizationManager.RESEARCH_TURN_COST,
			"btn": "⚖️ 조세 조율", "kind": "modal", "target": "tax", "prio": 10})
	if mm.speed_mult() < 3.0:
		list.append({"key": "modern_speed", "title": "연구 속도 높이기",
			"text": "서학 연구가 더디옵니다(현재 %.1f배). 서양 서적을 들여오시거나, 학문이 뛰어난 인재를 해외 유학 보내시옵소서.
유학생은 %d개월 뒤 돌아와 능력만큼 연구를 앞당기옵니다." % [mm.speed_mult(), ModernizationManager.STUDY_TURNS],
			"btn": "🔬 서학 진흥", "kind": "modal", "target": "west_promo", "prio": 6})
	var mon: int = time_manager.current_month if time_manager != null else 1
	var yr_now: int = time_manager.current_year if time_manager != null else 1820
	if yr_now == ModernizationManager.JAPAN_INVASION_YEAR - 1:
		list.append({"key": "modern_japan_warn", "title": "일본의 대규모 침공 경고",
			"text": "전하, 일본이 군함과 대군을 모으고 있다는 첩보이옵니다! 내년(1875년) 정초에 평소의 두 배가 넘는 군세로 쳐들어올 것이옵니다.
현재 아군 국방력은 %d(동맹 원군 %d 포함 시 %d)이옵니다. 성곽을 보수하고 신식 군대를 키우시옵소서." % [mm.defense_power(), mm.ally_reinforcement(), mm.defense_power() + mm.ally_reinforcement()],
			"btn": "🛡️ 성곽 보수", "kind": "modal", "target": "wall_repair", "prio": 13})
	elif yr_now == ModernizationManager.JAPAN_TREATY_YEAR - 1 and mm.japan_1875_done and not mm.treaty_1876_done:
		list.append({"key": "modern_treaty_warn", "title": "일본의 조약 요구 예고",
			"text": "내년(1876년) 정초에 일본 전권대신이 강화도에 와서 조약을 요구할 것이옵니다.
운요호 사건, 영사재판권, 무관세, 해안 측량, 일본 화폐 유통, 양곡 유출, 수신사, 왜양일체론을 미리 공부해 두시옵소서. 한 번이라도 잘못 답하면 나라를 잃사옵니다.",
			"btn": "", "kind": "", "target": "", "prio": 13})
	elif mon == 12:
		list.append({"key": "modern_war_%d" % yr_now, "title": "내년 열강 침공 대비",
			"text": "새해 정초에 열강이 쳐들어올 확률은 %d%%이옵니다. (외교 신뢰도 %d/10 — 신뢰도가 높을수록 줄어드옵니다)
현재 아군 국방력 %d, 동맹 원군 %d이옵니다." % [int(round(mm.invasion_chance() * 100.0)), mm.trust, mm.defense_power(), mm.ally_reinforcement()],
			"btn": "🌐 외교", "kind": "modal", "target": "diplomacy", "prio": 10})
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	if um != null and um.heritage_condition < 70.0:
		list.append({"key": "modern_heritage_%d" % int(um.heritage_condition / 10.0), "title": "화성 문화재 훼손",
			"text": "성곽과 사대문이 많이 낡고 부서졌사옵니다! (문화재 보존도 %d%%)\n문화재 보존도는 1945년 결산의 30%%를 차지하옵니다. [문화재 보수]로 되살리시옵소서." % int(um.heritage_condition),
			"btn": "🧱 문화재 보수", "kind": "modal", "target": "wall_repair", "prio": 9})
	var pol: ModernPoliticsManager = ModernPoliticsManager.instance
	if pol != null and not pol.decided and yr_now == ModernPoliticsManager.DECISION_YEAR - 1:
		list.append({"key": "modern_1897_warn", "title": "정치체제 결단 예고",
			"text": "내년(1897년)에 왕조를 이어 갈지, 현대 정치체제로 바꿀지 정하셔야 하옵니다.\n현대 정치체제를 고르시면 민심이 %d 이상이어야 대통령으로 통치를 이어 가실 수 있사옵니다. (현재 민심 %d)" % [ModernPoliticsManager.ELECTION_LOYALTY, sim.loyalty],
			"btn": "", "kind": "", "target": "", "prio": 12})
	if ModernPoliticsManager.is_presidential() and not pol.pending.is_empty():
		list.append({"key": "modern_proposals_%d" % sim.turn, "title": "국정 건의 검토",
			"text": "국회·행정 각부의 건의 %d건이 대통령의 결재를 기다리고 있사옵니다." % pol.pending.size(),
			"btn": "📜 국정 건의", "kind": "modal", "target": "proposals", "prio": 8})
	if ModernPoliticsManager.is_presidential() and yr_now == pol.next_election - 1:
		list.append({"key": "modern_election_%d" % pol.next_election, "title": "대통령 선거 예고",
			"text": "내년(%d년)이 대통령 선거이옵니다. 민심이 %d 이상이어야 연임하실 수 있사옵니다. (현재 민심 %d)" % [pol.next_election, ModernPoliticsManager.ELECTION_LOYALTY, sim.loyalty],
			"btn": "", "kind": "", "target": "", "prio": 11})
	if um != null and um.pollution_penalty > 0:
		list.append({"key": "modern_pollution_%d" % sim.turn, "title": "공장 매연 민원",
			"text": "공업지역 공장의 매연이 택지와 상가까지 퍼져 백성의 원성이 높사옵니다! (오염된 칸 %d개, 매달 민심 -%d)
공장 가까이의 주거·상업 구역을 옮기시거나, 공장과 주거지 사이를 %d칸 넘게 띄우시옵소서." % [um.polluted_cells, um.pollution_penalty, UrbanEvolutionManager.POLLUTION_RADIUS],
			"btn": "", "kind": "", "target": "", "prio": 9})
	if mm.diplomacy_unlocked and mm.diplomacy_turns_left() == 0:
		list.append({"key": "modern_diplomacy_%d" % sim.turn, "title": "국제외교 회담",
			"text": "열강의 사절과 회담할 수 있사옵니다. 차관, 신식 무기, 기술 교류 가운데 하나를 얻을 수 있사옵니다.
서학 진척도와 학문력이 높을수록 회담이 성사되기 쉽사옵니다.",
			"btn": "🌐 외교", "kind": "modal", "target": "diplomacy", "prio": 7})
	return list

## [완료 보고 김판관 전담 엔진]
## 학문 연구, 세자 교육, 국책 대역사 완공, 주요 건물 완성을 상단 배너나 팝업 없이 김판관이 전담 보고한다.
func report_building_completed(building: String) -> void:
	var raw_key: String = building.strip_edges().to_lower()
	if raw_key.is_empty():
		return
	# 일반 주거/상업/농업/공방 구획 타일 및 도로는 완공 보고 대상 제외
	if raw_key.begins_with("res") or raw_key.begins_with("com") or raw_key.begins_with("agr") or raw_key.begins_with("ind") or raw_key in ["road", "stone_road", "canal"]:
		return

	# 접미사 및 별칭 정규화
	var base_key: String = raw_key
	if base_key.ends_with("_site"):
		base_key = base_key.trim_suffix("_site")
	elif base_key.ends_with("_range"):
		base_key = base_key.trim_suffix("_range")
	elif base_key.ends_with("_wall"):
		base_key = base_key.trim_suffix("_wall")

	if base_key in ["banghwasuryujeong", "dongbuk_gakru"]:
		base_key = "banghwasuryu"
	elif base_key in ["dongjangdae"]:
		base_key = "yeonmudae"
	elif base_key in ["hwahongmun", "hwahong_mun", "buksumun"]:
		base_key = "hwahong"
	elif base_key in ["namsumun", "namsu_mun"]:
		base_key = "namsu"
	elif base_key in ["maehyang_gyo", "maehwang_gyo"]:
		base_key = "maehyang_gyo"

	# 고유 랜드마크는 1게임 1회만 완공 보고
	if _reported_unique_buildings.has(base_key):
		return
	if base_key in ["haenggung", "gwana", "jongnu", "seojangdae", "yeonmudae", "banghwasuryu", "yongyeon", "bongdon", "manseokgeo", "hyanggyo", "yeonghwajeong", "chukmanje"]:
		_reported_unique_buildings[base_key] = true

	var b_name: String = ""
	if BUILDING_NAMES.has(base_key):
		b_name = str(BUILDING_NAMES[base_key])
	elif BUILDING_NAMES.has(raw_key):
		b_name = str(BUILDING_NAMES[raw_key])
	else:
		b_name = InspectNarrativeGenerator.get_korean_name(base_key, InspectNarrativeGenerator.get_korean_name(raw_key, "화성 시설"))

	# Zero-English 2중 방어선: b_name에 영문 알파벳이 남아있는지 검사
	var has_alpha: bool = false
	for code in b_name.to_utf8_buffer():
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			has_alpha = true
			break
	if has_alpha:
		b_name = InspectNarrativeGenerator.get_korean_name(base_key, "화성 시설")
		has_alpha = false
		for code2 in b_name.to_utf8_buffer():
			if (code2 >= 65 and code2 <= 90) or (code2 >= 97 and code2 <= 122):
				has_alpha = true
				break
		if has_alpha:
			b_name = "화성 시설"

	var text: String = ""
	if BUILDING_COMPLETION_TALK.has(base_key):
		text = str(BUILDING_COMPLETION_TALK[base_key])
	elif BUILDING_COMPLETION_TALK.has(raw_key):
		text = str(BUILDING_COMPLETION_TALK[raw_key])
	else:
		text = "전하, [%s]이(가) 웅장하게 완공되었사옵니다!\n백성들이 기뻐하고 고을의 위용이 더욱 높아졌사옵니다." % b_name

	_show_completion_report(b_name + " 완공", text)

func report_mega_project_completed(project_name: String) -> void:
	var clean_name: String = project_name.strip_edges()
	# reward_msg 문장이 들어왔다면 국책 대역사 목록에서 이름 역조회
	if clean_name.contains("되었습니다") or clean_name.contains("완결") or clean_name.contains("연결"):
		if sim != null:
			for p in sim.mega_projects:
				if p.get("reward_msg", "") == clean_name:
					clean_name = str(p.get("name", "국책 대역사"))
					break
	# 영문 ID가 들어왔을 경우
	if sim != null:
		for p2 in sim.mega_projects:
			if p2.get("id", "") == clean_name:
				clean_name = str(p2.get("name", clean_name))
				break
	# Zero-English 검사
	var has_alpha: bool = false
	for code in clean_name.to_utf8_buffer():
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			has_alpha = true
			break
	if has_alpha:
		clean_name = InspectNarrativeGenerator.get_korean_name(clean_name, "화성 국책 대역사")

	var text: String = "전하, 국책 대역사 [%s]이(가) 마침내 완공되었사옵니다!\n백성들의 노고와 조정의 지혜가 결실을 맺어 화성의 번영과 국력이 크게 도약하였사옵니다." % clean_name
	_show_completion_report(clean_name + " 완공", text, "🏗️ 국책대역사 보기", "modal", "mega_projects")

func _on_research_completed(tech_id: String) -> void:
	var info: Dictionary = sim.tech_tree.get_tech_info(tech_id) if sim.tech_tree != null else {}
	if info.is_empty():
		return
	var parts: PackedStringArray = str(info.get("desc", "")).split(" — ")
	var what: String = str(parts[0])
	var effect: String = str(parts[1]) if parts.size() > 1 else what
	var t_name: String = str(info.get("name", tech_id))
	var text: String = "전하, 실학 연구 [%s]가 완수되었사옵니다!\n%s\n이제 이렇게 좋아졌사옵니다: %s" % [t_name, what, effect]
	_show_completion_report("실학 연구 완수", text, "📖 실학 연구 보기", "modal", "research")

func _on_prince_completed() -> void:
	var text: String = "전하, 세자께서 제왕학 서연을 모두 마치셨사옵니다!\n세자 교육이 100에 도달하여 왕실의 만년 대계를 굳건히 세우고 후계 걱정을 덜었사옵니다."
	_show_completion_report("세자 서연 완수", text, "👑 세자서연 보기", "modal", "crown_prince")

func _show_completion_report(title: String, text: String, btn_text: String = "", kind: String = "", target: String = "") -> void:
	if not GameSettings.is_judge_advice_enabled():
		if _box != null: _box.visible = false
		return
	_mode = "report"
	_is_user_folded = false
	_unfold()
	_advice_now = {"kind": kind, "target": target}
	if _page_lbl != null:
		_page_lbl.text = "📜 완료 보고: " + title
	_say(text)
	_set_buttons(false, btn_text != "", false, true, true)
	if btn_text != "" and _tool_btn != null:
		_tool_btn.text = btn_text
	if _next_btn != null:
		_next_btn.text = "확인 ▶"
	_auto_close = 0.0

func _report(key: String, text: String, btn: String, kind: String, target: String) -> void:
	_show_completion_report(key, text, btn, kind, target)

## 저장을 불러온 뒤: 지난 해들의 조언이 한꺼번에 쏟아져 팝업이 계속 이어지던 것을 막는다.
## 지금까지의 연표 조언은 이미 본 것으로 치고 대기열을 비운 뒤 현재 교지 안내로 돌아간다.
func sync_after_load() -> void:
	_advice_queue.clear()
	_advice_now = {}
	_auto_close = 0.0
	_advice_cooldown = 0.0
	_advice_seen["intro_done"] = true
	if _dim:
		_dim.visible = false
	if court != null and sim != null and grid != null and time_manager != null:
		var si: int = maxi(0, ["봄", "여름", "가을", "겨울"].find(time_manager.get_current_season()))
		_advise_for_turn(si, time_manager.current_year)
		_advice_queue.clear()
	if quests != null and quests.is_all_completed:
		_mode = "done"
		_fold()
	elif sim != null and (sim.current_year >= 1800 or sim.fortress_progress >= 100):
		_mode = "done"
		_fold()
	else:
		_resume_after_talk()
	_advice_cooldown = 0.0

## 조언/칭찬을 다 본 뒤 원래 탭(어명 또는 정무 조언)으로 돌아간다
## "알겠어요"를 눌렀을 때 정무 조언을 연속으로 쏟아내지 않도록,
## affairs 탭은 자동으로 재열지 않고 어명 탭(또는 완료)으로만 복귀한다.
## 플레이어가 정무 조언을 더 보고 싶으면 직접 탭을 클릭하면 된다.
func _resume_after_talk() -> void:
	_auto_close = 0.0
	_advice_now = {}
	_advice_cooldown = SERIALIZE_COOLDOWN_DELAY
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()

	# affairs 탭에서 "알겠어요"를 눌러도 다음 조언을 자동으로 열지 않는다.
	# 퀘스트(어명)가 남아있으면 어명 탭으로 복귀한다.
	if quests != null and not quests.is_all_completed:
		_current_tab = "quest"
		_show_step(quests.get_current_quest())
	elif not _affairs_list.is_empty():
		# 정무 조언이 있지만 자동으로 열지 않음 — 배지만 표시, 접힘 유지
		_current_tab = "quest"
		_mode = "done"
		_page_lbl.text = "🏛️ 정무 조언 %d건 대기 중" % _affairs_list.size()
		_say("전하, 처리하실 정무 과제가 있사옵니다.\\n[🏛️ 정무 조언] 쪽을 열어 확인하시옵소서.")
		_set_buttons(false, false, false, true, false)
		_update_tab_buttons()
	else:
		_mode = "done"
		_page_lbl.text = "모든 과업 완수"
		_say(FINAL_TALK)
		_set_buttons(false, false, false, true, false)

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP # 인사 중엔 지도 클릭을 막는다
	add_child(_dim)

	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.anchor_left = 0.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 14.0
	_box.offset_right = 640.0
	_box.offset_top = -312.0
	_box.offset_bottom = -88.0 # 하단 도크 바 위
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.87, 0.98) # 한지
	sb.border_color = Color(0.55, 0.36, 0.14)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.set_content_margin_all(10)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_box.add_child(hb)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(left)
	_portrait = GuidePortrait.new()
	_portrait.court = court
	left.add_child(_portrait)
	var name_lbl := Label.new()
	_name_lbl = name_lbl
	name_lbl.text = _gname()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color("5a2d0c"))
	name_lbl.add_theme_font_size_override("font_size", 14)
	left.add_child(name_lbl)
	var title_lbl := Label.new()
	title_lbl.text = GUIDE_TITLE
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color("8a6a2a"))
	title_lbl.add_theme_font_size_override("font_size", 11)
	left.add_child(title_lbl)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hb.add_child(right)

	# [이분화 탭 바] 어명 교지와 정무 조언을 명확히 분리
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", 6)
	right.add_child(tab_bar)

	_tab_quest_btn = _make_btn("📜 어명 교지", Color(0.18, 0.44, 0.22))
	_tab_quest_btn.custom_minimum_size = Vector2(110, 28)
	_tab_quest_btn.add_theme_font_size_override("font_size", 12)
	_tab_quest_btn.pressed.connect(Callable(self, "_switch_tab").bind("quest"))
	tab_bar.add_child(_tab_quest_btn)

	_tab_affairs_btn = _make_btn("🏛️ 정무 조언", Color(0.52, 0.35, 0.16))
	_tab_affairs_btn.custom_minimum_size = Vector2(130, 28)
	_tab_affairs_btn.add_theme_font_size_override("font_size", 12)
	_tab_affairs_btn.pressed.connect(Callable(self, "_switch_tab").bind("affairs", true))
	tab_bar.add_child(_tab_affairs_btn)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.custom_minimum_size = Vector2(440, 84)
	_text_lbl.add_theme_color_override("font_color", Color("2a1a0c"))
	_text_lbl.add_theme_font_size_override("font_size", 15)
	right.add_child(_text_lbl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 6)
	right.add_child(btns)

	_page_lbl = Label.new()
	_page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_lbl.add_theme_color_override("font_color", Color("8a6a2a"))
	_page_lbl.add_theme_font_size_override("font_size", 12)
	btns.add_child(_page_lbl)

	_prev_advice_btn = _make_btn("◀ 이전", Color(0.38, 0.33, 0.28))
	_prev_advice_btn.visible = false
	_prev_advice_btn.pressed.connect(Callable(self, "_on_prev_advice"))
	btns.add_child(_prev_advice_btn)

	_next_advice_btn = _make_btn("다음 ▶", Color(0.38, 0.33, 0.28))
	_next_advice_btn.visible = false
	_next_advice_btn.pressed.connect(Callable(self, "_on_next_advice"))
	btns.add_child(_next_advice_btn)

	_skip_btn = _make_btn("건너뛰기", Color(0.45, 0.40, 0.34))
	_skip_btn.pressed.connect(_end_intro)
	btns.add_child(_skip_btn)
	_tool_btn = _make_btn("🔨 도구 고르기", Color(0.50, 0.12, 0.08))
	_tool_btn.pressed.connect(_on_tool)
	btns.add_child(_tool_btn)
	_where_btn = _make_btn("📍 어디에?", Color(0.10, 0.30, 0.45))
	_where_btn.pressed.connect(_on_where)
	btns.add_child(_where_btn)
	_decline_btn = _make_btn("🙅 등용 안 함", Color(0.38, 0.33, 0.28))
	_decline_btn.visible = false
	_decline_btn.tooltip_text = "이 인재는 등용하지 않습니다. 앞으로 이 인물은 다시 천거하지 않습니다."
	_decline_btn.pressed.connect(_on_decline_scholar)
	btns.add_child(_decline_btn)
	_fold_btn = _make_btn("접기", Color(0.45, 0.40, 0.34))
	_fold_btn.pressed.connect(_fold)
	btns.add_child(_fold_btn)
	_next_btn = _make_btn("다음 ▶", Color(0.20, 0.42, 0.22))
	_next_btn.pressed.connect(_on_next)
	btns.add_child(_next_btn)

	# 접었을 때 다시 부르는 작은 버튼
	_reopen_btn = _make_btn("🧑‍⚖️ " + _gname(), Color(0.20, 0.42, 0.22))
	_reopen_btn.anchor_top = 1.0
	_reopen_btn.anchor_bottom = 1.0
	_reopen_btn.offset_left = 14.0
	_reopen_btn.offset_right = 210.0
	_reopen_btn.offset_top = -132.0
	_reopen_btn.offset_bottom = -92.0
	_reopen_btn.visible = false
	_reopen_btn.pressed.connect(_unfold)
	add_child(_reopen_btn)


func _make_btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 14)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate()
	sh.bg_color = col.lightened(0.18)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", Color(0.99, 0.96, 0.86))
	return b

# ------------------------------------------------------------------ 말하기(타자기 효과)
func _say(text: String) -> void:
	if GuidePortrait.is_secretary():
		text = secretary_speech(text)
	if _text_lbl != null:
		_text_lbl.text = text
		_text_lbl.visible_characters = 0
	_typing = 0.0
	if _portrait != null:
		_portrait.talking = true

func _typing_done() -> bool:
	if _text_lbl == null:
		return true
	return _text_lbl.visible_characters < 0 or _text_lbl.visible_characters >= _text_lbl.get_total_character_count()

func _process(delta: float) -> void:
	# PORT-TRACE [어두운 화면 갇힘]: 긴급 경보(alert) 중에 천거·정무 조언이 창을 넘겨받으면 _mode만 바뀌고 어두운 막이 남아
	# (layer 20) 그 아래 열린 팝업 버튼이 눌리지 않았다 — 막은 첫 안내·긴급 경보 동안에만 둔다.
	if _dim != null and _dim.visible and _mode not in ["intro", "alert"]:
		_dim.visible = false
	if _advice_cooldown > 0.0:
		_advice_cooldown -= delta
		if _advice_cooldown <= 0.0 and _mode in ["step", "done"] and not _advice_queue.is_empty():
			_show_next_advice()

	# 정무 조언 자동 표시 간격 쿨다운
	if _affairs_cooldown > 0.0:
		_affairs_cooldown -= delta

	if _auto_close > 0.0:
		_auto_close -= delta
		if _auto_close <= 0.0 and _mode in ["cheer", "advice", "affairs"]:
			_resume_after_talk()
	# 띄워 둔 조언의 대상이 그사이 이미 착공·완공되었으면 1.5초 안에 "이미 마친 일"로 바꾸고 다음 정무로 자연스럽게 진행
	_recheck -= delta
	if _recheck <= 0.0:
		_recheck = 1.0
		if _mode in ["advice", "affairs"] and _auto_close <= 0.0 and not _advice_now.is_empty() and _advice_expired(_advice_now):
			_set_buttons(false, false, false, true, false)
			_page_lbl.text = "✔ 완료"
			_say("✔ 그 일은 이미 하셨네요! 다음 정무 과제를 살피시옵소서.")
			_auto_close = 1.5
	if _text_lbl == null or _typing_done():
		if _portrait:
			_portrait.talking = false
		return
	_typing += delta * 38.0
	_text_lbl.visible_characters = int(_typing)

# ------------------------------------------------------------------ 흐름
func start_intro() -> void:
	if not GameSettings.is_judge_advice_enabled():
		if _dim != null: _dim.visible = false
		if _box != null: _box.visible = false
		return
	_mode = "intro"
	_page_i = 0
	_dim.visible = true
	_unfold()
	if time_manager:
		_speed_before = time_manager.current_speed
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	_show_intro_page()

func _show_intro_page() -> void:
	_set_buttons(true, false, false, false, true)
	_next_btn.text = "시작하기 ▶" if _page_i == INTRO_PAGES.size() - 1 else "다음 ▶"
	_page_lbl.text = "%d / %d" % [_page_i + 1, INTRO_PAGES.size()]
	_say(INTRO_PAGES[_page_i])

func _end_intro() -> void:
	_advice_seen["intro_done"] = true
	_dim.visible = false
	if time_manager and time_manager.current_speed == TimeManager.SpeedMode.PAUSE:
		var resume: int = _speed_before if _speed_before != TimeManager.SpeedMode.PAUSE else TimeManager.SpeedMode.NORMAL
		time_manager.set_speed(resume as TimeManager.SpeedMode)
	_resume_after_talk()

func is_modal_open() -> bool:
	return (_dim != null and _dim.visible) or (_box != null and _box.visible and _mode == "intro")

func _is_gate_constructed_or_started(g: Dictionary) -> bool:
	if grid == null:
		return false
	var gid: String = g.get("id", "")
	# 대역사 연계: 해당 성문이 포함된 대역사가 착공 중이거나 완공되었으면 착공/완공으로 간주
	if sim:
		for p in sim.mega_projects:
			var pid: String = p.get("id", "")
			var p_act: bool = p.get("is_started", false) or p.get("is_completed", false)
			if not p_act:
				continue
			if gid == "jangan" and pid == "hwahong_north":
				return true
			elif gid == "paldal" and pid == "namsu_south":
				return true
			elif gid == "changryong" and pid == "changryong_east":
				return true
			elif gid == "hwaseo" and (pid == "paldal_fortress" or pid == "hwahong_north"):
				return true
			elif gid == "hwahong" and pid == "hwahong_north":
				return true

	var gp: Vector2i = g.get("pos", Vector2i(-1, -1))
	var gname: String = g.get("name", "")
	var g_short: String = gname.split("(")[0].strip_edges()

	# 1. 맵 전체에서 해당 성문 이름으로 명명된 문이 있거나 공사 중인지 확인
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.get("building", "") == "gate":
				var t_name: String = t.get("gate_name", "")
				if t_name != "" and g_short != "" and (g_short in t_name):
					return true
			if t.get("under_construction", false) and t.get("building", "") == "gate":
				return true

	# 2. 고증 좌표 반경 3타일 내에 성문(gate) 또는 화홍문이 존재하는지 확인 (완공 및 공사 중 모두)
	if gp.x >= 0 and gp.y >= 0:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var nx := gp.x + dx
				var ny := gp.y + dy
				if grid.in_bounds(nx, ny):
					var t: Dictionary = grid.grid[ny][nx]
					var b: String = t.get("building", "")
					if b == "gate" or (gid == "hwahong" and (t.get("is_hwahong", false) or b == "hwahong")):
						return true
					if t.get("under_construction", false) and (b == "gate" or gid == "hwahong"):
						return true
	return false

func _get_next_unbuilt_gate() -> Dictionary:
	if grid == null:
		return {}
	for g in QuestSystem.GATE_ORDER:
		if not _is_gate_constructed_or_started(g):
			return g
	return {}

func _show_step(q: Dictionary) -> void:
	if not GameSettings.is_judge_advice_enabled():
		if _box != null: _box.visible = false
		return
	if q.is_empty():
		_on_all_done()
		return
	var qid: String = q.get("id", "")
	if qid == "wall_build":
		var wall_done: bool = (sim and sim.fortress_progress >= 100) or (grid and (grid.fortress_progress >= 100 or (grid.has_method("is_wall_loop_completed") and grid.is_wall_loop_completed())))
		if wall_done:
			if quests:
				quests.check_current_quest()
			_on_all_done()
			return
	_mode = "step"
	_step_quest = q
	# PORT-TRACE [심시티 2000급 최적화]: 대화창 팝업 시 4,096칸 부지 전수 유효성 검사 루프를 돌지 않고
	# 힌트 지원 여부만 O(1)로 확인하여 즉시 팝업(0초 딜레이). 실제 좌표 연산은 [어디에?] 클릭 시에만 수행.
	var has_hint: bool = qid in ["haenggung", "road", "gate", "seojangdae", "bongdon", "civil_zoning"]
	_set_buttons(false, true, has_hint, true, false)
	_tool_btn.text = "🔨 " + str(q.get("btn_text", "도구 고르기"))
	_page_lbl.text = str(q.get("title", ""))

	if qid == "haenggung":
		_say("첫 번째 할 일! '화성행궁'을 세워요. 팔달산 능선을 등진 아늑한 분지 평지(행궁 터)에 자리 잡아야 해요.\n[행궁 터 잡기]를 누르고 추천 자리를 누르세요. 7×7칸의 대궐이라 네 계절 동안 지어요!")
	elif qid == "gate":
		var ng := _get_next_unbuilt_gate()
		if not ng.is_empty():
			_say("실제로 화성을 지을 때는 '문'부터 세웠대요! 지금은 [%s]을(를) 세울 차례예요.\n[성문 세우기]를 누르고 삼남대로 길목을 눌러 성문을 세워요. [어디에?]를 누르면 위치를 보여드려요!" % ng.get("name", "성문"))
		else:
			_say(STEP_TALK.get(qid, str(q.get("desc", ""))))
	elif qid == "bongdon":
		if grid.count_completed("wall") == 0:
			_say("위험을 알리는 '봉돈'은 완공된 성곽 위에 세워야 합니다!\n아직 성곽이 완공되지 않았으니, 먼저 [화성성곽]을 쌓아 성곽을 완공해 주세요.")
			_where_btn.visible = false
		else:
			_say("위험할 때 불과 연기로 소식을 알리는 '봉돈'을 동남 구릉 능선에 지어요.\n[봉돈 축조]를 누르고 성곽 능선을 눌러 주세요. 어디인지 모르겠으면 [어디에?]를 눌러 보세요!")
	else:
		_say(STEP_TALK.get(qid, String(q.get("desc", ""))))

func _on_quest_completed(q: Dictionary) -> void:
	_mode = "cheer"
	_unfold()
	var qid: String = q.get("id", "")
	var reward: String = q.get("reward", {}).get("msg", "")
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()
	_set_buttons(false, false, false, true, true)
	if not _affairs_list.is_empty():
		_next_btn.text = "🏛️ 정무 조언 보기 ▶"
		_page_lbl.text = "✔ 어명 완수 (정무 조언 %d건)" % _affairs_list.size()
	else:
		_next_btn.text = "다음 어명 보기 ▶"
		_page_lbl.text = "✔ 어명 완수!"
	_say(CHEER_TALK.get(qid, "잘하셨어요!") + ("\n" + reward if reward != "" else ""))
	_auto_close = 4.0 # 클릭하지 않아도 잠시 뒤 저절로 닫히고 다음 조언으로

func _on_all_done() -> void:
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()
	if not _affairs_list.is_empty():
		_switch_tab("affairs")
		return
	_mode = "done"
	_unfold()
	_set_buttons(false, false, false, true, false)
	_page_lbl.text = "모든 어명 완수"
	_say(FINAL_TALK)

func _on_next() -> void:
	if not _typing_done():
		_text_lbl.visible_characters = -1 # 한 번 누르면 글을 끝까지 바로 보여준다
		return
	match _mode:
		"intro":
			_page_i += 1
			if _page_i >= INTRO_PAGES.size():
				_end_intro()
			else:
				_show_intro_page()
		"cheer":
			if not _affairs_list.is_empty():
				_switch_tab("affairs")
			elif (quests != null and quests.is_all_completed) or (sim != null and sim.fortress_progress >= 100):
				_on_all_done()
			else:
				_resume_after_talk()
		"affairs":
			# 현재 조언을 dismiss 처리 (이 세션 동안 재표시 금지)
			var cur_key: String = str(_advice_now.get("key", ""))
			if cur_key != "":
				_dismissed_affairs[cur_key] = true
			# dismiss 후 남은 조언 목록 재계산
			_affairs_list = _collect_affairs_advices()
			if _affairs_list.is_empty():
				# 더 이상 조언 없음 → 어명 탭 또는 완료로 복귀
				_resume_after_talk()
			else:
				# 다음 조언 표시 (인덱스 유지, 범위 초과 방지)
				_affair_idx = clampi(_affair_idx, 0, _affairs_list.size() - 1)
				_affairs_cooldown = AFFAIRS_MIN_INTERVAL
				_show_affairs_tab(_affair_idx)
		"advice", "report":
			_resume_after_talk()
		"alert":
			_dim.visible = false
			_resume_after_talk()

func _on_tool() -> void:
	if _mode in ["advice", "affairs", "report"]:
		_do_advice_action()
		return
	var tid: String = _step_quest.get("tool", "")
	var qid: String = _step_quest.get("id", "")
	if tid != "" and panels:
		if qid == "bongdon" and grid and grid.count_completed("wall") == 0:
			panels.select_tool("wall")
			_say("위험을 알리는 '봉돈'은 완공된 성곽 위에 세워야 합니다!\n먼저 [화성성곽]을 쌓아 성곽을 완성해 주세요.")
			if hud:
				hud._show_toast("봉돈은 완공된 성곽 위에만 축조할 수 있습니다! 먼저 성곽을 쌓아주세요.", "🧱")
			return
		panels.select_tool(tid)
		var pos: Vector2i = quests.find_hint_position(qid) if quests else Vector2i(-1, -1)
		if pos.x >= 0 and hud:
			hud.jump_to_grid(pos)
			_say("좋아요! 추천 자리로 화면을 옮겼어요. 여기에 지어 보세요.")
			hud._show_toast("추천 위치로 이동했습니다. 이곳에 건설하십시오!", "📍")
		else:
			_say("좋아요! 이제 지도에서 알맞은 땅을 눌러 주세요.")

func _on_where() -> void:
	var qid: String = _step_quest.get("id", "")
	var pos: Vector2i = quests.find_hint_position(qid) if quests else Vector2i(-1, -1)
	if _mode in ["advice", "affairs"] and _advice_now.get("target", "") == "gate":
		pos = quests.find_hint_position("gate")
	if pos.x >= 0 and hud:
		hud.jump_to_grid(pos)
		_say("여기가 좋겠어요! 화면 가운데쯤 보이는 곳에 지어 보세요.")
		hud._show_toast("추천 위치로 이동했습니다. 이곳에 건설하십시오!", "📍")

func _set_buttons(skip: bool, tool: bool, where: bool, fold: bool, next: bool) -> void:
	if _skip_btn != null: _skip_btn.visible = skip
	if _tool_btn != null: _tool_btn.visible = tool
	if _where_btn != null: _where_btn.visible = where
	if _fold_btn != null: _fold_btn.visible = fold
	if _next_btn != null: _next_btn.visible = next
	if _decline_btn != null: _decline_btn.visible = false

## 아뢸 일이 없을 때 창을 접는다. 플레이어가 접은 것(_is_user_folded)과 달리 다음 급한 조언은 그대로 저절로 뜬다.
func _hide_when_idle() -> void:
	_resume_after_talk() # 다시 펼쳤을 때 보일 내용(남은 어명 또는 완수 인사)을 채워 둔다
	if _dim != null:
		_dim.visible = false
	if _box != null:
		_box.visible = false
	if _reopen_btn != null:
		_reopen_btn.visible = true
		_reopen_btn.text = "🧑‍⚖️ " + _gname()

func _fold() -> void:
	_is_user_folded = true
	if _mode in ["advice", "affairs", "report"]:
		_resume_after_talk()
	if _box != null:
		_box.visible = false
	if _reopen_btn != null:
		_reopen_btn.visible = true
		_affairs_list = _collect_affairs_advices()
		if not _affairs_list.is_empty():
			_reopen_btn.text = ("🧑‍⚖️ %s (정무 조언 %%d건 💡)" % _gshort()) % _affairs_list.size()
		else:
			_reopen_btn.text = "🧑‍⚖️ " + _gname()

func _unfold() -> void:
	_is_user_folded = false
	if _box != null:
		_box.visible = true
	if _reopen_btn != null:
		_reopen_btn.visible = false
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()

## PORT-TRACE [공성전]: 반란군 출몰 직전 김판관의 전면 경고(화면을 어둡게 덮고 확인을 받는다, 한 번)
func show_alert(text: String) -> void:
	_mode = "alert"
	_auto_close = 0.0
	_dim.visible = true
	_unfold()
	_set_buttons(false, false, false, false, true)
	_next_btn.text = "알겠소, 막아라! ▶"
	_page_lbl.text = "⚠ 긴급 경보"
	_say(text)

## PORT-TRACE [김판관 천거]: 새 인재 후보가 나타나면 상소문처럼 천거하고 정무 조언 모드로 즉시 브리핑
func _on_scholar_appeared(c: Dictionary) -> void:
	var cid: String = str(c.get("id", ""))
	if ScholarManager.is_scholar_hired(cid, sim.retainers if sim != null else {}):
		return
	var info: Dictionary = CourtSystem.SCHOLARS.get(cid, {})
	if info.is_empty():
		return
	var s_sal: int = court.get_scholar_salary(cid) if court != null else CourtSystem.calculate_scholar_salary(int(info.get("salary", 200)))
	_push_advice("scholar_%s_%d_%d" % [cid, court.current_year, sim.turn],
		"전하, 상소를 올리옵니다. 초야에 %s(이)라는 인물이 있사온데…\n\"%s\"\n(녹봉 매달 %d냥 · 신의 천거 정확도 %d%%)" % [info["name"], c.get("praise", ""), s_sal, int(c.get("acc", 0))],
		"👥 조정 인사 열기", "modal", "court", {"cand": cid})
	
	_affairs_list = _collect_affairs_advices()
	_update_tab_buttons()
	_unfold()
	
	# 인재 등용 조언이 위치한 인덱스로 즉시 이동하여 브리핑
	for i in range(_affairs_list.size()):
		if _affairs_list[i].get("key", "").begins_with("affair_scholar"):
			_show_affairs_tab(i)
			return
	_show_affairs_tab(0)
