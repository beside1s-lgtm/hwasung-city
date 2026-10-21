extends RefCounted
class_name NamedNpcs

## 등용할 수 있는 인재(CourtSystem.SCHOLARS)가 지도에서 실제로 걸어 다니도록 하는 네임드 NPC 17인의 명세.
## (정약용·채제공·조심태·김홍도·김바우·구선복·유한지 7인은 CitizenManager.NAMED_INFO의 옛 방식을 그대로 쓴다.)
## 각자 "코스(route)"를 가진다: 주요 장소를 차례로 찾아가(place) 그곳에서 일정 시간(secs) 특정 행동(act)을 하고 다음 장소로 간다.
## place는 문자열 또는 대안 목록(앞에서부터 지도에 있는 곳을 쓴다). 지도에 어느 장소도 없으면 그 인물은 나타나지 않는다.
##   장소: gate 성문 · wall 성곽 · com 저잣거리 · haenggung 행궁 · seojangdae 서장대 · yeonmudae 연무대 · military 군사시설 ·
##         reservoir 저수지 · hyanggyo 향교 · seodang 서당/서원 · patrol 순라청 · workshop 공방 · farm 둔전 · road 도로 ·
##         bank 수원천변 · jongnu 종루 · banghwa 방화수류정 · levee 제방
##   행동: read 글 읽기 · write 글쓰기 · paint 그림 · survey 측량·관찰 · drill 무예 · inspect 점검 · bargain 흥정 ·
##         build 목수일 · craft 장인일 · farm 농사 살피기 · speak 강론
## 살피기로 눌렀을 때만 역사 사전 [역사 인물] 퍼즐 조각이 맞춰진다.

