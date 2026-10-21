# 건물·인물 그림 교체 안내

생성한 그림을 이 폴더(`art_inbox`)에 넣고 아래 명령 한 줄이면 게임용 PNG로 바뀝니다.

```
python tools/art_ingest.py --check   ← 미리보기만 (art_inbox/_preview.png 확인)
python tools/art_ingest.py           ← 실제로 교체
```

- **하나하나 따로 만들 필요 없습니다.** 한 장에 여러 개를 그려 넣고, 같은 이름의 `.txt`에 순서대로 이름만 적으면 도구가 잘라서 각 파일로 넣습니다.
- 크기 맞춤·배경 제거·바닥 정렬·색 줄이기(건물 64색, 인물 32색)는 도구가 합니다. 결과 파일은 장당 수 KB라 용량·성능 부담이 없습니다.
- 바꾸기 전 원본은 `C:\myapp\hwashung city\_backup_sprites\`에 한 번 백업됩니다(되돌리려면 거기서 복사).
- 처리가 끝난 그림은 `art_inbox/done/`으로 옮겨집니다. 교체 후 **Godot 편집기를 한 번 열어야** 새 그림이 가져와집니다.
- 이 폴더는 `.gdignore`가 있어 게임에는 포함되지 않습니다.

## 1. 그림 만들 때 지킬 것 (중요)

1. **배경은 단색**(밝은 회색이나 흰색). 체커보드도 되지만 단색이 가장 깔끔합니다.
2. **글씨·번호·격자선·제목 없이.** 글씨가 그림에 닿으면 함께 잘려 들어갑니다.
3. **그림끼리 넉넉히 띄워서**, 가로세로 줄을 맞춰 배치. 서로 닿으면 하나로 인식합니다.
4. **45도 아이소메트릭(2:1) 시점**, 바닥 마름모 위에 건물이 앉은 모양. 축만제·만석거와 같은 픽셀아트 화풍.
5. 크게 그려도 됩니다(도구가 줄입니다). 한 장에 같은 칸 크기끼리 4~8개가 적당합니다.

## 2. 건물: 한 장에 여러 개 넣는 법

```
art_inbox/buildings/초가묶음.png
art_inbox/buildings/초가묶음.txt   ← 읽는 순서(위 줄 왼→오른, 다음 줄…)대로 한 줄에 하나
```
txt 예:
```
초가 1
초가 2
thatch_house_03      # 영문 파일 이름도 됩니다
```
- 한 장에 건물 하나면 txt 없이 파일 이름을 `thatch_house_05.png`처럼 바꿀 건물 이름으로.
- 자동으로 못 나누면 txt 첫 줄에 `grid=4x2`(열x행)를 쓰면 칸을 똑같이 나눠 자릅니다.
- `…_01`을 바꾸면 같은 그림을 쓰는 기본 파일(thatch_house, tile_house, market_shop)도 함께 바뀝니다.

## 3. 인물: 한 장에 여러 명 넣는 법

한 인물은 **가로 한 줄**에 자세를 놓습니다. 방향은 *화면 기준*입니다.

| 자세 수 | 왼쪽부터 순서 |
|---|---|
| 2개 | ① 얼굴이 보이고 **화면 왼쪽 아래**를 향함 ② 등이 보이고 **화면 왼쪽 위**를 향함 → 도구가 좌우로 뒤집어 4방향을 만듭니다 |
| **4개 (권장)** | ① 앞모습 서기 ② 앞모습 걷기(한 발 내딛음) ③ 뒷모습 서기 ④ 뒷모습 걷기 — 앞모습은 화면 왼쪽 아래, 뒷모습은 왼쪽 위를 향함. 좌우 반전으로 4방향 × 걸음 2동작 |
| 8개 | 왼쪽 아래 서기·걷기, 오른쪽 아래 서기·걷기, 왼쪽 위 서기·걷기, 오른쪽 위 서기·걷기 |

걸음 2동작이 없으면 1픽셀 들썩이는 걸음으로 자동 처리합니다. 발밑 그림자와 얇은 외곽선도 도구가 넣습니다.

```
art_inbox/npcs/백성1.png      ← 줄마다 한 사람
art_inbox/npcs/백성1.txt
```
txt 예:
```
농부
아낙
사내아이 height=28      # 키(픽셀)를 바꾸고 싶을 때
```
- 이미 만든 시트가 다른 배치(예: 2줄 8칸에 FRONT/BACK/LEFT/RIGHT…)라면, 그림 전체를 읽는 순서로 1부터 센 번호를 골라 쓸 수 있습니다: `보부상 poses=5,6,7,8`
- 미리보기에서 방향이 반대로 보이면 번호 순서를 바꾸면 됩니다(예: `poses=6,5,8,7`).

## 4. 생성 프롬프트 예시 (Gemini 등에 그대로 붙여넣기)

공통 화풍 문장:
```
Detailed isometric pixel art game asset, 2:1 isometric (45-degree diagonal) view, Joseon-dynasty Korea late 18th century,
same style as a polished SNES/GBA city-builder, crisp pixels, soft top-left lighting, each object sits on its own
diamond-shaped ground base, plain flat light gray background, objects arranged in a neat grid with wide empty gaps,
no text, no labels, no numbers, no grid lines, no frame.
```
건물 예:
```
[공통 화풍 문장] Draw 6 separate small buildings in a 3x2 grid: 1) thatched-roof farmhouse with a low stone fence,
2) thatched farmhouse with a vegetable patch, 3) thatched house with drying racks, 4) thatched house with soy-sauce jars,
5) small giwa (black tile roof) house, 6) giwa house with a stone path.
```
인물 예:
```
Pixel art character sprites, Joseon-dynasty Korea, chibi proportions (head about 1/4 of body), clean dark outline,
plain flat light gray background, no text. 4 characters, one per row. In each row draw exactly 2 poses side by side
with wide gaps: left = 3/4 front view facing toward the lower-left of the screen, right = 3/4 back view facing toward the
upper-left of the screen. Row 1: farmer with straw hat and hoe. Row 2: village woman with white head cloth and basket.
Row 3: little boy with braided hair. Row 4: peddler (bobusang) with a wooden back-pack frame and walking stick.
```

## 5. 건물 목록 (총 69종)

캔버스 크기는 도구가 맞춥니다. 칸 크기는 같은 장에 묶을 때 참고하세요.

| 칸 | 캔버스 | 영문 이름 | 한글 이름 |
|---|---|---|---|
| 7x7 | 448×320 | `chukmanje` | 축만제(서호) — 완성본 |
| 7x7 | 448×320 | `haenggung` | 화성행궁 |
| 7x7 | 448×320 | `manseokgeo` | 만석거 — 완성본 |
| 3x3 | 192×160 | `maegok_seowon` | 매곡서원(향교) |
| 3x3 | 192×160 | `tile_house_10_3x3` | 대갓집 기와집(진휼소 등) |
| 3x3 | 192×160 | `ws_3x3_royal_arsenal` | 군기시(왕실 무기고) |
| 3x2 | 160×136 | `tile_house_10_3x2` | 큰 기와집 ㄱ자 |
| 2x2 | 128×112 | `children_play_yard` | 아이들 놀이마당(제기·팽이) |
| 2x2 | 128×112 | `seodang` | 서당 |
| 2x2 | 128×112 | `seojangdae` | 서장대(지휘 누각) |
| 2x2 | 128×112 | `tile_house_08` | 기와집 마당 넓은 집 1 |
| 2x2 | 128×112 | `tile_house_09` | 기와집 마당 넓은 집 2 |
| 2x2 | 128×112 | `women_play_yard` | 여인들 놀이마당(널뛰기·그네) |
| 2x2 | 128×112 | `ws_2x2_ceramics` | 도자기 가마 공방 |
| 2x2 | 128×112 | `ws_2x2_lumber_machinery` | 제재·목재 기계 공방 |
| 2x2 | 128×112 | `yeonmudae` | 연무대(활터 누각) |
| 2x2 | 128×112 | `yusubu` | 유수부·순라청 관아 |
| 2x1 | 96×88 | `thatch_house_08` | 초가 ㄱ자 1 |
| 2x1 | 96×88 | `thatch_house_09` | 초가 ㄱ자 2 |
| 2x1 | 96×88 | `thatch_house_10` | 초가 ㄱ자 3 |
| 2x1 | 96×88 | `tile_house_05` | 기와집 2칸 1 |
| 2x1 | 96×88 | `tile_house_06` | 기와집 2칸 2 |
| 2x1 | 96×88 | `tile_house_07` | 기와집 2칸 3 |
| 2x1 | 96×88 | `ws_2x1_blacksmith` | 대장간 |
| 2x1 | 96×88 | `ws_2x1_dyeing` | 염색 공방 |
| 2x1 | 96×88 | `ws_2x1_shoemaker` | 갖바치(신발) 공방 |
| 2x1 | 96×88 | `ws_2x1_stonemason` | 석공방 |
| 2x1 | 96×88 | `ws_2x1_tile_kiln` | 기와 가마 |
| 1x1 | 64×72 | `market_shop` | 장터 가게 기본 |
| 1x1 | 64×72 | `market_shop_01` | 장터 선전(비단) |
| 1x1 | 64×72 | `market_shop_02` | 장터 도자기전 |
| 1x1 | 64×72 | `market_shop_03` | 장터 약방 |
| 1x1 | 64×72 | `market_shop_04` | 장터 서책방 |
| 1x1 | 64×72 | `market_shop_05` | 장터 갓방 |
| 1x1 | 64×72 | `market_shop_06` | 장터 은·옥 공예방 |
| 1x1 | 64×72 | `market_shop_07` | 장터 유기전 |
| 1x1 | 64×72 | `market_shop_08` | 장터 악기전 |
| 1x1 | 64×72 | `market_shop_09` | 장터 팔달문 우시장 |
| 1x1 | 64×72 | `market_shop_10` | 장터 어물전 |
| 1x1 | 64×72 | `market_shop_11` | 장터 객주 |
| 1x1 | 64×72 | `market_shop_12` | 장터 싸전 |
| 1x1 | 64×72 | `market_shop_13` | 장터 육전 |
| 1x1 | 64×72 | `market_shop_14` | 장터 옹기전 |
| 1x1 | 64×72 | `market_shop_15` | 장터 주막 |
| 1x1 | 64×72 | `market_shop_16` | 장터 과일전 |
| 1x1 | 64×72 | `market_shop_17` | 장터 떡전 |
| 1x1 | 64×72 | `market_shop_18` | 장터 신방(신발) |
| 1x1 | 64×72 | `market_shop_19` | 장터 소금·양념전 |
| 1x1 | 64×72 | `market_shop_20` | 장터 연초전 |
| 1x1 | 64×72 | `thatch_house` | 초가 기본 |
| 1x1 | 64×72 | `thatch_house_01` | 초가 1 |
| 1x1 | 64×72 | `thatch_house_02` | 초가 2 |
| 1x1 | 64×72 | `thatch_house_03` | 초가 3 |
| 1x1 | 64×72 | `thatch_house_04` | 초가 4 |
| 1x1 | 64×72 | `thatch_house_05` | 초가 5 |
| 1x1 | 64×72 | `thatch_house_06` | 초가 6 |
| 1x1 | 64×72 | `thatch_house_07` | 초가 7 |
| 1x1 | 64×72 | `tile_house` | 기와집 기본 |
| 1x1 | 64×72 | `tile_house_01` | 기와집 1 |
| 1x1 | 64×72 | `tile_house_02` | 기와집 2 |
| 1x1 | 64×72 | `tile_house_03` | 기와집 3 |
| 1x1 | 64×72 | `tile_house_04` | 기와집 4 |
| 1x1 | 64×72 | `well` | 우물 |
| 1x1 | 64×72 | `workshop` | 공방 기본 |
| 1x1 | 64×72 | `ws_1x1_bamboo` | 죽세공방 |
| 1x1 | 64×72 | `ws_1x1_carpenter` | 목수 공방 |
| 1x1 | 64×72 | `ws_1x1_hanji` | 한지 공방 |
| 1x1 | 64×72 | `ws_1x1_leather` | 가죽 공방 |
| 1x1 | 64×72 | `ws_1x1_metalcraft` | 금속 공예방 |

## 6. 인물 목록

시트 규격(도구가 맞춤): 48×48 칸 × 2열(걸음) × 4행(방향) = 96×192, 정면 1칸 `_front` 48×48. 게임에서는 0.7~0.84배로 축소되어 보입니다.

### 역사 인물 (26명)
| 한글 이름 | 영문 이름 | 모습 |
|---|---|---|
| 정조 | `jeongjo` | 국왕, 붉은 곤룡포·익선관 |
| 채제공 | `chae_jegong` | 영의정, 흰 수염 노재상 |
| 정약용 | `jeong_yakyong` | 실학자, 관복 |
| 조심태 | `jo_simtae` | 화성유수, 무관 관복 |
| 박제가 | `park_jega` | 북학파 실학자 |
| 이덕무 | `yi_deokmu` | 규장각 검서관 |
| 유득공 | `yu_deukgong` | 역사학자 |
| 서유구 | `seo_yugu` | 농학자 |
| 박지원 | `park_jiwon` | 북학파 대가 |
| 홍대용 | `hong_daeyong` | 천문학자 |
| 이가환 | `yi_gahwan` | 공조판서 |
| 정범조 | `jeong_beomjo` | 대제학 |
| 김홍도 | `kim_hongdo` | 도화서 화원, 화구 |
| 김정희 | `kim_jeonghee` | 추사, 서예가 |
| 유한지 | `yu_hanji` | 예서 명필 |
| 심환지 | `sim_hwanji` | 벽파 영수 |
| 홍인한 | `hwang_inhan` | 권신 외척 |
| 김조순 | `kim_josun` | 시파 중신 |
| 이기경 | `yi_gigyeong` | 보수 유생 |
| 홍국영 | `hong_gukyeong` | 세도 권신 |
| 백동수 | `baek_dongsu` | 무예 총관, 장검 |
| 구선복 | `gu_seon_bok` | 훈련대장, 갑주 |
| 김바우 | `kim_bau` | 수석 석공, 망치 |
| 이성길 | `yi_seonggil` | 도편수(목수 우두머리) |
| 무쇠 | `musoe` | 군수 가죽공 |
| 김판관 | `kim_pangwan` | 수원부 판관(안내역) |

### 백성·군사·행렬 (25종)
| 한글 이름 | 영문 이름 | 모습 | 키(px) |
|---|---|---|---|
| 양반 선비 | `npc_yangban_scholar` | 갓·도포·부채 | 40 |
| 양반 부인 | `npc_yangban_lady` | 가체·장옷 | 38 |
| 한량 | `npc_hallyang` | 갓·화려한 도포 | 40 |
| 기생 | `npc_gisaeng` | 가체·화사한 치마저고리 | 38 |
| 농부 | `npc_farmer` | 삿갓·흰 바지저고리·괭이 | 39 |
| 아낙 | `npc_peasant_woman` | 흰 수건·치마·바구니 | 37 |
| 보부상 | `npc_bobusang` | 패랭이·지게 봇짐·지팡이 | 40 |
| 대장장이 | `npc_artisan_blacksmith` | 앞치마·망치 | 39 |
| 천민 | `npc_cheonmin` | 헤진 옷·맨상투 | 38 |
| 사내아이 | `npc_child_boy` | 댕기머리 아이 | 30 |
| 계집아이 | `npc_child_girl` | 댕기머리·색동 | 30 |
| 순라군 | `npc_patrol` | 전립·창 | 40 |
| 장용영 군사 | `npc_soldier` | 전립·두정갑·조총/창 | 40 |
| 도적 | `npc_thief` | 복면·몽둥이 | 39 |
| 왈짜(싸움꾼) | `npc_brawler` | 웃통 걸친 거친 사내 | 40 |
| 전기수(이야기꾼) | `npc_jeongisu` | 갓·책 | 40 |
| 어부 | `npc_fisherman` | 삿갓·그물·어망 | 39 |
| 연날리는 아이 | `npc_kite_flyer` | 연과 얼레 | 32 |
| 씨름꾼 | `npc_ssireum` | 샅바 맨 장사 | 40 |
| 택견꾼 | `npc_taekkyeon` | 바지저고리·띠 | 40 |
| 어가행렬 정조 | `parade_king` | 융복 차림 기마 국왕 | 44 |
| 어가(가마) | `parade_royal_carriage` | 왕의 가마와 가마꾼 | 44 |
| 행렬 기마병 | `parade_cavalry` | 말 탄 무관 | 44 |
| 취타대 | `parade_musician` | 나팔·북 악사 | 40 |
| 기수 | `parade_flag_bearer` | 큰 깃발 든 군사 | 44 |

※ `*_sheet.png`(64×288) 형식의 옛 형식 파일들은 지금 게임 화면에서 쓰이지 않아 목록에서 뺐습니다(성능 시험 도구만 사용).
