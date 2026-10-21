extends RefCounted
class_name JoseonPalette

## [조선시대 4단계 입체 셀 셰이딩 팔레트 마스터]
## 1. 1px 다크 차콜 외곽선 (Crisp Outline)
const OUTLINE_COLOR: Color = Color("#1e1b18")
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.32)

## 2. 피부 4단계 톤 (Highlight, Mid, Shadow, Deep)
const SKIN_TONES: Dictionary = {
	"fair": {
		"hl": Color("#fff0e6"), "mid": Color("#fcdbc0"), "sh": Color("#e8be9e"), "deep": Color("#c49876")
	},
	"normal": {
		"hl": Color("#ffe8d6"), "mid": Color("#f5cbab"), "sh": Color("#dbab87"), "deep": Color("#b88562")
	},
	"elder": {
		"hl": Color("#f4e4d4"), "mid": Color("#e6c8b0"), "sh": Color("#c4a58b"), "deep": Color("#9e7d64")
	},
	"worker": {
		"hl": Color("#eec8a3"), "mid": Color("#d8a77c"), "sh": Color("#b48054"), "deep": Color("#8c5d35")
	},
	"weathered": {
		"hl": Color("#dfb58f"), "mid": Color("#c69368"), "sh": Color("#9e6b42"), "deep": Color("#754b29")
	}
}

