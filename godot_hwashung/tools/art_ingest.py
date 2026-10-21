#!/usr/bin/env python3
"""
[그림 가공 도구] art_inbox/ 에 넣은 생성 그림을 게임용 PNG로 바꿔 assets/sprites/ 에 넣는다.

  python tools/art_ingest.py            # 가공 후 덮어쓰기(원본은 _backup_sprites/ 에 1회 백업)
  python tools/art_ingest.py --check    # 덮어쓰지 않고 art_inbox/_preview.png 미리보기만

넣는 법 (자세한 건 art_inbox/ART_LIST.md)
  art_inbox/buildings/
    thatch_house_01.png          ← 파일 이름 = 바꿀 건물 이름 (한 장에 건물 하나)
    아무이름.png + 아무이름.txt  ← 한 장에 여러 건물. txt에 건물 이름을 읽는 순서(위→아래, 왼→오른)대로 한 줄씩
  art_inbox/npcs/
    npc_farmer.png               ← 한 장에 인물 하나(자세 2·4·8개를 가로로)
    아무이름.png + 아무이름.txt  ← 한 장에 여러 인물. 한 줄(가로 행) = 한 인물, txt에 행 순서대로 이름
  txt 첫 줄에 grid=4x3 처럼 쓰면 자동 인식 대신 칸을 똑같이 나눠 자른다.
  이름은 영문 파일 이름 또는 목록의 한글 이름(예: 채제공, 농부, 초가 1) 둘 다 된다.

처리: 배경(단색·체커보드) 제거 → 물체 찾기 → 칸 크기에 맞춰 축소·바닥 정렬 → 알파 정리 → 색 수 줄이기(건물 64색, 인물 32색) → 저장
"""
from __future__ import annotations

import os
import re
import shutil
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
INBOX = os.path.join(ROOT, "art_inbox")
BACKUP = os.path.join(os.path.dirname(ROOT), "_backup_sprites")

# ------------------------------------------------------------------ 건물 목록: 이름 → (칸, 한글 이름)
# 캔버스: 가로 = (가로칸+세로칸)*32, 아래쪽 (가로칸+세로칸)*16 이 바닥 마름모. 위는 높이 여유.
CANVAS = {"1x1": (64, 72), "2x1": (96, 88), "2x2": (128, 112), "3x2": (160, 136), "3x3": (192, 160), "4x4": (256, 200), "7x7": (448, 320)}
SHOPS = ["선전(비단)", "도자기전", "약방", "서책방", "갓방", "은·옥 공예방", "유기전", "악기전", "팔달문 우시장", "어물전",
         "객주", "싸전", "육전", "옹기전", "주막", "과일전", "떡전", "신방(신발)", "소금·양념전", "연초전"]
BUILDINGS: dict[str, tuple[str, str]] = {
    "haenggung": ("7x7", "화성행궁"),
    "chukmanje": ("7x7", "축만제(서호) — 완성본"),
    "manseokgeo": ("7x7", "만석거 — 완성본"),
    "maegok_seowon": ("3x3", "매곡서원(향교)"),
    "lm_haenggung": ("7x7", "[지도] 화성행궁 7x7"),
    "lm_hyanggyo": ("4x4", "[지도] 수원향교 4x4"),
    "lm_gwana": ("2x2", "[지도] 관아 2x2"),
    "lm_jongnu": ("2x2", "[지도] 종루(여민각) 2x2"),
    "lm_jinhulso": ("2x2", "[지도] 진휼소 2x2"),
    "tile_house_10_3x3": ("3x3", "대갓집 기와집(진휼소 등)"),
    "ws_3x3_royal_arsenal": ("3x3", "군기시(왕실 무기고)"),
    "cattle_market_3x3": ("3x3", "수원 쇠전(우시장) 바탕 — 소·사람 없이"),
    "patrol_station": ("1x1", "순라청"),
    "firefighter_station": ("1x1", "멸화군 수성소"),
    "salt_store_2x2": ("2x2", "화서문 어염시장 소금 창고 2x2"),
    "tile_house_10_3x2": ("3x2", "큰 기와집 ㄱ자"),
    "seodang": ("2x2", "서당"),
    "seojangdae": ("2x2", "서장대(지휘 누각)"),
    "yeonmudae": ("2x2", "연무대(활터 누각)"),
    "yusubu": ("2x2", "유수부·순라청 관아"),
    "tile_house_08": ("2x2", "기와집 마당 넓은 집 1"),
    "tile_house_09": ("2x2", "기와집 마당 넓은 집 2"),
    "ws_2x2_ceramics": ("2x2", "도자기 가마 공방"),
    "ws_2x2_lumber_machinery": ("2x2", "제재·목재 기계 공방"),
    "children_play_yard": ("2x2", "아이들 놀이마당(제기·팽이)"),
    "women_play_yard": ("2x2", "여인들 놀이마당(널뛰기·그네)"),
    "thatch_house_08": ("2x1", "초가 ㄱ자 1"),
    "thatch_house_09": ("2x1", "초가 ㄱ자 2"),
    "thatch_house_10": ("2x1", "초가 ㄱ자 3"),
    "tile_house_05": ("2x1", "기와집 2칸 1"),
    "tile_house_06": ("2x1", "기와집 2칸 2"),
    "tile_house_07": ("2x1", "기와집 2칸 3"),
    "ws_2x1_blacksmith": ("2x1", "대장간"),
    "ws_2x1_dyeing": ("2x1", "염색 공방"),
    "ws_2x1_shoemaker": ("2x1", "갖바치(신발) 공방"),
    "ws_2x1_stonemason": ("2x1", "석공방"),
    "ws_2x1_tile_kiln": ("2x1", "기와 가마"),
    "thatch_house": ("1x1", "초가 기본"),
    "tile_house": ("1x1", "기와집 기본"),
    "market_shop": ("1x1", "장터 가게 기본"),
    "workshop": ("1x1", "공방 기본"),
    "well": ("1x1", "우물"),
    "ws_1x1_bamboo": ("1x1", "죽세공방"),
    "ws_1x1_carpenter": ("1x1", "목수 공방"),
    "ws_1x1_hanji": ("1x1", "한지 공방"),
    "ws_1x1_leather": ("1x1", "가죽 공방"),
    "ws_1x1_metalcraft": ("1x1", "금속 공예방"),
}
for _i in range(1, 8):
    BUILDINGS[f"thatch_house_{_i:02d}"] = ("1x1", f"초가 {_i}")
for _i in range(1, 5):
    BUILDINGS[f"tile_house_{_i:02d}"] = ("1x1", f"기와집 {_i}")
for _i, _n in enumerate(SHOPS):
    BUILDINGS[f"market_shop_{_i + 1:02d}"] = ("1x1", f"장터 {_n}")
# 같은 그림을 함께 쓰는 기본 파일(…_01을 넣으면 기본 이름도 같이 바뀐다)
BUILDING_TWINS = {"thatch_house_01": ["thatch_house"], "tile_house_01": ["tile_house"], "market_shop_01": ["market_shop"],
                  "ws_1x1_carpenter": ["workshop"]}

