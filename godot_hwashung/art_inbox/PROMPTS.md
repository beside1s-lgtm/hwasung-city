# Gemini 그림 생성 프롬프트 (수정 없이 그대로 사용)

건물 14장(65종) + 인물 27장(51명). **각 프롬프트를 그대로 붙여 넣고, 나온 그림을 제목의 파일 이름으로 저장**하면 끝입니다.
이름 목록(`.txt`)은 이미 만들어 두었으니 따로 쓸 필요가 없습니다.

## 쓰는 순서
1. 아래 프롬프트 하나를 복사해 Gemini에 붙여 넣는다.
2. 나온 그림을 저장한다 — 건물은 `art_inbox/buildings/B01.png`, 인물은 `art_inbox/npcs/N01.png`처럼 **제목의 이름 그대로**(.jpg·.webp도 됨).
3. 몇 장 모이면 미리보기 → 괜찮으면 교체:
   ```
   python tools/art_ingest.py --check
   python tools/art_ingest.py
   ```
4. Godot 편집기를 한 번 열어 새 그림을 가져온다.

## 잘 나오게 하는 요령
- **한 장마다 새 대화창**에서 만드세요. 같은 대화창에서 계속 만들면 앞 그림의 인물·배치가 섞여 들어갑니다.
- **화풍 맞추기**: 건물은 `assets/sprites/buildings/chukmanje.png`, 인물은 잘 나온 인물 그림 한 장을 첨부하고 "Match the art style of the attached image only; do not copy its characters."를 프롬프트 앞에 붙이세요. (첨부 없이도 동작합니다.)
- 그림 개수가 모자라거나 서로 붙어 나오면 그 장만 다시 생성하세요. 미리보기에서 "찾은 건물 N개 ≠ 목록 M개"가 뜨면 개수가 안 맞는 것입니다.
- 인물은 한 장에 2명(위 줄·아래 줄), 한 사람당 4자세(앞 서기·앞 걷기·뒤 서기·뒤 걷기)입니다. 줄이나 자세 개수가 안 맞으면 도구가 그 장을 건너뛰니 다시 생성하세요.
- 걷는 자세가 반대쪽을 보거나 앞모습이 오른쪽을 보면 가공 도구가 자동으로 뒤집어 맞춥니다(미리보기로 확인).
- 걷는 그림에서 소품이 사라지는 등 서기와 너무 다르면, 그 인물 이름 뒤에 ` walk=bob`을 붙이세요(예: `yu_hanji walk=bob`). 걷는 그림 대신 서 있는 그림이 살짝 들썩이며 걷습니다.
- 교체가 끝난 장의 그림과 txt는 `art_inbox/done/`으로 옮겨집니다. 다시 하고 싶으면 txt를 제자리로 옮기고 새 그림을 넣으세요.

---

# 건물

## B01 — 초가 1칸 6종
저장: `art_inbox/buildings/B01.png` · 들어가는 것: `thatch_house_01`, `thatch_house_02`, `thatch_house_03`, `thatch_house_04`, `thatch_house_05`, `thatch_house_06`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each is a small single-story house on a 1x1 diamond plate; the whole object (plate + roof) should be about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) small thatched-roof cottage with a low stone fence and a twig gate. 2) thatched cottage with a small vegetable garden plot in front. 3) thatched cottage with a wooden rack of drying red peppers and a straw mat. 4) thatched cottage with a jangdokdae platform of brown onggi soy-sauce jars. 5) thatched cottage with a firewood pile and an axe on a chopping block. 6) thatched cottage with a brushwood fence and a small chicken coop.
```

## B02 — 초가 1 + 기와집 4 + 우물
저장: `art_inbox/buildings/B02.png` · 들어가는 것: `thatch_house_07`, `tile_house_01`, `tile_house_02`, `tile_house_03`, `tile_house_04`, `well`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each sits on a 1x1 diamond plate; the whole object (plate + building) should be about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) thatched cottage with an orange persimmon tree beside it. 2) small giwa (black tile roof) house with white plaster walls and a stepping-stone path. 3) small giwa house with stacked brown onggi jars beside it. 4) small giwa house with a low stone wall and a little wooden gate. 5) small giwa house with a pine tree in the front yard. 6) village stone well: round granite rim, a wooden pulley frame with a tiny tile roof and a wooden bucket, on a small stone-paved diamond plate; a low object, no house.
```