## 3. 의복 4단계 입체 팔레트 (Highlight, Mid, Shadow, Deep)
const GARMENTS: Dictionary = {
	# 왕실 / 국왕 (다홍색 곤룡포)
	"royal_red": {
		"hl": Color("#d9383a"), "mid": Color("#b81d24"), "sh": Color("#8a1117"), "deep": Color("#5e0a0f"),
		"trim": Color("#d4af37"), "belt": Color("#e5c158")
	},
	# 문관 단령 (홍단령, 1품 대례복)
	"officer_red": {
		"hl": Color("#b83038"), "mid": Color("#8a1c22"), "sh": Color("#681217"), "deep": Color("#48090d"),
		"trim": Color("#f4ede2"), "belt": Color("#d4af37")
	},
	# 문관 단령 (청단령, 당하관/실무관)
	"officer_blue": {
		"hl": Color("#2b5999"), "mid": Color("#1d4378"), "sh": Color("#142f57"), "deep": Color("#0c1c36"),
		"trim": Color("#e8f0fe"), "belt": Color("#d4af37")
	},
	# 문관 단령 (녹단령)
	"officer_teal": {
		"hl": Color("#2e8b7d"), "mid": Color("#216e63"), "sh": Color("#164f47"), "deep": Color("#0e3630"),
		"trim": Color("#e6f4f1"), "belt": Color("#d4af37")
	},
	# 노론 벽파 짙은 자단색
	"officer_dark": {
		"hl": Color("#4a1f28"), "mid": Color("#38131b"), "sh": Color("#260b11"), "deep": Color("#170408"),
		"trim": Color("#e0c068"), "belt": Color("#d4af37")
	},
	# 선비/실학자 도포 (옥색/청백색 - 정약용)
	"scholar_teal": {
		"hl": Color("#e0f2f1"), "mid": Color("#b2dfdb"), "sh": Color("#80cbc4"), "deep": Color("#4db6ac"),
		"trim": Color("#263238"), "belt": Color("#212121")
	},
	# 선비 백색 도포 (이덕무)
	"scholar_white": {
		"hl": Color("#ffffff"), "mid": Color("#f0f4f8"), "sh": Color("#d9e2ec"), "deep": Color("#bcccdc"),
		"trim": Color("#334e68"), "belt": Color("#102a43")
	},
	# 선비 감청색 도포 (박제가)
	"scholar_navy": {
		"hl": Color("#3b5998"), "mid": Color("#2b4374"), "sh": Color("#1c2e52"), "deep": Color("#111c33"),
		"trim": Color("#e0c068"), "belt": Color("#c08030")
	},
	# 선비 비취색 도포 (유득공)
	"scholar_sage": {
		"hl": Color("#739e73"), "mid": Color("#588157"), "sh": Color("#416240"), "deep": Color("#2d452d"),
		"trim": Color("#1e2e1e"), "belt": Color("#a3b18a")
	},
	# 선비 황토빛 학창의 (서유구)
	"scholar_amber": {
		"hl": Color("#deb054"), "mid": Color("#c49a45"), "sh": Color("#96742f"), "deep": Color("#6e531d"),
		"trim": Color("#1a1a1a"), "belt": Color("#1a1a1a")
	},
	# 선비 갈색 도포 (박지원)
	"scholar_brown": {
		"hl": Color("#856e60"), "mid": Color("#6c584c"), "sh": Color("#504036"), "deep": Color("#382b24"),
		"trim": Color("#a98467"), "belt": Color("#adc178")
	},
	# 선비 심청색 학창의 (홍대용)
	"scholar_indigo": {
		"hl": Color("#2e4f7a"), "mid": Color("#1f3a60"), "sh": Color("#152842"), "deep": Color("#0c1829"),
		"trim": Color("#111111"), "belt": Color("#00a896")
	},
	# 서예가 백옥색 학창의 (김정희)
	"scholar_pure": {
		"hl": Color("#ffffff"), "mid": Color("#f8f9fa"), "sh": Color("#e2e8f0"), "deep": Color("#cbd5e1"),
		"trim": Color("#0f172a"), "belt": Color("#1e293b")
	},
	# 명필 자색 도포 (유한지)
	"scholar_purple": {
		"hl": Color("#7b2cbf"), "mid": Color("#5a189a"), "sh": Color("#3c096c"), "deep": Color("#240046"),
		"trim": Color("#9d4edd"), "belt": Color("#ffb703")
	},
	# 권신 세도 화려한 자주도포 (홍국영)
	"noble_violet": {
		"hl": Color("#9d4edd"), "mid": Color("#7209b7"), "sh": Color("#560bad"), "deep": Color("#3a0ca3"),
		"trim": Color("#f72585"), "belt": Color("#4cc9f0")
	},
	# 화원 복식 (김홍도)
	"painter_cream": {
		"hl": Color("#f6edce"), "mid": Color("#e9d8a6"), "sh": Color("#d4bd7e"), "deep": Color("#b39b56"),
		"trim": Color("#005f73"), "belt": Color("#0a9396")
	},
	# 무관 남색 융복/철릭 (조심태)
	"military_navy": {
		"hl": Color("#2b4a78"), "mid": Color("#1b3557"), "sh": Color("#12243d"), "deep": Color("#0a1524"),
		"trim": Color("#cc3333"), "belt": Color("#cc3333")
	},
	# 장용영 두정갑주 (백동수)
	"armor_blue": {
		"hl": Color("#2b4e7e"), "mid": Color("#1d3557"), "sh": Color("#13233a"), "deep": Color("#0a1320"),
		"trim": Color("#e63946"), "belt": Color("#d4af37")
	},
	# 훈련대장 흑철 중갑주 (구선복)
	"armor_iron": {
		"hl": Color("#5c646d"), "mid": Color("#495057"), "sh": Color("#343a40"), "deep": Color("#212529"),
		"trim": Color("#a82a2a"), "belt": Color("#adb5bd")
	},
	# 석공/장인 작업복 (김바우)
	"artisan_earth": {
		"hl": Color("#be9f7b"), "mid": Color("#a68a68"), "sh": Color("#82684b"), "deep": Color("#5f4931"),
		"trim": Color("#f8f9fa"), "belt": Color("#423220")
	},
	# 대목장 배자 (이성길)
	"carpenter_blue": {
		"hl": Color("#3b629b"), "mid": Color("#2b4c7e"), "sh": Color("#1e3558"), "deep": Color("#132239"),
		"trim": Color("#c4a482"), "belt": Color("#8c6d48")
	},
	# 가죽공 앞치마 (무쇠)
	"leather_dark": {
		"hl": Color("#754e33"), "mid": Color("#5c3d28"), "sh": Color("#422b1c"), "deep": Color("#2a1a10"),
		"trim": Color("#8a5a36"), "belt": Color("#1e1e1e")
	},
	# 실무 판관 청단령 (김판관)
	"officer_azure": {
		"hl": Color("#3b82f6"), "mid": Color("#1d4ed8"), "sh": Color("#1e40af"), "deep": Color("#172554"),
		"trim": Color("#93c5fd"), "belt": Color("#d4af37")
	},
	# 보부상 감청색/청색 도포 (레퍼런스 완벽 일치)
	"bobusang_blue": {
		"hl": Color("#3b6bc2"), "mid": Color("#29529e"), "sh": Color("#1b3973"), "deep": Color("#102247"),
		"trim": Color("#ffffff"), "belt": Color("#1b3973")
	},
	# 일반 백성 무명옷
	"commoner_hemp": {
		"hl": Color("#faf6ed"), "mid": Color("#ece4d4"), "sh": Color("#d4c7b0"), "deep": Color("#b3a388"),
		"trim": Color("#6e5d47"), "belt": Color("#5c4c38")
	},
	# 농부 삼베옷
	"farmer_rough": {
		"hl": Color("#e0d4be"), "mid": Color("#caba9f"), "sh": Color("#a89678"), "deep": Color("#827054"),
		"trim": Color("#5c4c38"), "belt": Color("#423626")
	},
	# 포졸/순라군 군복
	"patrol_blue": {
		"hl": Color("#2472ba"), "mid": Color("#1864ab"), "sh": Color("#11497d"), "deep": Color("#0b3054"),
		"trim": Color("#e03131"), "belt": Color("#c92a2a")
	},
	# 치안 군인/장용영
	"soldier_guard": {
		"hl": Color("#2f4258"), "mid": Color("#202f40"), "sh": Color("#141e2a"), "deep": Color("#0a0e14"),
		"trim": Color("#c92a2a"), "belt": Color("#d4af37")
	},
	# 양반 부인 한복 (녹의홍상 / 옥색치마)
	"lady_pastel": {
		"hl": Color("#ff9ebb"), "mid": Color("#e87a99"), "sh": Color("#bf5672"), "deep": Color("#8f364d"),
		"trim": Color("#ffffff"), "belt": Color("#2e3a6a")
	},
	# 기생 화려한 색동
	"gisaeng_vivid": {
		"hl": Color("#78cf53"), "mid": Color("#5aa83a"), "sh": Color("#3f7c24"), "deep": Color("#285215"),
		"trim": Color("#c8283a"), "belt": Color("#e0b040")
	},
	# 세시풍속: 낚시꾼 (황토/삼베 어부복)
	"fisherman_cloth": {
		"hl": Color("#e2d0ab"), "mid": Color("#c4af85"), "sh": Color("#9e875f"), "deep": Color("#735f3d"),
		"trim": Color("#3e2c1c"), "belt": Color("#5c3a21")
	},
	# 세시풍속: 씨름장사 (상의 탈의 맨살 구릿빛 근육 + 흰 무명 바지 + 청홍 샅바)
	"ssireum_satba": {
		"hl": Color("#dfb58f"), "mid": Color("#c69368"), "sh": Color("#9e6b42"), "deep": Color("#754b29"),
		"trim": Color("#1d4ed8"), "belt": Color("#dc2626")
	},
	# 세시풍속: 택견꾼 (백색 무명 도포 + 감청색 쾌자 띠)
	"taekkyeon_white": {
		"hl": Color("#ffffff"), "mid": Color("#f3f4f6"), "sh": Color("#d1d5db"), "deep": Color("#9ca3af"),
		"trim": Color("#1e3a8a"), "belt": Color("#dc2626")
	},
	# 세시풍속: 연날리기 동자 (화사한 옥색/청록색 쾌자)
	"kite_boy": {
		"hl": Color("#a7f3d0"), "mid": Color("#6ee7b7"), "sh": Color("#34d399"), "deep": Color("#059669"),
		"trim": Color("#f43f5e"), "belt": Color("#fbbf24")
	}
}

## 4. 관모 / 모자 색상
const HEADGEAR_COLORS: Dictionary = {
	"black": {"hl": Color("#383533"), "mid": Color("#22201e"), "sh": Color("#161413"), "deep": Color("#0d0c0b")},
	"red_felt": {"hl": Color("#e03131"), "mid": Color("#c92a2a"), "sh": Color("#961b1b"), "deep": Color("#630e0e")},
	"straw": {"hl": Color("#ebd2a0"), "mid": Color("#d4b77f"), "sh": Color("#b39359"), "deep": Color("#8a6e3c")},
	"gold": {"hl": Color("#fde047"), "mid": Color("#eab308"), "sh": Color("#ca8a04"), "deep": Color("#854d0e")},
	"iron": {"hl": Color("#64748b"), "mid": Color("#475569"), "sh": Color("#334155"), "deep": Color("#1e293b")}
}