# ------------------------------------------------------------------ 인물 목록: 이름 → (한글 이름, 설명, 키 px)
NAMED = {
    "jeongjo": ("정조", "국왕, 붉은 곤룡포·익선관", 40), "chae_jegong": ("채제공", "영의정, 흰 수염 노재상", 40),
    "jeong_yakyong": ("정약용", "실학자, 관복", 40), "jo_simtae": ("조심태", "화성유수, 무관 관복", 40),
    "park_jega": ("박제가", "북학파 실학자", 40), "yi_deokmu": ("이덕무", "규장각 검서관", 40),
    "yu_deukgong": ("유득공", "역사학자", 40), "seo_yugu": ("서유구", "농학자", 40),
    "park_jiwon": ("박지원", "북학파 대가", 40), "hong_daeyong": ("홍대용", "천문학자", 40),
    "yi_gahwan": ("이가환", "공조판서", 40), "jeong_beomjo": ("정범조", "대제학", 40),
    "kim_hongdo": ("김홍도", "도화서 화원, 화구", 40), "kim_jeonghee": ("김정희", "추사, 서예가", 40),
    "yu_hanji": ("유한지", "예서 명필", 40), "sim_hwanji": ("심환지", "벽파 영수", 40),
    "hwang_inhan": ("홍인한", "권신 외척", 40), "kim_josun": ("김조순", "시파 중신", 40),
    "yi_gigyeong": ("이기경", "보수 유생", 40), "hong_gukyeong": ("홍국영", "세도 권신", 40),
    "baek_dongsu": ("백동수", "무예 총관, 장검", 40), "gu_seon_bok": ("구선복", "훈련대장, 갑주", 40),
    "kim_bau": ("김바우", "수석 석공, 망치", 40), "yi_seonggil": ("이성길", "도편수(목수 우두머리)", 40),
    "musoe": ("무쇠", "군수 가죽공", 40), "kim_pangwan": ("김판관", "수원부 판관(안내역)", 40),
}
# 같은 인물을 가리키는 옛 파일 이름(함께 덮어쓴다) — SpriteCacheManager.NAMED_ID_ALIASES
NAMED_ALIASES = {
    "gu_seon_bok": ["gu_seonbok", "named_gu_seonbok"], "yi_deokmu": ["lee_deokmu", "named_lee_deokmu"],
    "sim_hwanji": ["shim_hwanji", "named_shim_hwanji"], "hwang_inhan": ["hong_inhan", "named_hong_inhan"],
    "yi_gigyeong": ["kim_myeongsin", "named_kim_myeongsin"], "yi_seonggil": ["lee_seonggil", "named_lee_seonggil"],
}
GENERIC = {
    "npc_yangban_scholar": ("양반 선비", "갓·도포·부채", 40), "npc_yangban_lady": ("양반 부인", "가체·장옷", 38),
    "npc_hallyang": ("한량", "갓·화려한 도포", 40), "npc_gisaeng": ("기생", "가체·화사한 치마저고리", 38),
    "npc_farmer": ("농부", "삿갓·흰 바지저고리·괭이", 39), "npc_peasant_woman": ("아낙", "흰 수건·치마·바구니", 37),
    "npc_bobusang": ("보부상", "패랭이·지게 봇짐·지팡이", 40), "npc_artisan_blacksmith": ("대장장이", "앞치마·망치", 39),
    "npc_cheonmin": ("천민", "헤진 옷·맨상투", 38), "npc_child_boy": ("사내아이", "댕기머리 아이", 30),
    "npc_child_girl": ("계집아이", "댕기머리·색동", 30), "npc_patrol": ("순라군", "전립·창", 40),
    "npc_soldier": ("장용영 군사", "전립·두정갑·조총/창", 40), "npc_thief": ("도적", "복면·몽둥이", 39),
    "npc_brawler": ("왈짜(싸움꾼)", "웃통 걸친 거친 사내", 40), "npc_jeongisu": ("전기수(이야기꾼)", "갓·책", 40),
    "npc_fisherman": ("어부", "삿갓·그물·어망", 39), "npc_kite_flyer": ("연날리는 아이", "연과 얼레", 32),
    "npc_ssireum": ("씨름꾼", "샅바 맨 장사", 40), "npc_taekkyeon": ("택견꾼", "바지저고리·띠", 40),
    "parade_king": ("어가행렬 정조", "융복 차림 기마 국왕", 44), "parade_royal_carriage": ("어가(가마)", "왕의 가마와 가마꾼", 44),
    "parade_cavalry": ("행렬 기마병", "말 탄 무관", 44), "parade_musician": ("취타대", "나팔·북 악사", 40),
    "parade_flag_bearer": ("기수", "큰 깃발 든 군사", 44),
    "npc_base_man": ("바탕: 맨상투 남자", "모자 없는 흰옷 바탕", 40),
    "npc_base_man2": ("바탕: 흰 두루마기 남자", "모자 없는 흰옷 바탕", 40),
    "npc_base_youth": ("바탕: 댕기머리 총각", "모자 없는 흰옷 바탕", 38),
    "npc_base_old": ("바탕: 노인", "모자 없는 흰옷 바탕", 37),
    "npc_base_woman": ("바탕: 쪽 찐 아낙", "모자 없는 흰옷 바탕", 37),
    "npc_base_woman2": ("바탕: 옅은 치마 아낙", "모자 없는 흰옷 바탕", 37),
    "npc_base_boy": ("바탕: 사내아이", "모자 없는 흰옷 바탕", 30),
    "npc_head_carrier": ("머리에 인 아낙 상인", "market woman in a white jeogori and gray-blue skirt carrying a big round basket of goods on her head", 38),
    "npc_yeot_seller": ("엿장수", "yeot taffy seller in white clothes and a straw hat with a wide wooden tray of yeot hung from his neck", 40),
    "npc_tteok_seller": ("떡장수 아낙", "rice-cake seller woman with a white head cloth carrying a wooden tray of colorful tteok", 37),
    "npc_fish_seller": ("생선 장수", "fish peddler in rolled-up white trousers carrying a straw rope of dried yellow croakers and a fish basket", 39),
    "npc_butcher": ("고기 장수", "butcher in a short white jacket and a leather apron with a big knife at the belt", 40),
    "npc_medicine_seller": ("약장수", "traveling medicine seller in a gray robe and black gat with a small wooden medicine chest on his back", 40),
    "npc_physician": ("의원", "village physician with a short beard", 40),
    "npc_drunkard": ("취객", "cheerful drunkard with a red face", 40),
    "npc_grandpa": ("할아버지", "old grandfather with a long white beard and a stooped back", 37),
    "npc_grandma": ("할머니", "old grandmother with a small white bun and a bent back", 35),
    "npc_mother_baby": ("아기 업은 아낙", "young mother in a pale jeogori and long skirt carrying a baby on her back wrapped in a cloth (podaegi)", 37),
    "npc_porter": ("짐꾼", "porter in white hemp clothes carrying a tall wooden A-frame (jige) loaded with bundles on his back", 40),
    "npc_woodcutter": ("나무꾼", "woodcutter in white clothes with a jige loaded with firewood and a sickle at his waist", 39),
    "npc_salt_porter": ("소금 지게꾼", "salt carrier in white clothes with a jige of straw salt sacks", 39),
    "npc_monk": ("스님", "Buddhist monk in gray robes with a shaved head", 39),
    "npc_ajeon": ("아전", "local government clerk (ajeon) in a light blue robe and a black gat with a record book under his arm", 40),
    "npc_book_peddler": ("책쾌(책장수)", "book peddler in a black gat with a big wrapped bundle of thread-bound books on his back", 40),
    "npc_simmani": ("심마니", "ginseng hunter in rough clothes and a straw hat with a long digging stick and a small basket", 39),
    "npc_jumo": ("주모", "tavern keeper woman with a bun", 37),
    "npc_refugee": ("유민", "poor refugee in torn gray clothes carrying a cloth bundle and walking with a stick", 37),
    "npc_pungmul_player": ("풍물잡이(상모)", "pungmul farmers' band player in white clothes with red", 40),
    "npc_pungmul_drummer": ("풍물잡이(장구)", "pungmul band drummer in white clothes with colored sashes and a paper-flower hat", 40),
    "npc_champion": ("천하장사", "ssireum champion with a flower crown and a red sash over his bare chest", 42),
    "npc_hunter": ("사냥꾼(포수)", "hunter in a fur cap and gray clothes carrying a matchlock musket on his shoulder and a gunpowder pouch", 40),
    "npc_chakhogapsa": ("착호갑사", "tiger-hunting soldier in a red felt jeollip hat and armored coat with a long spear", 40),
    "npc_firefighter": ("멸화군", "fire brigade soldier in a black hat and blue uniform carrying a wooden water bucket and a long fire hook", 40),
    "npc_bandit": ("화적(도적떼)", "bandit with a red headband", 40),
    "npc_messenger": ("파발 전령", "royal relay courier (pabal) in a black felt jeollip hat with a red tassel, a short dark navy military jacket with red cuffs, gray leggings and boots, a yellow cloth dispatch pouch slung across the chest", 40),
    "npc_beater": ("몰이꾼", "hunting beater in white clothes with a red headband banging a small gong and holding a stick", 39),
    "animal_tiger": ("호랑이", "Korean tiger", 26),
    "animal_boar": ("멧돼지", "wild boar", 22),
    "animal_deer": ("사슴", "spotted sika deer with small antlers", 32),
    "animal_wolf": ("늑대", "gray Korean wolf", 24),
    "animal_dog": ("개(백구)", "white Korean Jindo dog with a curled tail", 18),
    "animal_ox": ("황소", "brown Korean hanwoo ox with short horns", 30),
    "animal_horse": ("말", "brown pony with a red saddle cloth and bridle", 36),
    "animal_crane": ("학", "red-crowned crane", 30),
    "animal_rabbit": ("토끼", "small brown wild rabbit", 12),
}