## B03 — 장터 가게 1~6
저장: `art_inbox/buildings/B03.png` · 들어가는 것: `market_shop_01`, `market_shop_02`, `market_shop_03`, `market_shop_04`, `market_shop_05`, `market_shop_06`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each is a small market shop on a 1x1 diamond plate: a compact tile-roofed stall at the back and an open cloth awning over a wooden display counter at the front, so the goods are clearly visible. Each object about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) silk shop: rolls of red, blue, yellow and green silk on the counter and silk hanging from the awning. 2) porcelain shop: white moon jars and blue-and-white vases and tea cups. 3) herbal medicine shop: a wall of small wooden drawers and bundles of dried herbs hanging. 4) bookshop: stacks of thread-bound Korean books and rolled scrolls. 5) gat hat shop: black horsehair gat hats displayed on stands. 6) silver and jade craft shop: hairpins, norigae ornaments and jade pieces.
```

## B04 — 장터 가게 7~12
저장: `art_inbox/buildings/B04.png` · 들어가는 것: `market_shop_07`, `market_shop_08`, `market_shop_09`, `market_shop_10`, `market_shop_11`, `market_shop_12`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each is a small market shop on a 1x1 diamond plate: a compact tile-roofed stall at the back and an open cloth awning over a wooden display counter at the front, so the goods are clearly visible. Each object about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) brassware shop (yugijeon): shining golden brass bowls, basins and spoons. 2) musical instrument shop: a gayageum zither, janggu drums and bamboo flutes. 3) small 1-tile cattle trading stall (not a big market): a tiny wooden pen with one brown Korean ox, a feed trough and a hay pile. 4) fish shop: strings of dried yellow croaker and baskets of fish. 5) gaekju merchant inn: stacked straw-wrapped goods bundles and a horse hitching post. 6) rice shop: straw rice sacks and wooden rice measuring boxes.
```

## B05 — 장터 가게 13~18
저장: `art_inbox/buildings/B05.png` · 들어가는 것: `market_shop_13`, `market_shop_14`, `market_shop_15`, `market_shop_16`, `market_shop_17`, `market_shop_18`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each is a small market shop on a 1x1 diamond plate: a compact tile-roofed stall at the back and an open cloth awning over a wooden display counter at the front, so the goods are clearly visible. Each object about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) butcher shop: hanging meat and a wooden chopping block. 2) onggi pottery shop: piles of large brown earthenware jars. 3) jumak tavern: a low wooden bench (pyeongsang), makgeolli jars and a paper lantern. 4) fruit shop: baskets of persimmons, pears and red jujubes. 5) rice cake shop: trays of colorful tteok and a steaming wooden steamer. 6) shoe shop: straw sandals and leather shoes on shelves.
```

## B06 — 장터 가게 19~20 + 작은 공방 4종
저장: `art_inbox/buildings/B06.png` · 들어가는 것: `market_shop_19`, `market_shop_20`, `ws_1x1_carpenter`, `ws_1x1_bamboo`, `ws_1x1_hanji`, `ws_1x1_leather`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). All on 1x1 diamond plates; each object about as tall as it is wide. The first two are market shops (tile-roofed stall + awning + goods), the last four are small craft workshops.

Objects in reading order (left to right, top to bottom): 1) salt and spice shop: salt sacks and jars of red pepper powder and sesame. 2) tobacco shop: drying tobacco leaves and long bamboo pipes. 3) small carpenter workshop: open-front shed with a sawhorse, planks and wood shavings. 4) bamboo craft workshop: bamboo poles leaning on the wall and woven baskets. 5) hanji paper workshop: sheets of paper drying on wooden boards and a soaking vat. 6) leather workshop: animal hides stretched on wooden frames.
```

## B07 — 2칸 집 6종 (초가 3 + 기와 3)
저장: `art_inbox/buildings/B07.png` · 들어가는 것: `thatch_house_08`, `thatch_house_09`, `thatch_house_10`, `tile_house_05`, `tile_house_06`, `tile_house_07`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each house sits on a larger diamond plate covering two tiles (2x1 footprint). The whole object should be a bit wider than it is tall.

