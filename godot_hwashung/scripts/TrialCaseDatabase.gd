extends RefCounted
class_name TrialCaseDatabase

## [조선 후기 화성유수부 원옥(寃獄) 친국·송사 케이스 데이터베이스]
## 정조 대왕의 '흠휼사상(欽恤思想)' 고증을 바탕으로 백성들의 억울한 사연과 관아 비장·아전의 수사 보고서를 수록.
## 선택지 유형:
##   1. 엄벌/원칙: 법도 엄단 (왕권 +5, 민심 -5 등)
##   2. 타협/중도: 노역/벌금/변상 (현상 유지 및 소폭 자원 연동)
##   3. 관용/선처: 정조식 흠휼 훈방 (민심 +5, 왕권 -5 또는 구휼미 연동)

const CASES: Array[Dictionary] = [
	{
		"id": "starving_filial_rice",
		"title": "효자의 쌀 도둑질",
		"defendant_name": "춘삼 (소작농)",
		"defendant_desc": "\"어머니 약값이 없어 그만 지주의 쌀 한 됫박을 훔쳤사옵니다.\n굶어 죽어가는 노모를 차마 볼 수 없었습니다. 죽을 죄를 졌습니다!\"",
		"defendant_portrait": "criminal",
		"investigator_title": "형방 아전의 현장 수사 기록",
		"investigator_portrait": "ajeon_investigator",
		"investigator_report": "\"사또, 죄인 춘삼은 지주의 뒤주를 털다 현포되었습니다.\n허나 집안을 뒤져보니 병든 노모가 삼일 밤낮을 굶어 피골이 상접하였고,\n훔친 쌀도 죽을 쑤어 모친께만 바친 뒤 자신은 굶고 있었습니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 절도죄는 국법의 근간을 흔드니, 장형 40대에 처한다.",
				"desc": "법도를 바로세워 기강을 잡으나 백성들의 원성을 삽니다.",
				"royal_power": 5,
				"loyalty": -5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "국법의 엄정함을 천명하여 왕권이 섰으나, 효자의 장형 소식에 백성들이 슬퍼합니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 쌀값을 관아 노역 3일로 대신 변상케 한다.",
				"desc": "훔친 곡식을 노동으로 갚게 하여 법과 온정을 절충합니다.",
				"royal_power": 0,
				"loyalty": 0,
				"gold": 0,
				"rice": 0,
				"verdict_text": "춘삼이 관아에서 성실히 노역을 치르고 지주에게 쌀값을 갚아 사태가 원만히 매듭되었습니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 지극한 효심을 참작하여 훈방하고, 구휼미 10석을 하사한다.",
				"desc": "정조의 흠휼 뜻을 받들어 죄인을 풀고 굶주린 모자를 구제합니다.",
				"royal_power": -5,
				"loyalty": 5,
				"gold": 0,
				"rice": -10,
				"verdict_text": "유수의 자애로운 판결에 온 읍내 백성들이 감복하여 만세를 부릅니다."
			}
		]
	},
	{
		"id": "stonemason_delay",
		"title": "성곽 석수의 태업 의혹",
		"defendant_name": "막쇠 (축성 석수)",
		"defendant_desc": "\"사또, 결코 태업을 부린 것이 아니옵니다!\n정돌을 깰 때 속을 서두르면 금이 가 성벽이 무너집니다.\n단단한 화강암 결을 살피느라 늦어진 것뿐이옵니다.\"",
		"defendant_portrait": "artisan",
		"investigator_title": "유수부 감동 비장의 감정서",
		"investigator_portrait": "bijiang",
		"investigator_report": "\"공사를 감독한 패두는 막쇠가 며칠째 돌 쪼는 소리가 뜸해 공기를 지체시켰다 고변했습니다.\n허나 그가 쪼아낸 전돌과 성돌은 틈새가 칼날도 안 들어갈 만큼 정밀하여\n기술적인 완벽을 기하느라 진척이 더뎠던 것으로 보입니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 성역 공기 지연은 중죄이니, 노임을 삭감하고 옥에 가둔다.",
				"desc": "엄격한 공정 기강을 확립하나 장인들의 사기가 꺾입니다.",
				"royal_power": 5,
				"loyalty": -5,
				"gold": 50,
				"rice": 0,
				"verdict_text": "석수 막쇠를 문책하여 공사 기한을 독려했으나 장인들 사이에 탄식이 흐릅니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 경책만 내리고 숙련된 조수를 붙여 정해진 공정을 맞추게 한다.",
				"desc": "품질과 속도를 조화롭게 유지하는 현실적 중도책입니다.",
				"royal_power": 0,
				"loyalty": 0,
				"gold": 0,
				"rice": 0,
				"verdict_text": "조수를 얻은 석수가 성실히 성돌을 깎아 품질과 속도를 모두 보전하였습니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 튼튼한 성곽을 위한 노고를 치하하고, 막걸리와 휴식을 하사한다.",
				"desc": "석수의 장인정신을 기려 사기를 진작합니다. (국고 -50냥)",
				"royal_power": -3,
				"loyalty": 5,
				"gold": -50,
				"rice": 0,
				"verdict_text": "석수들이 유수의 혜안에 눈물 흘리며, 더욱 견고하게 성돌을 쌓겠다고 결의합니다."
			}
		]
	},
	{
		"id": "counterfeit_coin",
		"title": "저잣거리 위조 엽전 유통",
		"defendant_name": "마점석 (시전 보따리상)",
		"defendant_desc": "\"억울하옵니다! 한양에서 온 도매상에게 비단을 넘기고 받은 엽전일 뿐,\n제가 납을 섞어 주조한 것이 아니옵니다! 소인은 글자도 모르는 일개 행상입니다.\"",
		"defendant_portrait": "bobusang",
		"investigator_title": "포도청 군관의 수사 보고",
		"investigator_portrait": "patrol_soldier",
		"investigator_report": "\"장터에 유통된 상평통보는 아연과 납이 과하게 섞여 글자가 뭉개진 조악한 위전입니다.\n마점석의 봇짐 속에서 위전 서른 냥이 발견되었으나,\n실제 주조 거푸집이나 용광로는 전혀 나오지 않아 단순 유통책 혹은 피해자로 사료됩니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 화폐를 어지럽힌 죄는 역모와 같으니, 의금부로 압송해 참형을 건의한다.",
				"desc": "위조 화폐 발본색원을 천명하여 국가 법도를 엄히 세웁니다.",
				"royal_power": 5,
				"loyalty": -5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "화폐 유통 범죄를 일벌백계하여 관아의 위엄이 섰으나 과한 처벌이라는 동요가 있습니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 위전을 전량 압수하여 녹이고, 배후의 한양 환전상을 추적케 한다.",
				"desc": "사안의 본질을 짚어 위조 주모자를 캐는 명판결입니다.",
				"royal_power": 5,
				"loyalty": 5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "[명판결] 무고한 행상을 구제하고 배후의 위전 주조패를 일망타진하여 민심과 왕권이 함께 빛납니다!"
			},
			{
				"type": "mercy",
				"label": "③ [관용] 속아서 받은 사정을 딱히 여겨 엽전을 모두 돌려주고 방면한다.",
				"desc": "온정을 베풀었으나 불량 화폐가 장터에 그대로 풀립니다.",
				"royal_power": -5,
				"loyalty": -5,
				"gold": -50,
				"rice": 0,
				"verdict_text": "[오판] 시전에 불량 위조 엽전이 돌아 시장 신뢰가 무너지고 상인들이 큰 손해를 입었습니다."
			}
		]
	},
	{
		"id": "illegal_cow_slaughter",
		"title": "우시장 농우(農牛) 밀살 의혹",
		"defendant_name": "개똥이 (빈농)",
		"defendant_desc": "\"사또, 지난 봄부터 키우던 누렁이가 역병에 걸려 거품을 물고 쓰러졌습니다!\n그냥 묻으면 굶주린 처자식이 굶어 죽을 판이라 부득이 고기를 떠 장에 내다 팔았습니다.\"",
		"defendant_portrait": "farmer",
		"investigator_title": "우시장 감관의 감식 결과",
		"investigator_portrait": "ajeon_investigator",
		"investigator_report": "\"조선 법도상 농우는 농사의 근본이므로 사사로이 도살할 수 없습니다.\n검시 결과 소의 내장에 열독 흔적이 역력하여 병든 것은 사실이나,\n관아의 도살 허가 첩지를 받지 않고 암암리에 고기를 유통한 것은 명백한 위법입니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 농우 밀살금지령을 위반했으니, 곤장 30대와 전액 몰수형을 내린다.",
				"desc": "농경 국가의 근간인 소를 보호하는 원칙을 엄수합니다.",
				"royal_power": 5,
				"loyalty": -3,
				"gold": 0,
				"rice": 0,
				"verdict_text": "농우 밀살에 쐐기를 박아 관아의 규율을 세웠으나, 가난한 농가의 한숨이 깊어집니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 고기는 관아 진휼소로 몰수해 국밥으로 나누고, 죄인은 부역에 처한다.",
				"desc": "질병 고기의 시중 유통을 막고 빈민 구휼 식량으로 전환합니다.",
				"royal_power": 0,
				"loyalty": 2,
				"gold": 0,
				"rice": 10,
				"verdict_text": "상한 고기 유통을 막고 진휼소에 고깃국을 풀어 읍민들이 유수의 슬기를 칭송합니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 굶주린 처자식의 사정을 가엾게 여겨 훈방하고 관아 송아지를 대여한다.",
				"desc": "농민을 구제하는 애민정치를 폅니다. (국고 -50냥)",
				"royal_power": -4,
				"loyalty": 5,
				"gold": -50,
				"rice": 0,
				"verdict_text": "유수의 온정에 감복한 농민들이 다시 밭을 갈며 눈물로 은혜를 갚겠다고 맹세합니다."
			}
		]
	},
	{
		"id": "western_learning_book",
		"title": "서학(천주교) 서책 밀반입",
		"defendant_name": "이선달 (남인 몰락 양반)",
		"defendant_desc": "\"사또, 이 책은 사악한 요술책이 아니옵니다!\n서양의 측량술과 기하학, 그리고 만인이 하늘 아래 평등하다는 도리를 담은 서학서일 뿐,\n조정을 능멸하려는 뜻은 추호도 없었습니다.\"",
		"defendant_portrait": "scholar",
		"investigator_title": "유수부 비장의 서책 감정서",
		"investigator_portrait": "bijiang",
		"investigator_report": "\"압수한 서책은 마테오 리치의 《천주실의》와 서양 역법서입니다.\n노론 벽파 유생들은 사학(邪學) 죄인을 당장 한양 의금부로 압송하라며 연좌 농성 중이나,\n정조 대왕께서는 '바른 학문(정학)을 바로세우면 사학은 저절로 사라진다'고 하셨습니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 사학을 용납할 수 없으니, 즉시 의금부로 압송하여 국문케 한다.",
				"desc": "노론 유림의 환심을 사고 왕실 법통을 지킵니다.",
				"royal_power": 5,
				"loyalty": -5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "사학 죄인을 엄단하여 유림의 결집을 얻었으나, 실학 지식인들의 안타까움을 샀습니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 교리 서책은 압수해 불태우되, 측량·역법서는 규장각 연구용으로 귀속한다.",
				"desc": "정조의 흠휼과 서기수용론에 입각한 지혜로운 타협책입니다.",
				"royal_power": 3,
				"loyalty": 3,
				"gold": 0,
				"rice": 0,
				"verdict_text": "[정조식 명판결] 사학의 미혹은 차단하고 서양의 이로운 기술만 국정에 수용하여 양쪽을 모두 품었습니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 학문 탐구의 자유를 인정하여 묵인하고 조용히 훈방한다.",
				"desc": "사대부 유생들의 극심한 반발과 상소가 빗발칩니다.",
				"royal_power": -5,
				"loyalty": 5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "죄인은 풀려났으나, 노론 유림이 성균관과 향교를 앞세워 유수부 규탄 상소를 올립니다."
			}
		]
	},
	{
		"id": "illegal_tree_cutting",
		"title": "팔달산 금송(禁松) 채벌",
		"defendant_name": "김돌석 (나무꾼)",
		"defendant_desc": "\"사또, 지난 겨울 강추위에 어린 자식이 얼어 죽기 직전이었습니다!\n성벽 지을 아름드리 소나무는 건드리지 않고, 죽은 가지와 잡목 몇 단을 꺾었을 뿐입니다.\"",
		"defendant_portrait": "woodcutter",
		"investigator_title": "산림 감관(산직)의 현장 검증",
		"investigator_portrait": "patrol_soldier",
		"investigator_report": "\"팔달산 성곽 주변은 성역용 목재와 풍치를 위해 벌채를 엄금한 금산(禁山) 구역입니다.\n현장 확인 결과 백 년 묵은 소나무 한 그루의 아랫가지를 도끼로 벤 흔적이 있으나,\n나무 자체가 고사하지는 않았으며 장작을 팔아 치부한 정황은 없습니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 금송령 위반은 국법 엄단 대상이니, 도끼를 몰수하고 장형 30대에 처한다.",
				"desc": "국가 산림과 성곽 목재 보호의 기강을 확립합니다.",
				"royal_power": 5,
				"loyalty": -4,
				"gold": 0,
				"rice": 0,
				"verdict_text": "금송령을 엄격히 집행하여 팔달산 송림의 훼손을 차단하였습니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 생목 벌채는 금하되, 겨울철 낙엽과 마른 가지 수거는 관아 허가제로 푼다.",
				"desc": "산림 훼손을 막으면서 백성들의 땔감 고통을 덜어줍니다.",
				"royal_power": 0,
				"loyalty": 3,
				"gold": 0,
				"rice": 0,
				"verdict_text": "제도적 보완을 통해 산림도 보호하고 백성의 월동 난방도 해결하여 칭송을 받았습니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 자식을 살리려 한 부정을 참작해 훈방하고 관아 땔나무를 나눠준다.",
				"desc": "백성의 추위를 구휼하나 산림 훼손 우려가 남습니다.",
				"royal_power": -3,
				"loyalty": 5,
				"gold": -30,
				"rice": 0,
				"verdict_text": "관아의 땔감 나눔에 백성들이 얼어붙은 손을 녹이며 감사의 눈물을 흘립니다."
			}
		]
	},
	{
		"id": "hwan_gok_usury",
		"title": "사창 환곡(還穀) 고리대 착취",
		"defendant_name": "박참봉 (부유한 토호 지주)",
		"defendant_desc": "\"사또, 봄철 춘궁기에 굶주리는 소작농들에게 사재를 털어 곡식을 빌려주었을 뿐입니다.\n가을에 이자 서 말을 덧붙여 받은 것은 이자율 관례에 따른 정당한 대가입니다!\"",
		"defendant_portrait": "yangban_m",
		"investigator_title": "호방 아전의 사창 장부 감사",
		"investigator_portrait": "ajeon_investigator",
		"investigator_report": "\"박참봉은 관아의 환곡 배급이 늦어진 틈을 타 모래 섞인 쌀을 빌려주고,\n가을 추수 때 원금의 두 배가 넘는 살인적인 고리대를 징수하여\n소작농 다섯 가구가 전답을 빼앗기고 유랑민으로 전락할 위기입니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 토호의 가렴주구를 척결하니, 불법 이자를 몰수하고 곤장 50대에 처한다.",
				"desc": "백성을 수탈한 토호 세력을 응징하여 백성들의 환호를 받습니다.",
				"royal_power": 4,
				"loyalty": 5,
				"gold": 50,
				"rice": 20,
				"verdict_text": "[통쾌한 판결] 탐욕스러운 토호를 엄벌하고 빼앗긴 전답을 돌려주니 백성들이 춤을 춥니다!"
			},
			{
				"type": "compromise",
				"label": "② [타협] 관아 법정 이율(1할)만 인정하고, 초과 수탈분은 즉시 농민에게 환급케 한다.",
				"desc": "법 테두리 안에서 토호와 소작농 간의 채무를 조정합니다.",
				"royal_power": 1,
				"loyalty": 2,
				"gold": 0,
				"rice": 0,
				"verdict_text": "법정 이율을 엄격히 적용하여 무리한 수탈을 바로잡고 지역 경제의 안정을 꾀했습니다."
			},
			{
				"type": "mercy",
				"label": "③ [관용] 지주의 기득권을 존중하여 양자 간 자율 합의로 사건을 종결한다.",
				"desc": "토호의 눈치를 보느라 억울한 농민들을 외면합니다.",
				"royal_power": -5,
				"loyalty": -5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "[오판] 관아가 부자의 편을 들었다는 분노가 들끓으며 유랑민들이 도적으로 변하고 있습니다."
			}
		]
	},
	{
		"id": "market_monopoly",
		"title": "저잣거리 난전(亂廛) 난투극",
		"defendant_name": "배서방 (보따리 난전 상인)",
		"defendant_desc": "\"사또, 시전 금난전권(독점권)을 쥔 육의전 상인들이 저희 노점을 엎고 멱살을 잡았습니다!\n자유롭게 물건을 팔 권리(통공정책)를 주신 임금님의 뜻을 왜 시전 상인들이 가로막습니까!\"",
		"defendant_portrait": "merchant",
		"investigator_title": "시장 감관의 현장 실황",
		"investigator_portrait": "bijiang",
		"investigator_report": "\"정조 대왕께서 신해통공(辛亥通共)을 반포하여 시전의 독점권을 폐지하셨으나,\n기존 시전 상인들이 기득권을 지키려 난전 상인들의 채소 보따리를 짓밟아 패싸움이 났습니다.\n시전 상인들도 유수부의 명확한 경계 획정을 요구하고 있습니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 소란을 일으킨 양측 우두머리를 모두 구금하고 장터 영업을 일시 정지한다.",
				"desc": "치안을 신속히 회복하나 저잣거리 상권이 위축됩니다.",
				"royal_power": 4,
				"loyalty": -4,
				"gold": -30,
				"rice": 0,
				"verdict_text": "장터 소란을 진압하였으나 상인들의 발길이 끊겨 저잣거리 세수가 줄었습니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 통공의 법도를 재확인하고, 장마당 구역을 나누어 난전 전용 자리를 지정한다.",
				"desc": "정조의 통공 정책을 현장에 맞게 안착시키는 명판결입니다.",
				"royal_power": 5,
				"loyalty": 5,
				"gold": 20,
				"rice": 0,
				"verdict_text": "[명판결] 시전과 난전이 상생하는 구획을 정해주니 화성 저잣거리가 삼남 최대의 상업 중심지로 번영합니다!"
			},
			{
				"type": "mercy",
				"label": "③ [관용] 시전 상인들의 기득권을 인정하여 난전 상인들을 외곽으로 축출한다.",
				"desc": "통공 정신을 후퇴시키고 영세 상인들에게 고통을 줍니다.",
				"royal_power": -5,
				"loyalty": -3,
				"gold": 50,
				"rice": 0,
				"verdict_text": "[실책] 독점 상인들은 기뻐했으나, 물가가 치솟고 서민들의 원성이 자자합니다."
			}
		]
	},
	{
		"id": "dam_water_dispute",
		"title": "만석거 농업용수 쟁탈전",
		"defendant_name": "칠복이 (하류 둔전 소작인)",
		"defendant_desc": "\"사또, 상류 양반댁에서 만석거 물꼬를 혼자 독점해 우리 논은 바닥이 쩍쩍 갈라졌습니다!\n밤중에 물꼬를 조금 텄다고 몽둥이질을 하니 살아남으려면 어쩔 수 없었습니다.\"",
		"defendant_portrait": "farmer",
		"investigator_title": "수리 감관의 수로 조사 보고",
		"investigator_portrait": "bijiang",
		"investigator_report": "\"가뭄이 닥치자 상류 부호들이 사설 제방을 쌓아 만석거 수로를 가로막았습니다.\n하류 대유둔전 수백 마지기가 물이 말라 벼가 타들어가고 있어,\n농민들이 삽과 괭이를 들고 무력 충돌 직전까지 번진 심각한 상황입니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 사설 물꼬를 튼 자들을 처벌하고, 수로 훼손자에게 수리비를 물린다.",
				"desc": "물꼬 파손 행위를 다스리나 근본적인 가뭄 갈등은 방치됩니다.",
				"royal_power": 3,
				"loyalty": -4,
				"gold": 0,
				"rice": 0,
				"verdict_text": "야간 수로 침범을 경계하였으나 농민들의 목마름은 여전히 해결되지 않았습니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 상류 사설 제방을 헐고, 관아 주도로 '윤번 급수제(사흘씩 교대)'를 시행한다.",
				"desc": "수리 시설을 공평하게 공유하는 합리적 치수 판결입니다.",
				"royal_power": 4,
				"loyalty": 5,
				"gold": 0,
				"rice": 15,
				"verdict_text": "[명판결] 사설 제방을 철거하고 공평히 물을 나누어 대유둔전의 대풍작을 지켜냈습니다!"
			},
			{
				"type": "mercy",
				"label": "③ [관용] 양측 문책 없이 관아에서 군량미를 풀어 하류 농민들에게 구휼미를 준다.",
				"desc": "갈등은 봉합하나 관아 곳간이 축납니다.",
				"royal_power": -3,
				"loyalty": 4,
				"gold": 0,
				"rice": -30,
				"verdict_text": "구휼미로 급한 불은 껐으나, 근본적인 수로 분쟁은 불씨로 남았습니다."
			}
		]
	},
	{
		"id": "military_draft_evasion",
		"title": "군역(軍役) 회피와 백골포(白骨布)",
		"defendant_name": "갑돌이 (장정)",
		"defendant_desc": "\"사또, 작년에 세상을 떠난 아버지는 물론 세 살배기 갓난아이 이름으로도 군포가 나옵니다!\n일 년에 베 다섯 필을 낼 길이 없어 산속으로 도망쳤습니다. 소인을 차라리 죽여주십시오!\"",
		"defendant_portrait": "criminal",
		"investigator_title": "군관의 군적(軍籍) 대조 결과",
		"investigator_portrait": "patrol_soldier",
		"investigator_report": "\"조사 결과 이방과 군교들이 결탁하여 사망한 부친(백골징포)과 젖먹이(황구첨정)에게\n허위 군적을 부과해 중간에서 군포를 착복하고 있었습니다.\n갑돌이는 도망친 탈영병 신분이나, 사정은 참혹하기 이를 데 없습니다.\"",
		"choices": [
			{
				"type": "severe",
				"label": "① [엄벌] 군역 탈영은 병권의 근간을 해치니, 규정대로 장용영 부역군으로 압송한다.",
				"desc": "국방법도를 엄수하여 군영을 유지하나 백성의 한이 깊어집니다.",
				"royal_power": 5,
				"loyalty": -5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "탈영병을 처벌하여 군기를 세웠으나 군포 착취의 근본 모순에 백성들이 절망합니다."
			},
			{
				"type": "compromise",
				"label": "② [타협] 허위 군적을 작성한 부패 아전을 파직·압송하고, 갑돌이의 가혹한 군포를 탕감한다.",
				"desc": "정조의 군정 개혁과 흠휼사상을 완벽히 실현하는 명판결입니다.",
				"royal_power": 5,
				"loyalty": 5,
				"gold": 0,
				"rice": 0,
				"verdict_text": "[명판결] 부패 군교를 엄단하고 억울한 군포를 탕감하니 백성들이 관아를 향해 큰절을 올립니다!"
			},
			{
				"type": "mercy",
				"label": "③ [관용] 군포를 관아 예산으로 대신 대납해주고 죄인을 방면한다.",
				"desc": "온정을 베푸나 관아 재정이 축나고 부패의 싹을 자르지 못합니다.",
				"royal_power": -4,
				"loyalty": 3,
				"gold": -50,
				"rice": 0,
				"verdict_text": "사재로 대납하여 죄인을 구했으나 부패 아전들은 뒤에서 비웃고 있습니다."
			}
		]
	}
]

## 전체 사건 목록 조회
static func get_all_cases() -> Array[Dictionary]:
	return CASES

## ID로 사건 조회
static func get_case_by_id(case_id: String) -> Dictionary:
	for c: Dictionary in CASES:
		if c.get("id", "") == case_id:
			return c
	return {}

## 특정 턴/시드 기반 결정론적 사건 추첨
static func pick_seasonal_case(turn_number: int, solved_ids: Array = []) -> Dictionary:
	var available: Array[Dictionary] = []
	for c: Dictionary in CASES:
		var cid: String = c.get("id", "")
		if not (cid in solved_ids):
			available.append(c)

	if available.is_empty():
		# 모든 사건을 소진했을 경우 순환 재사용
		available = CASES.duplicate()

	var idx: int = (turn_number * 7 + 3) % available.size()
	return available[idx]