# ------------------------------------------------------------------ 동작 그림: 이름 → (칸 수, 키 px, 한글 이름, 묘사)
# 이름이 "_pair"로 끝나면 두 사람(또는 큰 탈것)을 한 칸(96x48)에. 그 밖은 48x48 칸, 화면 왼쪽(아래)을 보는 그림.
## PORT-TRACE [물품 그림]: 공방 도구·짐·장터 물건 — art_inbox/goods/*.png → assets/sprites/goods/<id>.png (정사각 캔버스, 바닥 가운데)
GOODS: dict[str, tuple[int, str]] = {
    "anvil": (24, "모루와 망치"),
    "workbench": (28, "목공 작업대"),
    "stone_block": (24, "다듬던 화강암"),
    "dye_vat": (24, "쪽물 독"),
    "dyed_cloth": (32, "물들인 천 장대"),
    "paper_vat": (28, "한지 뜨는 지통"),
    "log_bundle": (28, "통나무 짐"),
    "roof_tiles": (24, "기와 한 짐"),
    "crate": (24, "나무 궤짝"),
    "bundle": (20, "보자기 보따리"),
    "rice_sack": (24, "쌀가마니"),
    "salt_sack": (24, "소금 섬"),
    "onggi": (28, "옹기 항아리"),
    "brassware": (24, "놋그릇 한 벌"),
    "silk_bolt": (24, "비단 필"),
    "straw_shoes": (24, "짚신 꾸러미"),
    "gat": (24, "갓"),
    "herb_pack": (24, "약첩 꾸러미"),
    "yeot_tray": (28, "엿판과 가위"),
    "tteok": (24, "떡 시루"),
    "dried_fish": (28, "굴비 두름"),
    "fish_basket": (24, "생선 광주리"),
    "fruit_basket": (24, "과일 광주리"),
    "makgeolli": (24, "막걸리 동이"),
    "book_open": (20, "펼친 선장본 책"),
    "book_stack": (20, "선장본 책 더미"),
    "seoan": (28, "서안(낮은 책상)"),
    "painting_sheet": (28, "그림 그린 화지·벼루"),
    "scarecrow": (32, "허수아비"),
    "hyeongteul": (32, "형틀"),
}