Objects in reading order (left to right, top to bottom): 1) L-shaped thatched farmhouse with a dirt courtyard and a straw stack. 2) long thatched farmhouse with an attached cattle shed and an ox. 3) thatched farmhouse with grain drying on mats in the yard and a stone millstone. 4) two-wing giwa house around a small courtyard. 5) giwa house with a wide wooden veranda (daecheong maru) and onggi jars. 6) giwa house with a low stone wall and a small tile-roofed front gate.
```

## B08 — 공방 6종 (작은 공방 1 + 2칸 공방 5)
저장: `art_inbox/buildings/B08.png` · 들어가는 것: `ws_1x1_metalcraft`, `ws_2x1_blacksmith`, `ws_2x1_dyeing`, `ws_2x1_shoemaker`, `ws_2x1_stonemason`, `ws_2x1_tile_kiln`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). The first object is a small workshop on a 1x1 diamond plate (about as tall as it is wide); the other five sit on diamond plates covering two tiles (2x1 footprint, a bit wider than tall).

Objects in reading order (left to right, top to bottom): 1) small metalcraft workshop: a tiny charcoal forge, an anvil and brass tools. 2) blacksmith forge: open shed with a glowing forge, anvil, leather bellows and a little smoke. 3) dyeing workshop: indigo dye vats and long blue, red and yellow cloths hanging on poles. 4) gatbachi shoemaker workshop: leather shoes on racks and a work bench. 5) stonemason yard: cut granite blocks, chisels and a half-carved stone. 6) roof-tile kiln: a dome-shaped earthen kiln with smoke and stacks of gray giwa tiles.
```

## B09 — 서당 + 지도용 관청 3종 (2x2)
저장: `art_inbox/buildings/B09.png` · 들어가는 것: `seodang`, `lm_gwana`, `lm_jongnu`, `lm_jinhulso`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Each sits on a large diamond plate covering 2x2 tiles. The whole object should be wider than it is tall (about 8:7). Screen directions on the diamond plate: the TOP corner is the back, the BOTTOM corner is the front; the lower-right edge and the lower-left edge are the two front sides. Draw NO people.

Objects in reading order (left to right, top to bottom): 1) village seodang school: a giwa-roofed hall with an open wooden floor, a low wall and a big zelkova tree. 2) walled county office (gwana) compound: the main hall (dongheon) with an open wooden front hall stands in the TOP corner and faces the lower-left; a small round stone-walled prison with a thatched cell in the RIGHT corner; an empty packed-earth courtyard with a long wooden punishment bench in the LEFT corner; a tall three-door gate (sosul-sammun) with a pagoda tree in the BOTTOM corner, set in the lower-left wall; low plastered walls with tile caps all around. 3) Yeomingak bell pavilion: an elegant two-story pavilion with red pillars and dancheong eaves on a granite platform, a large bronze bell hanging inside, standing in the front half of a stone-paved square. 4) government relief office (jinhulso) compound: a tile-roofed main office in the back, a raised rice granary on one side, three big iron cooking cauldrons under an open thatched shelter on the other side, and an empty paved space in front for the food line.
```

## B10 — 큰 집·공방 4종 (2x2)
저장: `art_inbox/buildings/B10.png` · 들어가는 것: `tile_house_08`, `tile_house_09`, `ws_2x2_ceramics`, `ws_2x2_lumber_machinery`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Each sits on a large diamond plate covering 2x2 tiles. The whole object should be wider than it is tall (about 8:7).

Objects in reading order (left to right, top to bottom): 1) wealthy giwa house compound: L-shaped tiled house, garden with a small pond and pine trees, stone wall and gate. 2) giwa house compound with a jangdokdae yard full of onggi jars, a stone wall and a gate. 3) pottery workshop with a long climbing kiln on a slope, a potter wheel shed and pots drying. 4) lumber yard with log piles, a sawing pit and a large wooden treadwheel crane.
```

## B11 — 대형 건물 4종 (3x2·3x3)
저장: `art_inbox/buildings/B11.png` · 들어가는 것: `tile_house_10_3x2`, `tile_house_10_3x3`, `maegok_seowon`, `ws_3x3_royal_arsenal`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). These are big compounds on large diamond plates (3x2 or 3x3 tiles). Each whole object should be clearly wider than it is tall (about 6:5).