const EXTRA := {
	"park_jiwon": {
		"name": "박지원 (朴趾源)", "title": "북학파 문장가·연암", "role_tag": "북학파 문장가", "icon": "🖋️",
		"base": "seonbi", "top": "5a6e8a", "bottom": "5a6e8a", "acc": "c8a040", "extra": {"prop": "book"},
		"route": [{"place": "com", "act": "write", "secs": 22}, {"place": ["gate", "road"], "act": "survey", "secs": 14}, {"place": "bank", "act": "write", "secs": 18}],
		"lines": ["수레와 벽돌을 쓰면 백성의 살림이 달라지오. 이용후생이 학문의 끝이오!", "저잣거리 장꾼들의 입담이 곧 살아 있는 문장이로구나.", "청나라에서 본 벽돌 쌓는 법을 이 성에서 보게 되다니 감개무량하오.", "붓은 칼보다 멀리 가는 법, 오늘 본 일을 열하일기 한 줄로 남기겠소.", "글은 높은 곳이 아니라 백성의 삶터에서 길어 올리는 것이오."],
		"desc": "《열하일기》를 쓴 북학파의 거장. 청나라에서 배운 수레·벽돌·상업의 이점을 조선에 들여오려 애쓴 문장가입니다.",
		"activity": "저잣거리와 성문, 수원천변을 돌며 백성들의 삶을 붓으로 기록하고 있습니다.",
		"leave": "오늘 본 장터 이야기를 정리하러 서재로 돌아가야겠소."
	},
	"hong_daeyong": {
		"name": "홍대용 (洪大容)", "title": "천문학자·담헌", "role_tag": "천문학자·과학자", "icon": "🔭",
		"base": "yangban", "top": "3a5a6a", "bottom": "3a5a6a", "acc": "c8a040", "extra": {"prop": "book"},
		"route": [{"place": "seojangdae", "act": "survey", "secs": 24}, {"place": ["hyanggyo", "seodang"], "act": "speak", "secs": 18}],
		"lines": ["땅이 둥글어 스스로 돈다는 이치를 아직도 믿지 못하는 이가 많구려.", "서장대 높은 곳에서 별을 헤아리니 하늘의 이치가 한눈에 드는구나.", "혼천의를 다듬어야 절기를 정확히 맞출 수 있소.", "중화도 변방도 없소. 만물은 저마다 중심이라오.", "과학은 백성의 농사와 뱃길을 돕는 학문이어야 하오."],
		"desc": "지구가 자전한다고 주장한 조선 최고의 천문학자. 서양 과학과 북학을 받아들이려 한 실학자입니다.",
		"activity": "서장대에 올라 하늘을 관측하고 서당에서 젊은 유생들에게 천문을 가르칩니다.",
		"leave": "오늘 별 관측 기록을 정리하러 돌아가겠소."
	},
	"lee_deokmu": {
		"name": "이덕무 (李德懋)", "title": "규장각 검서관·청장관", "role_tag": "규장각 검서관", "icon": "📚",
		"base": "seonbi", "top": "8a9a8a", "bottom": "8a9a8a", "acc": "6a5a3a", "extra": {"prop": "book"},
		"route": [{"place": ["seodang", "hyanggyo"], "act": "read", "secs": 26}, {"place": "haenggung", "act": "write", "secs": 20}],
		"lines": ["책을 읽는 것이 곧 벗을 사귀는 일이라, 나는 책벌레라 불려도 좋소.", "의궤 교정에 쓸 글자 하나도 소홀할 수 없소.", "규장각 검서관의 일은 정조 대왕의 학문을 곁에서 받드는 것이오.", "눈이 침침해도 좋은 글 앞에서는 졸음이 달아나는구려.", "서얼 출신이라도 학문이 깊으면 나라의 큰 일꾼이 되지 않겠소."],
		"desc": "서얼 출신이면서 정조의 눈에 들어 규장각 검서관이 된 학자. 박학과 성실로 많은 책을 교정하고 엮었습니다.",
		"activity": "서당과 향교에서 책을 읽고 행궁에서 의궤 원고를 베끼고 교정합니다.",
		"leave": "해가 기우니 책 보따리를 싸서 규장각으로 돌아가야겠소."
	},
	"park_jega": {
		"name": "박제가 (朴齊家)", "title": "북학파 검서관·초정", "role_tag": "북학파 실학자", "icon": "🛒",
		"base": "yangban", "top": "7a6a4a", "bottom": "7a6a4a", "acc": "c8a040", "extra": {"prop": "pack"},
		"route": [{"place": "com", "act": "bargain", "secs": 22}, {"place": ["gate", "road"], "act": "survey", "secs": 14}, {"place": "workshop", "act": "inspect", "secs": 16}],
		"lines": ["수레를 쓰지 않으니 길이 있어도 물건이 오가지 못하는구려.", "나라가 가난한 것은 쓰는 법을 몰라서요. 재물은 우물과 같아 퍼 써야 마르지 않소.", "청나라의 벽돌과 배를 보고 배워야 하오. 부끄러워할 일이 아니오.", "장터에 물건이 넘치면 백성의 살림도 넉넉해지는 법이라오.", "북학의, 이것이 조선이 나아갈 길이오."],
		"desc": "《북학의》를 쓴 실학자. 수레와 선박, 상업의 이점을 들어 조선의 낡은 경제를 바꾸려 했습니다.",
		"activity": "저잣거리에서 상인들과 값을 의논하고 공방과 성문 앞 길목의 유통을 살핍니다.",
		"leave": "오늘 본 시세를 적어 두었으니 돌아가 상소를 다듬어야겠소."
	},
	"baek_dongsu": {
		"name": "백동수 (白東脩)", "title": "장용영 무예 총관·야뇌", "role_tag": "무예 총관", "icon": "🗡️",
		"base": "trooper", "top": "232826", "bottom": "3a3030", "acc": "b22222", "extra": {},
		"route": [{"place": "yeonmudae", "act": "drill", "secs": 24}, {"place": "seojangdae", "act": "drill", "secs": 16}, {"place": ["patrol", "gate"], "act": "inspect", "secs": 14}],
		"lines": ["검은 마음으로 쥐는 것이 아니오. 몸으로 익혀 마음을 다스리는 것이 무예요!", "무예도보통지의 스물네 가지 기예를 한 가지도 빠짐없이 가르치겠다!", "장용영의 칼은 백성을 지키는 칼이어야 하오.", "기본 자세가 흐트러지면 아무리 센 힘도 소용없다. 다시 한 번!", "도적이 오더라도 훈련된 병사는 두렵지 않소."],
		"desc": "《무예도보통지》 편찬에 참여한 조선 제일의 무인. 장용영 군사들에게 무예를 가르친 총관입니다.",
		"activity": "연무대와 서장대에서 군사들의 무예를 지도하고 순라청과 성문을 점검합니다.",
		"leave": "오늘 훈련을 마쳤으니 병기를 정비하러 돌아가겠다."
	},
	"lee_gahwan": {
		"name": "이가환 (李家煥)", "title": "공조판서·수학자·정헌", "role_tag": "수학자·공조판서", "icon": "📐",
		"base": "official", "top": "2a4a9a", "bottom": "2a4a9a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": "wall", "act": "survey", "secs": 24}, {"place": ["hyanggyo", "seodang"], "act": "speak", "secs": 16}],
		"lines": ["성벽의 기울기 한 치가 백 년 뒤의 붕괴를 가르오. 정밀하게 재시오.", "수를 모르고는 나라의 살림도 성도 쌓을 수 없소.", "서양의 기하와 우리의 산학을 아우르면 더 반듯한 성을 쌓을 수 있소.", "축성 공사비는 하나하나 셈하여 의궤에 남겨야 하오.", "학문은 편을 가르는 것이 아니라 이치를 밝히는 일이라오."],
		"desc": "수학과 천문에 밝았던 남인의 지식인. 공조판서로서 정밀한 측량과 셈으로 축성을 돕습니다.",
		"activity": "성곽 공사 구간을 실측하고 향교에서 산학과 천문을 강론합니다.",
		"leave": "측량 장부를 정리해야 하니 관아로 돌아가겠소."
	},
	"kim_josun": {
		"name": "김조순 (金祖淳)", "title": "규장각 제학·풍고", "role_tag": "규장각 제학", "icon": "🏛️",
		"base": "official", "top": "3a7a5a", "bottom": "3a7a5a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": "haenggung", "act": "write", "secs": 22}, {"place": "jongnu", "act": "inspect", "secs": 14}, {"place": "com", "act": "survey", "secs": 14}],
		"lines": ["조정이 화목하려면 말을 아끼고 예를 다해야 하오.", "세자 교육의 일을 소홀히 할 수 없으니 오늘은 서책을 다시 살피겠소.", "규장각 제학의 붓은 임금의 뜻을 바르게 전해야 하오.", "시파와 벽파가 서로 다투어서는 나라가 편치 못하오.", "민심이 평안해야 도성도 평안한 법이오."],
		"desc": "노론 시파의 인물로 규장각 제학을 맡은 학자. 훗날 세도 정치의 주역이 되는 집안의 재목입니다.",
		"activity": "행궁에서 문서를 살피고 종루와 저잣거리를 거닐며 민심을 헤아립니다.",
		"leave": "오늘 정무를 마쳤으니 규장각으로 가서 문서를 정리하겠소."
	},
	"yu_deukgong": {
		"name": "유득공 (柳得恭)", "title": "역사가·영재", "role_tag": "규장각 검서관·역사가", "icon": "📜",
		"base": "seonbi", "top": "7a9a7a", "bottom": "7a9a7a", "acc": "5a4a2a", "extra": {"prop": "book"},
		"route": [{"place": ["seodang", "hyanggyo"], "act": "read", "secs": 24}, {"place": ["gate", "wall"], "act": "write", "secs": 20}],
		"lines": ["발해는 우리 역사요. 남북국이라 불러야 마땅하오.", "성문 위에 올라 옛 도읍의 풍경을 읊조리면 시구가 절로 나오.", "역사를 잊은 나라는 뿌리를 잃은 나무와 같소.", "수원은 본래 고구려의 땅이었다는 기록을 찾아냈다오.", "옛 기록을 모으는 일이 내 책무요."],
		"desc": "《발해고》를 쓴 실학자이자 역사가. 규장각 검서관으로 여러 서책을 엮었습니다.",
		"activity": "서당과 향교에서 옛 기록을 읽고 성문과 성곽 아래서 시와 글을 지어 기록합니다.",
		"leave": "오늘 모은 기록을 정리하러 서재로 돌아가겠소."
	},
	"kim_jeonghui": {
		"name": "김정희 (金正喜)", "title": "청년 서예가·추사", "role_tag": "청년 서예가·금석학자", "icon": "🖌️",
		"base": "yangban", "top": "e8e4d8", "bottom": "e8e4d8", "acc": "3a5aa0", "extra": {},
		"route": [{"place": ["gate", "wall"], "act": "write", "secs": 22}, {"place": ["banghwa", "bank"], "act": "paint", "secs": 20}],
		"lines": ["획 하나에 천 년의 기운을 담아야 비문이 살아 있소.", "옛 비석의 글씨를 탁본하여 금석학을 배우는 중이오.", "방화수류정 연못의 물빛이 먹빛보다 곱구려.", "젊다고 얕보지 마시오. 붓은 나이를 가리지 않소.", "글씨는 마음의 그림자라, 바르지 못하면 획도 흔들리오."],
		"desc": "훗날 추사체를 완성할 청년 김정희. 금석학과 비문 고증에 열정을 쏟는 총명한 서생입니다.",
		"activity": "성문 현판과 비석 글씨를 살피고 방화수류정 연못가에서 풍경을 그립니다.",
		"leave": "오늘은 연습한 글씨가 많으니 돌아가 먹을 다시 갈아야겠소."
	},
	"seo_yugu": {
		"name": "서유구 (徐有榘)", "title": "농학자·풍석", "role_tag": "농학자", "icon": "🌾",
		"base": "seonbi", "top": "5a8a4a", "bottom": "5a8a4a", "acc": "6a5a3a", "extra": {"prop": "book"},
		"route": [{"place": "farm", "act": "farm", "secs": 24}, {"place": ["reservoir", "levee"], "act": "survey", "secs": 18}],
		"lines": ["씨 뿌리고 거두는 때를 알면 흉년에도 굶는 백성이 줄어들지요.", "둔전에 물을 어떻게 대는가가 소출을 가르오.", "농사는 천하의 근본이니, 선비도 밭을 알아야 하오.", "임원경제지에 오늘 본 논의 모양을 그려 넣어야겠소.", "새 농기구와 새 종자가 모든 백성의 밥상을 바꿀 것이오."],
		"desc": "방대한 농서 《임원경제지》를 남긴 농학자. 둔전 경영과 수리 개선에 밝았습니다.",
		"activity": "둔전을 돌며 농사 상태를 살피고 저수지와 제방의 물 관리를 점검합니다.",
		"leave": "농사 일지를 정리하러 돌아가겠소."
	},
	"jeong_beomjo": {
		"name": "정범조 (丁範祖)", "title": "대제학·해좌", "role_tag": "대제학", "icon": "🎓",
		"base": "official", "top": "a82a2a", "bottom": "a82a2a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": ["hyanggyo", "seodang"], "act": "speak", "secs": 24}, {"place": "haenggung", "act": "write", "secs": 18}],
		"lines": ["유생들이 경전의 뜻을 몸으로 익히면 고을이 절로 바로 서오.", "소론의 원로라 하여 편을 가르지 않고 인재를 구하겠소.", "임금의 글을 지을 때는 한 글자도 가볍게 쓸 수 없소.", "배움에는 끝이 없고 나이에는 한이 있다오.", "향교의 글 읽는 소리가 곧 고을의 기운이오."],
		"desc": "소론의 원로이자 대제학을 지낸 학자. 임금의 글을 짓고 유생들을 가르치는 데 힘썼습니다.",
		"activity": "향교와 서당에서 유생들에게 강론하고 행궁에서 임금의 글을 다듬습니다.",
		"leave": "강론을 마쳤으니 관아로 돌아가 문서를 살피겠소."
	},
	"lee_seonggil": {
		"name": "이성길 (李成吉)", "title": "도편수", "role_tag": "수석 목수·도편수", "icon": "🪚",
		"base": "mason", "top": "8a6a4a", "bottom": "7a5a3a", "acc": "6a4a2a", "extra": {"prop": "jige_e"},
		"route": [{"place": "haenggung", "act": "build", "secs": 24}, {"place": ["gate", "wall"], "act": "build", "secs": 20}, {"place": "workshop", "act": "craft", "secs": 14}],
		"lines": ["기둥 하나, 서까래 하나가 맞아야 집이 백 년을 가오.", "못 없이 짜 맞추는 것이 우리 목수의 자랑이오.", "행궁 대들보는 소나무 중에서도 곧은 것만 골랐소.", "도면대로 깎되 나무의 결을 거스르지 마시오.", "문루 지붕의 곡선은 눈으로 보고 손끝으로 완성하는 것이오."],
		"desc": "화성 건축을 이끈 수석 목수. 행궁의 전각과 성문 문루를 짜 올린 솜씨 좋은 도편수입니다.",
		"activity": "행궁과 성문 공사장에서 목재를 다듬고 짜 맞추며 작업을 지휘합니다.",
		"leave": "오늘 깎은 목재를 정리하고 연장을 챙겨 돌아가겠소."
	},
	"musoe": {
		"name": "무쇠", "title": "군수 가죽공", "role_tag": "장인·가죽공", "icon": "🧤",
		"base": "butcher", "top": "5c4a3a", "bottom": "4a3a2e", "acc": "3a281c", "extra": {},
		"route": [{"place": "workshop", "act": "craft", "secs": 24}, {"place": ["military", "patrol"], "act": "inspect", "secs": 16}],
		"lines": ["갑옷 가죽은 잘 무두질해야 화살도 막는다오.", "북 가죽 한 장에 장용영의 사기가 달렸소.", "군장이 허술하면 병사도 허술해지는 법이오.", "소가죽이든 말가죽이든 쓰임새를 알아야 제 값을 하오.", "손은 거칠어도 내 가죽만큼은 곱고 질기다오."],
		"desc": "군영에서 쓰는 갑옷과 북, 군장을 다루는 이름난 가죽공. 신분은 천해도 솜씨로는 으뜸입니다.",
		"activity": "공방에서 가죽을 무두질하고 군사 시설과 순라청의 군장을 점검합니다.",
		"leave": "가죽이 마르기 전에 공방으로 돌아가야겠소."
	},
	"hong_gukyeong": {
		"name": "홍국영 (洪國榮)", "title": "도승지·숙위소 대장", "role_tag": "왕의 측근", "icon": "⚡",
		"base": "official", "top": "a82a2a", "bottom": "a82a2a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": "haenggung", "act": "inspect", "secs": 20}, {"place": ["road", "gate"], "act": "inspect", "secs": 14}, {"place": "yeonmudae", "act": "inspect", "secs": 14}],
		"lines": ["전하의 뜻이 곧 법이오. 누구든 막아서는 자는 용서하지 않겠소.", "숙위소의 눈은 도성 구석구석까지 닿아 있소.", "내가 곁에 있는 한 전하의 안위는 걱정 마시오.", "공이 크다고 하는 말은 곧 칼날이 되어 돌아오는 법이지.", "세도가 하늘을 찔러도 한순간이니, 조심하여라."],
		"desc": "정조 즉위에 큰 공을 세워 권세가 하늘을 찔렀던 측근. 숙위소를 맡아 왕권을 지키려 했습니다.",
		"activity": "행궁과 주요 길목, 연무대를 돌며 경호 상태를 점검하고 사람들을 살핍니다.",
		"leave": "전하께 아뢸 일이 있어 입궐해야겠소."
	},
	"hong_inhan": {
		"name": "홍인한 (洪麟漢)", "title": "좌의정·외척", "role_tag": "권신·외척", "icon": "💰",
		"base": "official", "top": "3a3a6a", "bottom": "3a3a6a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": "com", "act": "bargain", "secs": 20}, {"place": ["haenggung", "gate"], "act": "inspect", "secs": 14}],
		"lines": ["세손이 정사를 알 필요가 있겠소? 노론의 뜻이 곧 나라의 뜻이오.", "저잣거리 세금이 얼마 걷히는지 내가 직접 보아야 마음이 놓이오.", "재물이 있어야 권세도 있는 법이오.", "내 곳간은 조정의 곳간과 한 몸이니 걱정 마시오.", "임금도 신하의 말을 들어야 오래가는 법이라오."],
		"desc": "혜경궁 홍씨의 숙부로, 세손의 즉위를 막으려 했던 외척. 재물과 권세에 밝았으나 나라 일을 어지럽혔습니다.",
		"activity": "저잣거리에서 상인들의 세금과 장사를 살피고 성문과 행궁 주변을 오갑니다.",
		"leave": "오늘 걷은 세금을 헤아리러 집으로 돌아가겠소."
	},
	"lee_gigyeong": {
		"name": "이기경 (李基慶)", "title": "서학 탄압 상소 유생", "role_tag": "보수 유생", "icon": "📕",
		"base": "seonbi", "top": "34495e", "bottom": "34495e", "acc": "8a2a2a", "extra": {"prop": "book"},
		"route": [{"place": ["hyanggyo", "seodang"], "act": "speak", "secs": 22}, {"place": "jongnu", "act": "inspect", "secs": 14}, {"place": "com", "act": "survey", "secs": 14}],
		"lines": ["서학은 아비도 임금도 모르는 사학(邪學)이오. 엄히 금해야 하오!", "제사를 폐하는 풍조가 번지니 삼강오륜이 무너지고 있소.", "정학을 지키는 것이 선비의 도리라오.", "서양 책을 읽는 자들이 저잣거리에 있다 하니 살펴야겠소.", "정약용이 아무리 재주가 있어도 사학에 물들면 소용이 없소."],
		"desc": "서학(천주교)을 사학이라 비판하며 엄히 금하라고 상소한 보수 유생. 정학의 수호자를 자처했습니다.",
		"activity": "향교에서 강론하고 종루와 저잣거리를 돌며 사학의 흔적을 감시합니다.",
		"leave": "오늘 본 일을 상소에 적으러 돌아가겠소."
	},
	"sim_hwanji": {
		"name": "심환지 (沈煥之)", "title": "노론 벽파 영수·만포", "role_tag": "벽파 영수", "icon": "🦅",
		"base": "official", "top": "3a3a4a", "bottom": "3a3a4a", "acc": "1a1a1a", "extra": {},
		"route": [{"place": "haenggung", "act": "inspect", "secs": 22}, {"place": ["hyanggyo", "seodang"], "act": "speak", "secs": 16}, {"place": "jongnu", "act": "inspect", "secs": 12}],
		"lines": ["전하의 일이라도 나라의 법도에 어긋나면 간하는 것이 신하의 도리요.", "군포를 함부로 줄이면 나라의 근본이 흔들리오.", "새로운 기술이니 뭐니 하지만 선왕의 법을 먼저 지켜야 하오.", "비밀 어찰은 태워 없애라 했건만, 전하의 속뜻은 알 수 없구려.", "벽파라 하여 모두 틀린 것은 아니오. 신중함이 곧 충심이오."],
		"desc": "노론 벽파를 이끈 영수로 정조와 때로 맞서면서도 어찰을 주고받으며 정국을 풀어 간 노회한 정치가입니다.",
		"activity": "행궁과 향교, 종루를 오가며 정국을 살피고 유생들의 여론을 헤아립니다.",
		"leave": "전하께 올릴 말씀을 다듬으러 돌아가겠소."
	},
}

static func has(id: String) -> bool:
	return EXTRA.has(id)

static func ids() -> Array:
	return EXTRA.keys()

## NpcSprites에 등록되는 도트 스프라이트 종류 이름(옷 색·모자·소품이 인물마다 다르다)
static func sprite_kind(id: String) -> String:
	var d: Dictionary = EXTRA.get(id, {})
	if d.is_empty():
		return "commoner_m"
	return NpcSprites.custom_kind(String(d["base"]), Color(String(d["top"])), Color(String(d["bottom"])), Color(String(d["acc"])), d["extra"] as Dictionary)

## CitizenManager가 쓰는 네임드 정보(옛 NAMED_INFO와 같은 모양)
static func info(id: String) -> Dictionary:
	var d: Dictionary = EXTRA.get(id, {})
	if d.is_empty():
		return {}
	return {"id": id, "name": d["name"], "title": d["title"], "role_tag": d["role_tag"], "icon": d["icon"], "lines": d["lines"],
		"leave_line": d["leave"], "desc": d["desc"], "activity": d["activity"]}