ACTIONS: dict[str, tuple[int, int, str, str]] = {
    "act_ssireum_pair": (4, 40, "씨름 두 장사", "two bare-chested ssireum wrestlers in white trousers with satba belts gripping each other's belts: 1) locked shoulder to shoulder, 2) one lifts the other off the ground, 3) swinging him around, 4) throwing him down to the sand"),
    "npc_taekkyeon__kick": (4, 40, "택견 발차기", "taekkyeon fighter in white clothes and straw headband: 1) bouncing stance, 2) stepping forward, 3) high kick with the front leg, 4) landing back in stance"),
    "act_pungmul_sangmo": (4, 40, "풍물패 상모돌리기", "pungmul farmers' band player in white clothes with red, blue and yellow sashes and a sangmo hat with a long white ribbon, playing a small gong (kkwaenggwari): 1) knees bent, ribbon to the left, 2) hopping, ribbon circling up, 3) ribbon to the right, 4) hopping, ribbon circling down"),
    "act_lion_dance_pair": (4, 40, "사자춤(두 사람이 쓴 사자)", "Korean bukcheong lion dance: a shaggy lion costume worn by two dancers (only their legs show) with a big red-faced lion mask: 1) standing, 2) rearing its head up, 3) shaking its mane, 4) crouching low"),
    "act_talchum": (4, 40, "탈춤", "talchum mask dancer in a yellow robe with very long white sleeves and a white wooden mask with red cheeks: 1) arms out, sleeves flowing, 2) one leg raised, 3) sleeves flung overhead, 4) spinning"),
    "act_rope_walker": (4, 40, "남사당 줄타기 어름사니", "namsadang tightrope walker in white clothes with a red sash holding an open red fan, balancing on a thin rope (draw only a short piece of rope under the feet): 1) balancing, 2) stepping, 3) bouncing up from the rope, 4) sitting down on the rope"),
    "act_ganggang": (4, 38, "강강술래 아낙", "village woman in a white jeogori and colorful long skirt dancing ganggangsullae, both arms stretched out sideways as if holding neighbors' hands: 1) step left, 2) step right, 3) arms swinging up, 4) skirt twirling"),
    "npc_kite_flyer__fly": (4, 32, "연날리는 아이(날리기)", "boy with a yellow headband flying a kite: holding a wooden kite reel, looking up toward the upper-left, the kite string going up and out of the picture: 1) holding, 2) pulling the string, 3) letting out string, 4) stepping back"),
    "act_jwibul": (4, 32, "쥐불놀이 아이", "boy in winter clothes swinging a can of glowing embers on a string in a big circle (jwibulnori): 1) can low, 2) can to the side, 3) can overhead, 4) can on the other side, with orange sparks"),
    "act_paengi": (4, 30, "팽이 치는 아이", "child whipping a spinning wooden top on ice with a small whip: 1) whip raised, 2) whip striking, 3) watching the top, 4) whip raised again"),
    "act_jegi": (4, 30, "제기차기 아이", "child kicking a jegi shuttlecock with the inner foot: 1) jegi in the air, 2) foot raised kicking, 3) jegi high, 4) hopping"),
    "npc_jeongisu__tell": (4, 40, "전기수 이야기", "storyteller (jeongisu) in a white robe and black gat sitting cross-legged on a straw mat with an open book, telling a story with dramatic gestures: 1) reading, 2) raising the fan, 3) slapping the knee, 4) pointing forward"),
    "npc_peasant_woman__wash": (4, 24, "빨래하는 아낙", "village woman with a white head cloth kneeling at a stream, washing clothes on a flat stone with a wooden laundry paddle: 1) paddle raised, 2) paddle striking, 3) rinsing the cloth, 4) wringing the cloth"),
    "npc_fisherman__fish": (4, 28, "낚시하는 어부", "fisherman in a straw hat sitting on a low stone holding a long fishing rod over water to the lower-left: 1) waiting, 2) rod twitching, 3) pulling up, 4) a small fish on the line"),
    "npc_soldier__attack": (4, 40, "장용영 창 찌르기", "Jangyongyeong soldier in a black jeollip hat and studded armored coat with a long spear: 1) guard stance, 2) stepping in, 3) thrusting the spear far forward, 4) pulling back"),
    "npc_soldier__shoot": (4, 40, "장용영 조총 사격", "Jangyongyeong soldier with a matchlock musket: 1) loading, 2) aiming, 3) firing with a flash and smoke, 4) lowering the musket"),
    "npc_thief__steal": (4, 39, "도둑 훔치기", "thief in dark clothes with a black headband and cloth mask: 1) crouching and sneaking, 2) reaching out, 3) grabbing a cloth bundle, 4) tucking it under the arm"),
    "npc_thief__run": (4, 39, "도둑 도주", "the same thief running away fast carrying a stolen cloth bundle on his back: four running frames"),
    "npc_thief__bound": (4, 39, "포박된 죄인", "the same thief with hands tied behind his back by a thick rope (oraeul), head down, walking: four walking frames, rope trailing behind"),
    "npc_brawler__punch": (4, 40, "왈짜 주먹질", "rough street brawler with a topknot and earth-brown clothes, sleeves rolled up: 1) fists up, 2) throwing a punch, 3) full punch, 4) pulling back"),
    "npc_farmer__hoe": (4, 39, "괭이질하는 농부", "farmer in a straw satgat and white hemp clothes working the field with a hoe: 1) hoe raised, 2) swinging down, 3) hoe in the soil, 4) pulling back"),
    "npc_hunter__shoot": (4, 40, "포수 조총 사격", "hunter in a fur cap and gray clothes with a matchlock musket: 1) kneeling and loading, 2) aiming, 3) firing with a flash and white smoke, 4) lowering the musket"),
    "npc_bandit__attack": (4, 40, "화적 칼 휘두르기", "bandit with a red headband and rough dark clothes swinging a curved sword: 1) sword raised, 2) slashing, 3) follow-through, 4) guard stance"),
    "npc_patrol__subdue": (4, 40, "포졸 육모방망이 제압", "patrol constable (pojol) in a black jeollip hat and blue uniform swinging a hexagonal wooden club (yungmo-bangmangi): 1) club raised, 2) striking down, 3) pressing down, 4) club raised again"),
    "npc_soldier__bow": (4, 40, "장용영 활쏘기", "Jangyongyeong soldier in a black jeollip hat and armored coat shooting a Korean horn bow: 1) nocking an arrow, 2) drawing the bow, 3) releasing, 4) reaching for the next arrow"),
    "npc_artisan_blacksmith__hammer": (4, 39, "망치질하는 대장장이", "blacksmith in a leather apron hammering on an anvil (draw the small anvil): 1) hammer raised, 2) swinging, 3) striking with sparks, 4) lifting again"),
}

def _korean_lookup() -> dict[str, tuple[str, str]]:
    """한글 이름 → (종류, 영문 이름)"""
    out = {}
    for k, (_, kn) in BUILDINGS.items():
        out[kn] = ("b", k)
    for k, v in NAMED.items():
        out[v[0]] = ("n", k)
    for k, v in GENERIC.items():
        out[v[0]] = ("g", k)
    return out

KOREAN = _korean_lookup()

# ------------------------------------------------------------------ 이미지 처리
def _dist2(a, b) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2