Objects in reading order (left to right, top to bottom): 1) large L-shaped yangban mansion with a men quarters and a women quarters, a courtyard, trees, a stone wall and a gate (3x2 tiles). 2) grand compound of a rich Jeongjo-era family: several tiled halls around courtyards, a garden with pine trees and rocks, stone walls and a main gate (3x3 tiles). 3) Confucian academy (seowon): a central lecture hall, two dormitory wings facing each other, a shrine at the back, a big ginkgo tree, enclosed by a wall with a gate (3x3 tiles). 4) royal arsenal: a walled compound with long storage halls, rows of bronze cannons, racks of spears and matchlock muskets, and banners (3x3 tiles).
```

## B12 — [지도] 화성행궁 7x7 (한 장에 하나)
저장: `art_inbox/buildings/B12.png` · 들어가는 것: `lm_haenggung`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw only this one object, centered, filling most of the image. A very large palace complex on one huge diamond plate covering 7x7 tiles. The whole object should be much wider than it is tall (about 7:5). Wide landscape image. Draw NO people.

Object: Hwaseong Haenggung detached palace. Its central axis runs straight from the middle of the UPPER-LEFT edge (back) to the middle of the LOWER-RIGHT edge (front). The main gate Sinpungnu, a two-story gate tower with a tile roof, stands in the middle of the lower-right outer wall. Inside, along the axis from front to back: a stone-paved forecourt with trees, the inner gate Jwaikmun with roofed corridors on both sides, an open stone-paved courtyard, then the main hall Bongsudang with red pillars, then Nangnamheon hall and a small rear garden near the back wall. Rows of side halls and barracks line both long sides. A long tile-capped wall encloses everything.
```

## B13 — 수원 쇠전(우시장) 바탕 3x3 (한 장에 하나)
저장: `art_inbox/buildings/B13.png` · 들어가는 것: `cattle_market_3x3`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw only this one object, centered, filling most of the image. A large open livestock yard on one big diamond plate covering 3x3 tiles, seen from the same 2:1 isometric angle. The whole object should be clearly wider than it is tall (about 6:5). IMPORTANT: draw NO animals and NO people at all - the yard must be empty, because the game animates the cattle and merchants on top.

Object: Suwon cattle market (soejeon) yard of the 1790s: a wide trampled packed-earth ground with scattered straw and hoof marks, a low wooden post-and-rail fence around the whole edge with an open entrance on the front-left side, two long wooden tethering rails crossing the middle of the yard (running from the top-left area toward the lower-right) where cattle would be tied, a wooden feed trough with a golden haystack at the top corner, a small thatched-roof tavern awning with a low wooden bench (pyeongsang) and makgeolli jars at the right corner, a small cloth flag on a pole near the top edge, and a few wooden water buckets; the middle of the yard stays mostly open.
```

## B14 — [지도] 수원향교 4x4 (한 장에 하나)
저장: `art_inbox/buildings/B14.png` · 들어가는 것: `lm_hyanggyo`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw only this one object, centered, filling most of the image. A Confucian school compound on one diamond plate covering 4x4 tiles. The whole object should be clearly wider than it is tall (about 5:4). Draw NO people.

Object: Suwon Hyanggyo Confucian school. Its axis runs straight from the middle of the UPPER-RIGHT edge (back) to the middle of the LOWER-LEFT edge (front). In the back: the Daeseongjeon shrine hall on a raised stone terrace with two small side shrines. In the front half: an open courtyard and the Myeongnyundang lecture hall with an open wooden floor, two long dormitory wings facing each other, an old ginkgo tree, and the outer gate in the middle of the lower-left wall. Tile-capped walls around.
```