def remove_background(img: Image.Image, tol: int = 30) -> Image.Image:
    """가장자리에서 시작해 배경색(단색·체커보드)과 비슷한 칸을 투명하게. 이미 투명 배경이면 그대로."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    border = [px[x, y] for x in range(w) for y in (0, h - 1)] + [px[x, y] for y in range(h) for x in (0, w - 1)]
    if sum(1 for p in border if p[3] < 20) > len(border) * 0.6:
        return img  # 이미 투명 배경
    # 가장자리에 많은 색 최대 3개(체커보드 두 색 + 여분)
    buckets: dict[tuple, int] = {}
    for p in border:
        key = (p[0] // 12, p[1] // 12, p[2] // 12)
        buckets[key] = buckets.get(key, 0) + 1
    tops = sorted(buckets.items(), key=lambda kv: -kv[1])[:3]
    bgs = [(k[0] * 12 + 6, k[1] * 12 + 6, k[2] * 12 + 6) for k, n in tops if n > len(border) * 0.05]
    # 그림 전체를 넓게 덮는 무채색(체커보드·회색 판)도 배경으로 본다 — 칸마다 구분선에 막혀 테두리에서 닿지 않는 경우
    thumb = img.convert("RGB").resize((max(1, w // 4), max(1, h // 4)), Image.NEAREST)
    hist: dict[tuple, int] = {}
    for p in (thumb.get_flattened_data() if hasattr(thumb, "get_flattened_data") else thumb.getdata()):
        if max(p) - min(p) <= 14:
            key = (p[0] // 8, p[1] // 8, p[2] // 8)
            hist[key] = hist.get(key, 0) + 1
    total = thumb.width * thumb.height
    keyed = [(k[0] * 8 + 4, k[1] * 8 + 4, k[2] * 8 + 4) for k, n in hist.items() if n > total * 0.06]
    t2 = tol * tol
    k2 = 14 * 14

    def is_bg(p) -> bool:
        return p[3] < 20 or any(_dist2(p, b) <= t2 for b in bgs) or any(_dist2(p, b) <= k2 for b in keyed)

    seen = bytearray(w * h)
    q = deque()
    if keyed:  # 넓은 무채색 판은 테두리에 안 닿아도 지운다
        for y in range(h):
            for x in range(w):
                p = px[x, y]
                if any(_dist2(p, b) <= k2 for b in keyed):
                    q.append((x, y))
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        p = px[x, y]
        if not is_bg(p):
            continue
        px[x, y] = (0, 0, 0, 0)
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    return img

def _odd(n: int) -> int:
    return n if n % 2 else n + 1

def strip_thin_lines(img: Image.Image, reach: int = 3) -> Image.Image:
    """격자선·구분선 같은 가는 선을 지운다: 열림 연산으로 몸통만 남긴 뒤, 몸통 가까이(창·지팡이 같은 소품)는 살리고 멀리 떨어진 가는 선만 버린다."""
    a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    k = _odd(max(3, round(max(img.size) / 400)))
    body = a.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))
    keep = body.filter(ImageFilter.MaxFilter(_odd(k * reach)))
    from PIL import ImageChops
    img.putalpha(ImageChops.multiply(img.getchannel("A"), keep))
    return img

def remove_watermark(img: Image.Image) -> Image.Image:
    """Gemini 워터마크(오른쪽 아래의 작은 흰 별 ✦, 한두 개)를 배경색으로 덮는다. 배경 지우기 전에 부른다.
    오른쪽 아래 1/4 영역에서 순백에 가까운 작은 덩어리(그림 폭의 6% 이하)만 골라, 둘레 2px까지 구석 배경색으로 칠한다."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    bg = px[w - 3, h - 3]
    lite = min(235, max(bg[0], bg[1], bg[2]) + 9) # 배경보다 눈에 띄게 밝은 무채색(반투명 별 포함)
    x0, y0 = int(w * 0.72), int(h * 0.72)
    rw, rh = w - x0, h - y0
    white = bytearray(rw * rh)
    for y in range(rh):
        for x in range(rw):
            r, g, b, a = px[x0 + x, y0 + y]
            if a > 0 and min(r, g, b) > lite and max(r, g, b) - min(r, g, b) < 18:
                white[y * rw + x] = 1
    seen = bytearray(rw * rh)
    limit = max(w, h) * 0.06
    for st in range(rw * rh):
        if not white[st] or seen[st]:
            continue
        q = deque([st])
        seen[st] = 1
        pts = []
        while q:
            i = q.popleft()
            pts.append(i)
            x, y = i % rw, i // rw
            for j in (i - 1 if x > 0 else -1, i + 1 if x < rw - 1 else -1, i - rw if y > 0 else -1, i + rw if y < rh - 1 else -1):
                if j >= 0 and white[j] and not seen[j]:
                    seen[j] = 1
                    q.append(j)
        xs = [i % rw for i in pts]
        ys = [i // rw for i in pts]
        bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        if bw > limit or bh > limit or len(pts) < 12:
            continue
        for yy in range(max(0, min(ys) - 3), min(rh, max(ys) + 4)):
            for xx in range(max(0, min(xs) - 3), min(rw, max(xs) + 4)):
                r, g, b, a = px[x0 + xx, y0 + yy]
                if min(r, g, b) > 150 and max(r, g, b) - min(r, g, b) < 30:
                    px[x0 + xx, y0 + yy] = bg
    return img

def find_objects(img: Image.Image, min_ratio: float = 0.04) -> list[tuple[int, int, int, int]]:
    """불투명 덩어리들의 상자(x0,y0,x1,y1). 작게 줄인 지도에서 가까운 조각(나무·소품)은 한 덩어리로 묶는다."""
    w, h = img.size
    f = max(1, round(max(w, h) / 300))
    sw, sh = (w + f - 1) // f, (h + f - 1) // f
    a_full = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    k = _odd(max(3, round(max(w, h) / 400)))
    body = a_full.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))  # 가는 선·토막을 뺀 몸통
    a = body.resize((sw, sh), Image.BOX).load()
    occ = bytearray(sw * sh)
    for y in range(sh):
        for x in range(sw):
            if a[x, y] > 60:
                occ[y * sw + x] = 1
    lab = [0] * (sw * sh)
    boxes = []
    for start in range(sw * sh):
        if not occ[start] or lab[start]:
            continue
        cid = len(boxes) + 1
        q = deque([start])
        lab[start] = cid
        x0, y0, x1, y1, area = sw, sh, 0, 0, 0
        while q:
            i = q.popleft()
            x, y = i % sw, i // sw
            area += 1
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
            for j in (i - 1 if x > 0 else -1, i + 1 if x < sw - 1 else -1, i - sw if y > 0 else -1, i + sw if y < sh - 1 else -1):
                if j >= 0 and occ[j] and not lab[j]:
                    lab[j] = cid
                    q.append(j)
        boxes.append((area, (x0 * f, y0 * f, min(w, (x1 + 1) * f), min(h, (y1 + 1) * f))))
    if not boxes:
        return []
    big = max(b[0] for b in boxes)
    boxes = [(ar, bb) for ar, bb in boxes if ar >= big * min_ratio]
    tall = max(bb[3] - bb[1] for ar, bb in boxes)
    return [bb for ar, bb in boxes if bb[3] - bb[1] >= tall * 0.22]  # 납작한 덩어리(글씨·제목)는 버림

def attach_small_parts(boxes):
    """인물 그림에서 몸보다 작은 따로 떨어진 조각(연·깃발·소품 — 가는 줄이 지워져 떨어져 나온 것)을
    가장 가까운 인물 상자에 합친다. 큰 상자 = 가장 큰 높이의 60% 이상."""
    if len(boxes) < 2:
        return boxes
    tall = max(b[3] - b[1] for b in boxes)
    big = [list(b) for b in boxes if b[3] - b[1] >= tall * 0.6]
    small = [b for b in boxes if b[3] - b[1] < tall * 0.6]
    for sb in small:
        sx, sy = (sb[0] + sb[2]) / 2, (sb[1] + sb[3]) / 2
        def gap(bb):
            dx = max(bb[0] - sx, 0, sx - bb[2])
            dy = max(bb[1] - sy, 0, sy - bb[3])
            return dx * dx + (dy * 1.5) ** 2
        tgt = min(big, key=gap)
        tgt[0], tgt[1] = min(tgt[0], sb[0]), min(tgt[1], sb[1])
        tgt[2], tgt[3] = max(tgt[2], sb[2]), max(tgt[3], sb[3])
    return [tuple(b) for b in big]

def split_row_bins(img: Image.Image, row: list, n: int) -> list:
    """한 줄을 가로로 n등분해 칸마다 그림이 있는 부분만 잘라 낸다(Gemini는 장면을 고른 간격으로 그린다).
    물체가 서로 붙거나(돗자리) 쪼개져(가는 다리·불똥) 칸 수가 어긋날 때 쓴다."""
    ux0, uy0, ux1, uy1 = union(row)
    w = (ux1 - ux0) / n
    out = []
    a = img.getchannel("A")
    for i in range(n):
        bx0, bx1 = int(ux0 + i * w), int(ux0 + (i + 1) * w)
        bb = a.crop((bx0, uy0, bx1, uy1)).point(lambda v: 255 if v > 40 else 0).getbbox()
        if bb:
            out.append((bx0 + bb[0], uy0 + bb[1], bx0 + bb[2], uy0 + bb[3]))
    return out if len(out) == n else row

def reading_order(boxes):
    """위→아래 행으로 묶고, 행 안에서 왼→오른"""
    rows: list[list] = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        cy = (b[1] + b[3]) / 2
        for r in rows:
            ry0 = min(x[1] for x in r)
            ry1 = max(x[3] for x in r)
            if ry0 <= cy <= ry1:
                r.append(b)
                break
        else:
            rows.append([b])
    return [sorted(r, key=lambda b: b[0]) for r in rows]

def grid_boxes(img: Image.Image, cols: int, rows: int):
    w, h = img.size
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            cell = (c * w // cols, r * h // rows, (c + 1) * w // cols, (r + 1) * h // rows)
            bb = img.crop(cell).getchannel("A").getbbox()
            if bb:
                row.append((cell[0] + bb[0], cell[1] + bb[1], cell[0] + bb[2], cell[1] + bb[3]))
        out.append(row)
    return out

def union(boxes):
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))