## B15 — 순라청 · 멸화군 수성소 · 소금 창고 (물건 3개)
저장: `art_inbox/buildings/B15.png` · 들어가는 것: `patrol_station`, `firefighter_station`, `salt_store_2x2`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon Hwaseong, Joseon-dynasty Korea, 1790s. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Authentic Korean architecture: charcoal-blue giwa roof tiles with visible tile rows and gently upturned eaves, golden straw thatch roofs with rope lines, wooden posts and beams, white plaster walls, hanji lattice doors and windows, granite foundations. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Exactly 3 objects in one row, left to right:
1) Patrol station (Sullacheong) on a 1x1 tile diamond plate: a small tile-roofed guard post with red pillars, a wooden notice board, a rack of spears and a lantern hanging at the eave, a red-and-black flag on a pole. Draw NO people.
2) Fire brigade post (Myeolhwagun) on a 1x1 tile diamond plate: a small tile-roofed shed with an open front, rows of wooden water buckets, long iron fire hooks and a big earthenware water jar beside it, a small watch-bell frame. Draw NO people.
3) Salt warehouse on a 2x2 tile diamond plate (about twice as wide as the others): a long red-tiled storehouse with an open front full of stacked straw salt sacks, a big white heap of coarse sea salt in the yard partly covered by a straw mat, a wooden scale and a low fence. Draw NO people.
```

---

# 인물

## N01 — 정조 · 채제공
저장: `art_inbox/npcs/N01.png` · 들어가는 것: `jeongjo`, `chae_jegong`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: King Jeongjo: young adult man, no beard, red royal robe (gonryongpo) with round golden dragon badges on the chest and shoulders, black ikseongwan crown hat with two small upright wings at the back, jade belt, holding a sheathed royal sword.

Bottom row — second character: Chae Je-gong, elderly chief state councillor: long thick white beard, red official robe with an embroidered rank badge on the chest, black samo hat with side wings, holding an ivory hol tablet.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N02 — 정약용 · 조심태
저장: `art_inbox/npcs/N02.png` · 들어가는 것: `jeong_yakyong`, `jo_simtae`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Jeong Yak-yong, scholar and fortress designer in his thirties: thin mustache, teal dopo robe, black wide-brimmed gat hat, holding a rolled construction blueprint.

Bottom row — second character: Jo Sim-tae, military governor of Hwaseong: short black beard, navy military coat with a sash, red felt jeollip military hat with a tassel, holding a commander baton.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N03 — 박제가 · 이덕무
저장: `art_inbox/npcs/N03.png` · 들어가는 것: `park_jega`, `yi_deokmu`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Park Je-ga, northern-learning scholar: thin mustache, navy dopo robe, black gat hat, carrying a bundle of books on his back.

Bottom row — second character: Yi Deok-mu, royal library clerk: slim young man, no beard, white dopo robe, black soft cloth cap (yugeon), holding a stack of books.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N04 — 유득공 · 서유구
저장: `art_inbox/npcs/N04.png` · 들어가는 것: `yu_deukgong`, `seo_yugu`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Yu Deuk-gong, historian: thin mustache, sage-green dopo robe, black gat hat, holding an unrolled old map.

Bottom row — second character: Seo Yu-gu, agricultural scholar: medium black beard, amber-yellow robe, black layered horsehair jeongjagwan cap, holding a sheaf of golden rice.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N05 — 박지원 · 홍대용
저장: `art_inbox/npcs/N05.png` · 들어가는 것: `park_jiwon`, `hong_daeyong`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Park Ji-won, sturdy middle-aged writer: full black beard, brown dopo robe, black gat hat, holding a long bamboo smoking pipe.

Bottom row — second character: Hong Dae-yong, astronomer: thin mustache, indigo robe, black jeongjagwan cap, holding a small brass armillary sphere.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N06 — 이가환 · 정범조
저장: `art_inbox/npcs/N06.png` · 들어가는 것: `yi_gahwan`, `jeong_beomjo`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Yi Ga-hwan, minister of works: elderly, medium gray beard, red official robe with a rank badge, black samo hat, holding a wooden measuring ruler.

Bottom row — second character: Jeong Beom-jo, chief royal scholar: elderly, thick white beard, blue official robe with a rank badge, black samo hat, holding a scroll.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N07 — 김홍도 · 김정희
저장: `art_inbox/npcs/N07.png` · 들어가는 것: `kim_hongdo`, `kim_jeonghee`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Kim Hong-do, court painter: thin mustache, cream-colored robe, black gat hat, holding a painting brush and a sheet of paper.

Bottom row — second character: Kim Jeong-hui, young calligrapher: no beard, pure white robe, black jeongjagwan cap, holding a very large calligraphy brush.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N08 — 유한지 · 심환지
저장: `art_inbox/npcs/N08.png` · 들어가는 것: `yu_hanji`, `sim_hwanji`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Yu Han-ji, master calligrapher: elderly, thick white beard, purple dopo robe, black gat hat, holding a scroll of calligraphy.

Bottom row — second character: Sim Hwan-ji, stern elderly faction leader: long black beard, dark charcoal official robe with a rank badge, black samo hat, holding a sealed letter.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N09 — 홍인한 · 김조순
저장: `art_inbox/npcs/N09.png` · 들어가는 것: `hwang_inhan`, `kim_josun`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Hong In-han, haughty royal in-law minister: medium black beard, navy official robe with a rank badge, black samo hat, holding a scroll.

Bottom row — second character: Kim Jo-sun, elegant court minister: no beard, teal official robe with a rank badge, black samo hat, holding a jade ornament.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N10 — 이기경 · 홍국영
저장: `art_inbox/npcs/N10.png` · 들어가는 것: `yi_gigyeong`, `hong_gukyeong`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Yi Gi-gyeong, conservative scholar-official: thin mustache, dark gray official robe without badge, black samo hat, holding a scroll.

Bottom row — second character: Hong Guk-yeong, ambitious young power broker: thin mustache, rich violet robe, black gat hat with a bead chin strap, holding a small seal box.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N11 — 백동수 · 구선복
저장: `art_inbox/npcs/N11.png` · 들어가는 것: `baek_dongsu`, `gu_seon_bok`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Baek Dong-su, martial arts master: short black beard, blue padded military robe with armor plates, red felt jeollip hat, holding a sword.

Bottom row — second character: Gu Seon-bok, training commander general: full black beard, iron studded lamellar armor (dujeonggap), iron helmet with a red plume, holding a long glaive (woldo).

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N12 — 김바우 · 이성길
저장: `art_inbox/npcs/N12.png` · 들어가는 것: `kim_bau`, `yi_seonggil`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Kim Ba-u, master stonemason: stubble, earth-brown work clothes with rolled sleeves, straw headband, holding a big stone hammer.

Bottom row — second character: Yi Seong-gil, master carpenter (dopyeonsu): short beard, blue work clothes, straw paerangi hat, holding a saw.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## N13 — 무쇠 · 김판관
저장: `art_inbox/npcs/N13.png` · 들어가는 것: `musoe`, `kim_pangwan`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Mu-soe, military leatherworker: burly man, dark leather apron and clothes, black headband, holding a leather-cutting knife.

Bottom row — second character: Kim Pan-gwan, friendly middle-aged magistrate officer: neat short beard, azure-blue official robe with a rank badge, black samo hat, holding a ledger book.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G01 — 양반 선비 · 양반 부인
저장: `art_inbox/npcs/G01.png` · 들어가는 것: `npc_yangban_scholar`, `npc_yangban_lady`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: yangban gentleman: thin mustache, teal dopo robe, black gat hat, holding a folding fan.

Bottom row — second character: noblewoman: elaborate braided gache hairstyle, pastel pink jeogori jacket and a long full light-blue chima skirt.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G02 — 한량 · 기생
저장: `art_inbox/npcs/G02.png` · 들어가는 것: `npc_hallyang`, `npc_gisaeng`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: dandy idler (hallyang): swaggering young man, purple dopo robe, black gat hat with a bead strap, holding a fan.

Bottom row — second character: gisaeng entertainer: large gache hairstyle with ornaments, vivid green jeogori and a red chima skirt.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G03 — 농부 · 아낙
저장: `art_inbox/npcs/G03.png` · 들어가는 것: `npc_farmer`, `npc_peasant_woman`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: farmer: stubble, straw satgat hat, rough white hemp jacket and trousers rolled up, straw sandals, a hoe on his shoulder.

Bottom row — second character: village woman: white head cloth, beige hemp jeogori, brown chima skirt, carrying a basket.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G04 — 보부상 · 대장장이
저장: `art_inbox/npcs/G04.png` · 들어가는 것: `npc_bobusang`, `npc_artisan_blacksmith`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: peddler (bobusang): short beard, straw paerangi hat with white cotton tufts, blue clothes, a wooden jige back frame loaded with goods, a walking stick.

Bottom row — second character: blacksmith: stubble, straw headband, earth-brown clothes with a leather apron, holding a hammer.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G05 — 천민 · 사내아이
저장: `art_inbox/npcs/G05.png` · 들어가는 것: `npc_cheonmin`, `npc_child_boy`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: lowborn laborer (cheonmin): bare topknot, patched worn hemp clothes, straw sandals.

Bottom row — second character: little boy (child, smaller than adults): long single braid (daenggi), teal jacket and white trousers.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G06 — 계집아이 · 연날리는 아이
저장: `art_inbox/npcs/G06.png` · 들어가는 것: `npc_child_girl`, `npc_kite_flyer`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: little girl (child, smaller than adults): braided hair with a red ribbon, rainbow-striped saekdong jacket and a red skirt.

Bottom row — second character: boy flying a kite (child, smaller than adults): yellow headband, holding a wooden kite reel with a rectangular bangpae kite.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G07 — 순라군 · 장용영 군사
저장: `art_inbox/npcs/G07.png` · 들어가는 것: `npc_patrol`, `npc_soldier`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: night patrol guard (sunra): thin mustache, black jeollip hat, blue uniform, holding a wooden club and a small lantern.

Bottom row — second character: Jangyongyeong royal guard soldier: short beard, black jeollip hat with a red tassel, studded armored coat, sword at the hip.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G08 — 도적 · 왈짜
저장: `art_inbox/npcs/G08.png` · 들어가는 것: `npc_thief`, `npc_brawler`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: thief: black headband, dark clothes, a cloth mask over the lower face, sneaky crouching walk.

Bottom row — second character: street brawler: bare topknot, earth-brown clothes with sleeves rolled up, clenched fists, tough look.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G09 — 전기수 · 어부
저장: `art_inbox/npcs/G09.png` · 들어가는 것: `npc_jeongisu`, `npc_fisherman`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: storyteller (jeongisu): thin mustache, white dopo robe, black gat hat, holding an open book and a fan.

Bottom row — second character: fisherman: stubble, straw satgat hat, gray-indigo work clothes, a fishing rod and a fish basket.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G10 — 씨름꾼 · 택견꾼
저장: `art_inbox/npcs/G10.png` · 들어가는 것: `npc_ssireum`, `npc_taekkyeon`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: ssireum wrestler: muscular, bare chest, topknot, white trousers with a satba cloth belt around the waist and thigh.

Bottom row — second character: taekkyeon fighter: white clothes, straw headband, cloth belt, light fighting stance.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## G11 — 어가행렬 정조(기마)
저장: `art_inbox/npcs/G11.png` · 들어가는 것: `parade_king`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly ONE row with ONE character: King Jeongjo in military dress riding a white horse: red robe with gold dragon badge, red felt jeollip hat, sword.

Draw this character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Riders stay on their horse (and palanquin bearers stay together) in all four figures; in the walking figures the horse or bearers are mid-step.
```

## G12 — 혜경궁 가마
저장: `art_inbox/npcs/G12.png` · 들어가는 것: `parade_royal_carriage`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly ONE row with ONE character: royal palanquin (gama) of Lady Hyegyeong: red-lacquered roofed sedan chair with silk curtains carried on poles by four bearers.

Draw this character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Riders stay on their horse (and palanquin bearers stay together) in all four figures; in the walking figures the horse or bearers are mid-step.
```

## G13 — 기마병 · 취타대
저장: `art_inbox/npcs/G13.png` · 들어가는 것: `parade_cavalry`, `parade_musician`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: cavalry officer riding a brown horse: blue armored coat, black jeollip hat, sword.

Bottom row — second character: daechwita military band musician: yellow robe, black jeollip hat with yellow tassel, playing a long brass nabal trumpet.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second. Riders stay on their horse (and palanquin bearers stay together) in all four figures; in the walking figures the horse or bearers are mid-step.
```

## G14 — 기수
저장: `art_inbox/npcs/G14.png` · 들어가는 것: `parade_flag_bearer`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly ONE row with ONE character: flag bearer soldier: armored coat, black jeollip hat, holding a tall pole with a large red-and-yellow royal banner.

Draw this character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand.
```