def shrink(img: Image.Image, size) -> Image.Image:
    """알파를 곱한 채로 면적 평균 축소(가장자리 테두리 번짐 방지) → 살짝 선명하게"""
    sm = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    rgb = sm.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1, percent=45, threshold=2))
    rgb.putalpha(sm.getchannel("A"))
    return rgb

def harden_alpha(img: Image.Image, cut: int = 110) -> Image.Image:
    img.putalpha(img.getchannel("A").point(lambda v: 255 if v >= cut else 0))
    return img

def quantize(img: Image.Image, colors: int) -> Image.Image:
    return img.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)

def keep_main(img: Image.Image, ratio: float = 0.03) -> Image.Image:
    """잘라낸 그림에서 본체와 떨어진 작은 조각(워터마크 ✦·글씨 부스러기)을 지운다. 가장 큰 덩어리의 ratio보다 작은 덩어리만."""
    w, h = img.size
    f = max(1, round(max(w, h) / 220))
    sw, sh = (w + f - 1) // f, (h + f - 1) // f
    a = img.getchannel("A").resize((sw, sh), Image.BOX).load()
    occ = bytearray(sw * sh)
    for y in range(sh):
        for x in range(sw):
            if a[x, y] > 30:
                occ[y * sw + x] = 1
    lab = [0] * (sw * sh)
    areas = [0]
    for st in range(sw * sh):
        if not occ[st] or lab[st]:
            continue
        cid = len(areas)
        areas.append(0)
        q = deque([st])
        lab[st] = cid
        while q:
            i = q.popleft()
            areas[cid] += 1
            x, y = i % sw, i // sw
            for j in (i - 1 if x > 0 else -1, i + 1 if x < sw - 1 else -1, i - sw if y > 0 else -1, i + sw if y < sh - 1 else -1):
                if j >= 0 and occ[j] and not lab[j]:
                    lab[j] = cid
                    q.append(j)
    if len(areas) <= 2:
        return img
    big = max(areas)
    small = Image.new("L", (sw, sh), 255)
    sp = small.load()
    for i in range(sw * sh):
        if lab[i] and areas[lab[i]] < big * ratio:
            sp[i % sw, i // sw] = 0
    mask = small.resize((w, h), Image.NEAREST).filter(ImageFilter.MinFilter(3))
    from PIL import ImageChops
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    return img

def fit_building(obj: Image.Image, canvas) -> Image.Image:
    W, H = canvas
    w, h = obj.size
    s = min(W / w, H / h)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    small = harden_alpha(shrink(obj, (nw, nh)))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(small, ((W - nw) // 2, H - nh))
    return out

def outline(img: Image.Image, col=(28, 20, 16, 255)) -> Image.Image:
    a = img.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(3))
    ring = Image.new("RGBA", img.size, col)
    ring.putalpha(grown)
    ring.alpha_composite(img)
    return ring

def npc_frame(pose: Image.Image, s: float, bob: int = 0) -> Image.Image:
    w, h = pose.size
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    fig = outline(harden_alpha(shrink(pose, (nw, nh))))
    cell = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(cell)
    d.ellipse((24 - 10, 45 - 3, 24 + 10, 45 + 2), fill=(30, 36, 22, 90))  # 발밑 그림자
    cell.alpha_composite(fig, (24 - fig.width // 2, 46 - fig.height - bob))
    return cell

def action_cell(pose: Image.Image, s: float, cw: int) -> Image.Image:
    w, h = pose.size
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    fig = outline(harden_alpha(shrink(pose, (nw, nh))))
    cell = Image.new("RGBA", (cw, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(cell)
    d.ellipse((cw // 2 - cw // 5, 42, cw // 2 + cw // 5, 47), fill=(30, 36, 22, 90))
    cell.alpha_composite(fig, (cw // 2 - fig.width // 2, 46 - fig.height))
    return cell

def write_action(aid: str, frames: list, check: bool, results: list) -> None:
    pair = aid.endswith("_pair")
    cw = 96 if pair else 48
    if not pair and facing_left(frames[0]) is False:
        frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
    height = ACTIONS[aid][1]
    tallest = max(f.height for f in frames)
    widest = max(f.width for f in frames)
    sc = min(height / tallest, (cw - 4) / widest)
    sheet = Image.new("RGBA", (cw * len(frames), 48), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(action_cell(f, sc, cw), (i * cw, 0))
    save_png(sheet, os.path.join(SPRITES, "npcs", "actions", aid + ".png"), 32, check)
    results.append((aid, sheet))

WALK_BOB: set[str] = set() # txt에 walk=bob을 붙인 인물: 걷는 그림 대신 서 있는 그림 + 1px 들썩임

def _thumb(im: Image.Image) -> list:
    t = im.convert("RGBa").resize((24, 32), Image.BOX)
    return list(t.get_flattened_data() if hasattr(t, "get_flattened_data") else t.getdata())

def flip_matches_better(ref: Image.Image, im: Image.Image) -> bool:
    """im을 좌우로 뒤집었을 때 ref와 더 닮으면 True(같은 인물·같은 방향이어야 할 두 자세 맞추기)"""
    a = _thumb(ref)
    d0 = sum(abs(p[k] - q[k]) for p, q in zip(a, _thumb(im)) for k in range(4))
    d1 = sum(abs(p[k] - q[k]) for p, q in zip(a, _thumb(im.transpose(Image.FLIP_LEFT_RIGHT))) for k in range(4))
    return d1 < d0 * 0.97

def facing_left(im: Image.Image):
    """앞모습이 화면 왼쪽을 보는지: 머리 부분(위 45%)에서 피부색 픽셀의 무게중심이 몸 중심보다 왼쪽이면 True, 오른쪽이면 False, 모르면 None"""
    w, h = im.size
    px = im.convert("RGBA").load()
    top = int(h * 0.45)
    sx = sn = 0
    ox = on = 0
    for y in range(top):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            ox += x
            on += 1
            if r > 140 and g > 90 and b > 55 and r > g > b and r - b > 35 and r - g < 75:
                sx += x
                sn += 1
    if sn < max(12, on * 0.02) or on == 0:
        return None
    off = (sx / sn - ox / on) / max(1.0, w)
    if abs(off) < 0.02:
        return None
    return off < 0.0

def orient_four(poses: list, animal: bool = False) -> list:
    """[앞 서기, 앞 걷기, 뒤 서기, 뒤 걷기]의 방향을 맞춘다: 앞모습은 왼쪽 아래를 보게, 걷기는 서기와 같은 방향으로."""
    flip = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    f0, f1, b0, b1 = poses[:4]
    if not animal and facing_left(f0) is False:
        f0 = flip(f0)
    fl1 = None if animal else facing_left(f1)
    if fl1 is False or (fl1 is None and flip_matches_better(f0, f1)):
        f1 = flip(f1)
    if flip_matches_better(b0, b1):
        b1 = flip(b1)
    return [f0, f1, b0, b1]

def build_npc_sheet(poses: list[Image.Image], height: int, animal: bool = False) -> Image.Image:
    """자세 2개 [앞 서기, 뒤 서기] → 좌우 뒤집어 4방향(걸음은 1px 들썩임)
    / 4개 [앞 서기, 앞 걷기, 뒤 서기, 뒤 걷기] → 좌우 뒤집어 4방향 × 실제 걸음 2동작 (권장, PROMPTS.md 방식)
    / 8개 = [앞-왼 서기·걷기, 앞-오 서기·걷기, 뒤-왼 서기·걷기, 뒤-오 서기·걷기].
    시트(96x192): 행0 앞-왼(↙), 행1 앞-오(↘), 행2 뒤-왼(↖), 행3 뒤-오(↗) / 열 = 걸음 동작 0·1"""
    n = len(poses)
    flip = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    if n == 1:
        dirs = [[poses[0]], [flip(poses[0])], [poses[0]], [flip(poses[0])]]
    elif n in (2, 3):
        dirs = [[poses[0]], [flip(poses[0])], [poses[1]], [flip(poses[1])]]
    elif n < 8:
        poses = orient_four(poses, animal)
        dirs = [[poses[0], poses[1]], [flip(poses[0]), flip(poses[1])], [poses[2], poses[3]], [flip(poses[2]), flip(poses[3])]]
    else:
        dirs = [[poses[0], poses[1]], [poses[2], poses[3]], [poses[4], poses[5]], [poses[6], poses[7]]]
    tallest = max(p.height for d in dirs for p in d)
    widest = max(p.width for d in dirs for p in d)
    s = min(height / tallest, 44 / widest)
    sheet = Image.new("RGBA", (96, 192), (0, 0, 0, 0))
    for r, d in enumerate(dirs):
        f0 = npc_frame(d[0], s)
        f1 = npc_frame(d[1], s) if len(d) > 1 else npc_frame(d[0], s, bob=1)  # 2동작이 없으면 1px 들썩임
        sheet.alpha_composite(f0, (0, r * 48))
        sheet.alpha_composite(f1, (48, r * 48))
    return sheet

# ------------------------------------------------------------------ 저장
def backup_once(path: str) -> None:
    rel = os.path.relpath(path, SPRITES)
    dst = os.path.join(BACKUP, rel)
    if os.path.exists(path) and not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(path, dst)

def save_png(img: Image.Image, path: str, colors: int, check: bool) -> None:
    if check:
        return
    backup_once(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    quantize(img, colors).save(path, optimize=True)

def resolve(name: str, kind: str) -> str | None:
    name = name.strip()
    if kind == "b":
        if name in BUILDINGS:
            return name
        hit = KOREAN.get(name)
        return hit[1] if hit and hit[0] == "b" else None
    key = name.removeprefix("named_")
    if key in NAMED:
        return "named:" + key
    for canon, al in NAMED_ALIASES.items():
        if key in al or "named_" + key in al:
            return "named:" + canon
    if name in GENERIC or "npc_" + name in GENERIC:
        return "gen:" + (name if name in GENERIC else "npc_" + name)
    hit = KOREAN.get(name)
    if hit and hit[0] == "n":
        return "named:" + hit[1]
    if hit and hit[0] == "g":
        return "gen:" + hit[1]
    return None

def write_building(key: str, img: Image.Image, check: bool, results: list) -> None:
    cells, _ = BUILDINGS[key]
    out = fit_building(keep_main(img), CANVAS[cells])
    try:  # 땅 판 옆면(흙·석축 단면)을 지우고 내려 윗면이 게임 땅에 붙게(tools/flatten_base.py)
        import flatten_base
        out = flatten_base.flatten(out)[0]
    except Exception as e:
        print("  ⚠ 땅 판 정리 못 함:", key, e)
    for k in [key] + BUILDING_TWINS.get(key, []):
        save_png(out, os.path.join(SPRITES, "buildings", k + ".png"), 64, check)
        if not check: # 겨울판(눈 덮인 지붕)도 새 그림으로 다시
            try:
                import make_winter
                make_winter.main([k])
            except Exception as e:
                print("  ⚠ 겨울판 못 만듦:", k, e)
    results.append((key, out))

def write_goods(gid: str, img: Image.Image, check: bool, results: list) -> None:
    size = GOODS[gid][0]
    obj = keep_main(img)
    bb = obj.getbbox()
    if bb:
        obj = obj.crop(bb)
    s = min((size - 2) / obj.width, (size - 2) / obj.height)
    fig = outline(harden_alpha(shrink(obj, (max(1, round(obj.width * s)), max(1, round(obj.height * s))))))
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell.alpha_composite(fig, ((size - fig.width) // 2, size - fig.height - 1))
    save_png(cell, os.path.join(SPRITES, "goods", gid + ".png"), 32, check)
    results.append((gid, cell))

def write_npc(key: str, poses: list[Image.Image], height: int | None, check: bool, results: list) -> None:
    kind, nid = key.split(":")
    h = height or (NAMED[nid][2] if kind == "named" else GENERIC[nid][2])
    if (nid in WALK_BOB or any(resolve(w, "n") == key for w in WALK_BOB if w)) and len(poses) >= 4:
        poses = [poses[0], poses[2]] # 걷는 그림이 어긋나면 서 있는 그림만(들썩임 걸음)
    elif len(poses) == 2 and not nid.startswith("animal_") and facing_left(poses[0]) is False:
        poses = [poses[0].transpose(Image.FLIP_LEFT_RIGHT), poses[1]]
    sheet = build_npc_sheet(poses, h, nid.startswith("animal_"))
    front = sheet.crop((0, 0, 48, 48))
    if kind == "named":
        names = ["named_" + nid, nid] + NAMED_ALIASES.get(nid, [])
        base = os.path.join(SPRITES, "npcs", "named")
    else:
        names = [nid]
        base = os.path.join(SPRITES, "npcs")
    for n in names:
        save_png(sheet, os.path.join(base, n + ".png"), 32, check)
        save_png(front, os.path.join(base, n + "_front.png"), 32, check)
    results.append((nid, sheet))

def read_list(txt: str):
    grid = None
    items = []
    for line in open(txt, encoding="utf-8-sig"):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.fullmatch(r"grid\s*=\s*(\d+)\s*[xX×]\s*(\d+)", line)
        if m:
            grid = (int(m.group(1)), int(m.group(2)))
            continue
        if re.search(r"walk\s*=\s*bob", line):
            line = re.sub(r"walk\s*=\s*bob", "", line)
            WALK_BOB.add(line.split()[0].removeprefix("named_") if line.split() else "")
        hm = re.search(r"height\s*=\s*(\d+)", line)
        pm = re.search(r"poses\s*=\s*([\d,\s]+)", line)
        name = re.sub(r"(height|poses)\s*=\s*[\d,\s]+", "", line).strip()
        poses = [int(v) for v in re.findall(r"\d+", pm.group(1))] if pm else None
        items.append((name, int(hm.group(1)) if hm else None, poses))
    return grid, items

def process(check: bool) -> None:
    results: list = []
    problems: list[str] = []
    for kind_dir, kind in (("buildings", "b"), ("npcs", "n"), ("actions", "a"), ("goods", "g"), ("gazette", "z")):
        folder = os.path.join(INBOX, kind_dir)
        if not os.path.isdir(folder):
            continue
        for fn in sorted(os.listdir(folder)):
            stem, ext = os.path.splitext(fn)
            if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            src = os.path.join(folder, fn)
            txt = os.path.join(folder, stem + ".txt")
            print(f"· {kind_dir}/{fn}")
            img = Image.open(src)
            if max(img.size) > 2200:
                r = 2200 / max(img.size)
                img = img.resize((round(img.width * r), round(img.height * r)), Image.LANCZOS)
            raw = img.convert("RGB")  # 기사 그림은 종이 바탕째 원본에서 잘라 쓴다(물표는 회색 틈에 있어 잘리지 않음)
            img = strip_thin_lines(remove_background(remove_watermark(img)), 1 if kind in ("b", "g", "z") else 3)
            grid, items = read_list(txt) if os.path.exists(txt) else (None, [(stem, None, None)])
            if grid:
                rows = grid_boxes(img, *grid)
            else:
                boxes = find_objects(img)
                rows = reading_order(attach_small_parts(boxes) if kind in ("n", "a") else boxes)
            ok = True
            if kind == "a":
                if len(rows) != len(items):
                    problems.append(f"{fn}: 찾은 동작 줄 {len(rows)}개 ≠ 목록 {len(items)}개 — 이 장은 저장하지 않았습니다 (다시 생성하세요)")
                    continue
                bad = False
                for (name, _, _), row in zip(items, rows):
                    if name not in ACTIONS:
                        problems.append(f"{fn}: 모르는 동작 이름 '{name}'")
                        bad = True
                        continue
                    want = ACTIONS[name][0]
                    if name.endswith("_pair") and len(row) == want * 2:
                        row[:] = [union([row[k], row[k + 1]]) for k in range(0, len(row), 2)] # 떨어진 두 사람을 한 칸으로
                    if len(row) != want:
                        row[:] = split_row_bins(img, row, want)
                    if len(row) != want:
                        problems.append(f"{fn}: '{ACTIONS[name][2]}' 칸 {len(row)}개 ≠ {want}개 — 이 장은 저장하지 않았습니다")
                        bad = True
                if bad:
                    continue
                for (name, _, _), row in zip(items, rows):
                    write_action(name, [img.crop(b) for b in row], check, results)
            elif kind == "z":
                flat = [b for r in rows for b in r]
                if len(flat) != len(items):
                    problems.append(f"{fn}: 찾은 그림 {len(flat)}개 ≠ 목록 {len(items)}개 — 이 장은 저장하지 않았습니다 (다시 생성하세요)")
                    continue
                for (name, _, _), bb in zip(items, flat):
                    pan = raw.crop((bb[0] + 3, bb[1] + 3, bb[2] - 3, bb[3] - 3))  # 칸 가장자리의 회색 바탕 줄은 빼고
                    side = min(pan.width, pan.height)  # 가운데 정사각으로
                    pan = pan.crop(((pan.width - side) // 2, (pan.height - side) // 2, (pan.width - side) // 2 + side, (pan.height - side) // 2 + side))
                    pan = pan.resize((160, 160), Image.LANCZOS)
                    out_p = os.path.join(SPRITES, "..", "illustrations", "gazette", name + ".png")
                    if not check:
                        backup_once(out_p)
                        os.makedirs(os.path.dirname(out_p), exist_ok=True)
                        pan.quantize(colors=96, method=Image.Quantize.MEDIANCUT).convert("RGB").save(out_p, optimize=True)
                    results.append((name, pan.convert("RGBA")))
            elif kind == "g":
                flat = [b for r in rows for b in r]
                if len(flat) != len(items):
                    problems.append(f"{fn}: 찾은 물건 {len(flat)}개 ≠ 목록 {len(items)}개 — 이 장은 저장하지 않았습니다 (다시 생성하세요)")
                    continue
                for (name, _, _), bb in zip(items, flat):
                    if name not in GOODS:
                        problems.append(f"{fn}: 모르는 물건 이름 '{name}'")
                        continue
                    write_goods(name, img.crop(bb), check, results)
            elif kind == "b":
                flat = [b for r in rows for b in r]
                if len(items) == 1 and not grid:
                    flat = [union(flat)] if flat else []  # 한 장에 건물 하나: 떨어진 나무·소품까지 모두
                if len(flat) != len(items):
                    problems.append(f"{fn}: 찾은 건물 {len(flat)}개 ≠ 목록 {len(items)}개 — 이 장은 저장하지 않았습니다 (다시 생성하거나 txt 첫 줄에 grid=열x행)")
                    continue # 개수가 다르면 엉뚱한 이름에 덮어쓰지 않도록 이 장 전체를 건너뜀
                for (name, _, _), bb in zip(items, flat):
                    key = resolve(name, "b")
                    if not key:
                        problems.append(f"{fn}: 모르는 건물 이름 '{name}'")
                        continue
                    write_building(key, img.crop(bb), check, results)
            else:
                flat = [b for r in rows for b in r]
                if any(it[2] for it in items):  # poses=번호: 그림 전체를 읽는 순서로 1부터 센 번호
                    rows = [[flat[i - 1] for i in (it[2] or []) if 0 < i <= len(flat)] for it in items]
                elif len(items) == 1 and not grid:
                    rows = [flat]  # 한 사람: 모든 자세를 한 줄로
                if len(rows) != len(items):
                    problems.append(f"{fn}: 찾은 인물 줄 {len(rows)}개 ≠ 목록 {len(items)}명 — 이 장은 저장하지 않았습니다 (다시 생성하세요)")
                    continue
                for ri in range(len(rows)):
                    if len(rows[ri]) not in (2, 4, 8):
                        rows[ri] = split_row_bins(img, rows[ri], 4) # 4자세를 고른 간격으로
                bad_rows = [it[0] for it, row in zip(items, rows) if len(row) not in (2, 4, 8)]
                if bad_rows:
                    problems.append(f"{fn}: 자세 개수가 2·4·8이 아닌 인물 {bad_rows} — 이 장은 저장하지 않았습니다 (다시 생성하세요)")
                    continue
                for (name, hgt, _), row in zip(items, rows):
                    key = resolve(name, "n")
                    if not key:
                        problems.append(f"{fn}: 모르는 인물 이름 '{name}'")
                        continue
                    write_npc(key, [img.crop(b) for b in row], hgt, check, results)
            if ok and not check:
                done = os.path.join(INBOX, "done", kind_dir)
                os.makedirs(done, exist_ok=True)
                for p in (src, txt):
                    if os.path.exists(p):
                        shutil.move(p, os.path.join(done, os.path.basename(p)))
    make_preview(results)
    print(f"\n완료: {len(results)}개 {'(미리보기만, 저장 안 함)' if check else '저장'} → art_inbox/_preview.png")
    for p in problems:
        print("  ⚠", p)

def make_preview(results) -> None:
    if not results:
        return
    sc = 2
    cells = [(n, im.resize((im.width * sc, im.height * sc), Image.NEAREST)) for n, im in results]
    W = 1600
    x = y = 8
    row_h = 0
    pos = []
    for n, im in cells:
        if x + im.width > W:
            x, y = 8, y + row_h + 24
            row_h = 0
        pos.append((x, y))
        x += im.width + 12
        row_h = max(row_h, im.height)
    canvas = Image.new("RGBA", (W, y + row_h + 30), (86, 116, 74, 255))
    d = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("malgun.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for (n, im), (px, py) in zip(cells, pos):
        canvas.alpha_composite(im, (px, py))
        d.text((px, py + im.height + 3), n, fill=(255, 255, 230, 255), font=font)
    os.makedirs(INBOX, exist_ok=True)
    canvas.save(os.path.join(INBOX, "_preview.png"))

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if "--inbox" in sys.argv:  # 시험용: 다른 받은 그림 폴더
        INBOX = os.path.abspath(sys.argv[sys.argv.index("--inbox") + 1])
    process(check="--check" in sys.argv)
