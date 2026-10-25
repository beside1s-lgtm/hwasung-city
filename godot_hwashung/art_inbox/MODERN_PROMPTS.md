# Gemini 그림 생성 프롬프트 — 근대화 시대(1820~1900년대)

근대화 시대에 쓸 근대 건물 14장, 시민 6장, 엔딩 그림 1장, 도로 1장입니다. 쓰는 법은 [PROMPTS.md](PROMPTS.md)와 같습니다.
**각 프롬프트를 그대로 붙여 넣고, 나온 그림을 제목의 파일 이름으로 저장**하세요. 이름 목록(`.txt`)은 이미 만들어 두었습니다.

## 쓰는 순서
1. 아래 프롬프트 하나를 복사해 **새 대화창**에서 Gemini에 붙여 넣는다.
2. 화풍 맞추기: 건물은 `assets/sprites/buildings/chukmanje.png`, 시민은 기존 인물 그림 한 장(예: `assets/sprites/npcs/npc_farmer.png`)을 첨부하고, 프롬프트 앞에 다음 문장을 붙인다.
   `Match the art style of the attached image only; do not copy its buildings or characters.`
3. 나온 그림을 제목에 적힌 이름으로 저장한다(예: `art_inbox/buildings/M01.png`).
4. 미리보기 → 괜찮으면 교체:
   ```
   python tools/art_ingest.py --check
   python tools/art_ingest.py
   ```
   근대 건물은 `assets/sprites/buildings_modern/`, 시민은 `assets/sprites/npcs/`, 도로는 `assets/sprites/terrain/`에 들어갑니다.
5. Godot 편집기를 한 번 열어 새 그림을 가져온다.

> 화성 문화재(성곽·사대문·수문·군사시설·화성행궁)는 근대화 시대에도 바뀌지 않으므로 그림이 필요 없습니다.
> 축만제·만석거는 [호수공원 조성]을 하면 M04·M05 그림으로 바뀝니다.

---

# 건물

## M01 — 1단계 석조 건물 6종 (1820~)
저장: `art_inbox/buildings/M01.png` · 들어가는 것: `stone_house_01`, `stone_house_02`, `stone_house_03`, `stone_shop_01`, `stone_shop_02`, `stone_office_01`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, during its 19th-century modernization (1820s-1880s), when traditional Joseon houses were gradually rebuilt in stone. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Style: neoclassical and early modernist stone buildings that still feel Korean: pale granite or light gray cut-stone walls, tall arched or rectangular windows with white frames, small balconies, and roofs that mix charcoal-blue giwa roof tiles with flat stone cornices. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 6 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of three objects (3 columns x 2 rows). Each is a small one- or two-story building on a 1x1 diamond plate; the whole object (plate + building) should be about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) small one-story granite house with a giwa tile roof, arched windows and a stone doorstep. 2) two-story light gray stone house with a small iron-railed balcony and a hip roof of dark tiles. 3) granite house with a stone wall fence, a small garden tree and white-framed windows. 4) one-story stone shop with a large arched glass shop window and a striped cloth awning. 5) two-story stone shop with a wooden shop door, display window and a flat cornice roof. 6) small neoclassical stone public office or bank with four white columns, a triangular pediment and wide front steps.
```

## M02 — 2단계 택지: 빌라·붉은벽돌 양옥 4종 (대도시화)
저장: `art_inbox/buildings/M02.png` · 들어가는 것: `villa_01`, `villa_02`, `brick_mansion_01`, `brick_mansion_02`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930, when the city became a modern metropolis. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (grass, packed earth or stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Each sits on a 1x1 diamond plate; the whole object (plate + building) should be about as tall as it is wide, a little taller for the three-story ones.

Objects in reading order (left to right, top to bottom): 1) three-story cream-colored stucco row house (small apartment villa) with repeated windows, a flat roof and an outside staircase. 2) two-story gray concrete row house with small balconies, potted plants and a flat roof with a water tank. 3) Western-style red-brick mansion with a steep red tile roof, white window frames, a chimney and a small front garden with a low iron fence. 4) red-brick two-story house with a wooden veranda, a bay window, a red tile roof and a garden tree.
```

## M03 — 2단계 상업시설 빌딩 2 + 공업지역(옛 대유둔전) 공장 2 (2x2)
저장: `art_inbox/buildings/M03.png` · 들어가는 것: `modern_highrise_01`, `modern_highrise_02`, `factory_01`, `factory_02`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930, when the city became a modern metropolis. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (stone or concrete paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Each is a large building on a 2x2 diamond plate (twice as wide as a single house plate). The buildings are tall: the whole object is about as tall as it is wide.

Objects in reading order (left to right, top to bottom): 1) five-story red-brick department store with rows of arched windows, white stone trim on every floor, a corner clock tower and a flat roof with a railing. 2) six-story pale concrete commercial building in early modernist style with long horizontal window bands, a ground-floor arcade of shop windows and a flagless rooftop. 3) red-brick steam factory with a saw-tooth roof, two tall brick chimneys puffing white steam, large iron-framed windows and a big gear wheel on the wall. 4) electric power and machine factory of gray brick with one tall chimney, a water tower, power poles with wires and stacked wooden crates by the door.
```

## M04 — 축만제(서호) 호수공원 (7x7)
저장: `art_inbox/buildings/M04.png` · 들어가는 것: `chukmanje_park`

```
Detailed isometric pixel art game asset for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south). The object sits on ONE large diamond-shaped ground plate whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY ONE object filling most of the image: Seoho (Chukmanje) lake park, a large reservoir turned into a modern public park on a big 7x7 diamond plate. A calm blue-green lake in the middle with a small island of willow trees, a granite-edged embankment (the old Joseon dam) along one side kept intact, a curving lakeside promenade of light stone paving with iron street lamps and wooden benches, rows of cherry and willow trees, a small white Western-style gazebo bandstand by the water, a little wooden pier with two rowing boats, flower beds and lawns, and a small traditional Korean pavilion (hangjeong) with a giwa roof on a rocky point.
```

## M05 — 만석거 호수공원 (7x7)
저장: `art_inbox/buildings/M05.png` · 들어가는 것: `manseokgeo_park`

```
Detailed isometric pixel art game asset for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south). The object sits on ONE large diamond-shaped ground plate whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY ONE object filling most of the image: Manseokgeo lake park, an old Joseon irrigation reservoir turned into a modern public park on a big 7x7 diamond plate. A wide blue lake with a granite sluice gate and stone embankment from the Joseon era kept intact, the small traditional Yeonghwajeong-style pavilion with a giwa roof on the southern bank, a modern lakeside walking path of red brick with iron lamps and benches, a white wooden boathouse with a dock and swan boats, lotus leaves near the shore, lawns with a fountain, pine and zelkova trees, and a small arched stone footbridge over the inlet.
```

## M06 — 자동차·노면전차 (앞·뒤)
저장: `art_inbox/buildings/M06.png` · 들어가는 것: `veh_car_front`, `veh_car_back`, `veh_tram_front`, `veh_tram_back`

```
Detailed isometric pixel art game vehicle sprites for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. NO ground plate under the vehicles: each vehicle stands alone with only a small dark oval shadow under its wheels. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no grid lines, no frames, no borders.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Top row: the car. Bottom row: the tram, which is about twice as long as the car.

Objects in reading order (left to right, top to bottom): 1) classic black Ford Model T style car with a folded canvas roof, spoked wheels and brass headlamps, seen from the front three-quarter view driving toward the lower-left. 2) the same car seen from the back three-quarter view driving away toward the upper-left. 3) single-car electric streetcar (tram) painted dark green and cream with a row of windows, a trolley pole on the roof and a headlamp, seen from the front three-quarter view moving toward the lower-left. 4) the same streetcar seen from the back three-quarter view moving away toward the upper-left.
```

## M07 — 2단계 금융·서비스 구역 (옛 공방 자리) 4종
저장: `art_inbox/buildings/M07.png` · 들어가는 것: `finance_bank_01`, `finance_office_01`, `service_hotel_01`, `service_cafe_01`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930, when the city became a modern metropolis. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (stone or concrete paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in a neat grid exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 4 separate objects, one for each numbered description below. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Layout: Two rows of two objects (2 columns x 2 rows). Each sits on a 1x1 diamond plate; the whole object (plate + building) should be about as tall as it is wide, a little taller for the three-story ones. No smoke, no chimneys, no factories: these are clean office and service buildings.

Objects in reading order (left to right, top to bottom): 1) small granite bank building with a domed corner entrance, tall arched windows, heavy wooden doors and a bronze lamp on each side. 2) three-story red-brick office building for an insurance and securities company with rows of tall windows, a stone ground floor and a flat roof with a small railing. 3) three-story white stucco Western-style hotel with green window shutters, small balconies, a canopy over the entrance and potted palm trees. 4) one-story tearoom and Western restaurant (dabang) with a large glass front window, a striped awning, two small outdoor tables with chairs and a hanging lamp.
```

## M08 — 연무대 신식 군사기지 (2x2)
저장: `art_inbox/buildings/M08.png` · 들어가는 것: `yeonmudae_base`

```
Detailed isometric pixel art game asset for a city-builder game set in Suwon, Korea, around 1880-1910. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south). The object sits on ONE diamond-shaped ground plate whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Absolutely no text, no labels, no numbers, no letters, no flags with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY ONE object filling most of the image, on a 2x2 diamond plate: a modern Korean army base built around the old Yeonmudae (Dongjangdae) command post. At the back, the traditional Joseon command pavilion with a charcoal-blue giwa roof on a granite platform is kept intact as a heritage building. In front of it, a flat sandy parade ground with a row of small soldiers in dark blue Western-style uniforms, two red-brick barracks with gray slate roofs, a pair of modern field cannons on wheels, a wooden flagpole without a flag, stacked ammunition crates and a low stone wall with an iron gate around the base.
```

## M09 — 근대 관공서: 정부청사 · 경찰서 · 소방서
저장: `art_inbox/buildings/M09.png` · 들어가는 것: `gov_office`, `police_station`, `fire_station`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (stone paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in ONE row exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no flags with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 3 separate objects, one for each numbered description below, left to right. Do not combine two descriptions into one object, do not skip any, do not add extra objects. The first object is on a large 2x2 diamond plate (about twice as wide as the others); the second and third are on small 1x1 diamond plates and are about as tall as they are wide.

1) government office building: a symmetrical two-story granite and red-brick neoclassical building with a central clock tower, white columns at the entrance, wide stone steps, a flagpole without a flag and a small front lawn with trimmed trees. 2) police station: a small two-story red-brick building with a dark green door, a round red lamp above the entrance, barred windows and a bicycle parked by the wall. 3) fire station: a red-brick building with a large arched wooden garage door, a tall square fire watchtower with a bell on top, and a red horse-drawn fire pump cart with a coiled hose parked in front.
```

## M10 — 복지관 (옛 진휼소, 2x2)
저장: `art_inbox/buildings/M10.png` · 들어가는 것: `welfare_center`

```
Detailed isometric pixel art game asset for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south). The object sits on ONE diamond-shaped ground plate (stone paving and a little lawn) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY ONE object filling most of the image, on a 2x2 diamond plate: a warm, welcoming public welfare center. A two-story cream-colored building with a red tile roof, large friendly windows and a covered front porch, a small courtyard with wooden benches, a big iron soup pot on a stove under an awning with stacked rice sacks beside it, a small vegetable garden, a shade tree and a low hedge fence with an open gate.
```

## M11 — 수원 대학교 · 초등학교 · 중등학교
저장: `art_inbox/buildings/M11.png` · 들어가는 것: `university`, `elementary_school`, `secondary_school`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (stone paving, lawn or a dirt schoolyard) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in ONE row exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no flags with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 3 separate objects, one for each numbered description below, left to right. Do not combine two descriptions into one object, do not skip any, do not add extra objects. Sizes: the first is the largest, on a big 4x4 diamond plate; the second is the smallest, on a 2x2 plate; the third is in between, on a 3x3 plate.

1) university campus built around the old Suwon Hyanggyo Confucian school: at the back, the traditional Myeongnyundang lecture hall with a charcoal-blue giwa roof and old ginkgo trees kept intact as heritage; in front, a large three-story red-brick Gothic-style main hall with a pointed clock tower, arched windows and ivy on the walls, a stone gate with iron bars, a lawn quad crossed by paths and a few benches. 2) small elementary school: a one-story wooden schoolhouse painted cream with green window frames and a small bell tower, a dirt playground with a swing, a seesaw and a tall flagpole without a flag. 3) secondary school: a two-story red-brick school building with long rows of windows, a central entrance porch, a sports field with a running track and a small gym building with a gray slate roof.
```

## M13 — 대통령궁·국회·법원 (옛 화성행궁, 7x7)
저장: `art_inbox/buildings/M13.png` · 들어가는 것: `haenggung_republic`

```
Detailed isometric pixel art game asset for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south). The object sits on ONE large diamond-shaped ground plate whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Absolutely no text, no labels, no numbers, no letters, no flags with writing, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY ONE object filling most of the image, on a big 7x7 diamond plate: the old Hwaseong Haenggung royal palace complex turned into the seat of a modern republic. The traditional palace halls with charcoal-blue giwa roofs, red pillars and stone courtyards are all kept intact as heritage, and the main hall (Bongsudang) is now the presidential office. Inside the palace walls, add two modest new buildings that respect the old style: on the left a two-story granite National Assembly hall with a low green copper dome, and on the right a red-brick courthouse with white columns. Neat lawns, stone paths, a few pine trees, and guards in dark modern uniforms at the main gate (Sinpungnu).
```

---

## M14 — 마당 근대화: 시민공원 · 어린이 놀이터 · 체육공원
저장: `art_inbox/buildings/M14.png` · 들어가는 것: `park_citizen`(3x3, 옛 저잣거리 난전 마당), `playground_modern`(2x2, 옛 주거지 어린이 마당), `sports_park`(2x2, 옛 여인 놀이마당)
가공 뒤 위치: `assets/sprites/buildings_modern/park_citizen.png`, `playground_modern.png`, `sports_park.png`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object is a flat open-air ground area on its own diamond-shaped ground plate whose two front edges show a thin layer of earth and stone; objects on it are low (no tall buildings), so the whole object is wider than it is tall. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in ONE row exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no people, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 3 separate objects, one for each numbered description below, left to right. Do not combine two descriptions into one object, do not skip any, do not add extra objects. The first object is on a larger 3x3 diamond plate; the second and third are on smaller 2x2 diamond plates (two thirds the width of the first).

1) small public city park (former market square): a lawn crossed by light stone paths meeting at a round fountain, wooden benches, iron street lamps, flower beds, two shade trees and a small white bandstand gazebo. 2) modern children's playground: sandy ground with a red slide, a two-seat swing set with a metal frame, a seesaw, a sandbox with a low wooden border and a small climbing frame, surrounded by a low green fence and one tree. 3) small sports park (former women's play yard): a packed-dirt field with a white-lined running track loop, a pair of parallel bars, a high bar, a long-jump sand pit and a low spectator bench under a tree.
```

---

## M15 — 근대 수도체제: 집수정 · 생활용수 공급시설 · 하수처리시설
저장: `art_inbox/buildings/M15.png` · 들어가는 것: `water_collector`(1x1, 옛 우물), `water_supply_plant`(1x1, 저수지 위에 얹힘), `lm_sewage`(2x2, 하수처리시설)
가공 뒤 위치: `assets/sprites/buildings_modern/water_collector.png`, `assets/sprites/buildings_modern/water_supply_plant.png`, `assets/sprites/buildings/lm_sewage.png`

```
Detailed isometric pixel art game asset sheet for a city-builder game set in Suwon, Korea, around 1900-1930, when a modern waterworks system was built. Strict 2:1 isometric projection (classic 45-degree diagonal view, camera looking down from the south), the same angle for every object. Every object sits on its own diamond-shaped ground plate (stone or concrete paving) whose two front edges show a thin layer of earth and stone. Crisp hand-placed pixels, rich but limited palette, soft sunlight from the upper left, darker outlines on silhouettes. Background: plain flat solid light gray (#d9d9d9), completely empty. Arrange the objects in ONE row exactly as listed, with very wide empty gaps between them (at least half an object width); no object may touch another. Absolutely no text, no labels, no numbers, no letters, no signboards with writing, no people, no grid lines, no frames, no borders, no cast shadow on the background.

Draw EXACTLY 3 separate objects, one for each numbered description below, left to right. Do not combine two descriptions into one object, do not skip any, do not add extra objects. The first two are small, on 1x1 diamond plates, each about as tall as it is wide; the third is on a larger 2x2 diamond plate (twice as wide).

1) neighborhood water collection well (jipsujeong): a round concrete well head with a cast-iron hand pump and spout, a small red-brick pump house with a gray slate roof, a drain channel and a wooden bucket. 2) small water supply station: a short round brick water tower on stone legs with a cone roof, connected by iron pipes to a little filtering tank with a valve wheel; drawn so it can stand on the edge of a pond. 3) early modern sewage treatment plant: two round open concrete settling tanks with dark water and a rotating arm bridge, a rectangular filter bed, a red-brick pump building with a tall narrow chimney and arched windows, iron pipes and a low brick wall around the site.
```

---

# 엔딩 그림

## M12 — 현대 수원 전경 3종 (1945년 근대화 본 엔딩, 엔딩마다 다른 그림)
가공 도구를 거치지 않고 아래 이름으로 **`assets/illustrations/`에 바로** 넣습니다(16:9 가로 그림 권장).

| 엔딩 | 파일 |
|---|---|
| 글로벌 선진국 도약 | `assets/illustrations/modern_suwon_global_advanced.png` |
| 중진국의 늪 | `assets/illustrations/modern_suwon_middle_trap.png` |
| 후진국화 | `assets/illustrations/modern_suwon_underdeveloped.png` |

엔딩 때 플레이어의 도시 화면이 해당 엔딩 그림으로 천천히 겹쳐 바뀝니다. 엔딩 그림이 없으면 공용 그림 `assets/illustrations/modern_suwon_hwaseong.png`를 쓰고, 그것도 없으면 화면이 어둡게 사라지며 자막만 나옵니다.
아래 프롬프트는 공용(선진국) 모습의 예시입니다.

```
A wide, beautiful aerial panorama of present-day Suwon Hwaseong Fortress in South Korea, seen from high above toward the north at golden hour. The complete stone fortress wall loops around Paldalsan mountain and the old town, with Paldalmun gate as a roundabout island in the city traffic, Janganmun gate, Hwahongmun floodgate with its seven arches over the stream, Banghwasuryujeong pavilion beside the Yongyeon pond, and the restored Hwaseong Haenggung palace below the mountain. Around and beyond the walls spreads a modern Korean city: apartment towers, low-rise shops, tree-lined roads with cars, and green parks, all in harmony with the heritage fortress. Soft warm sunlight, clear sky, detailed but painterly digital illustration in a gentle pixel-art-inspired style, 16:9 landscape. No text, no logos, no watermarks.
```

## 초상 — 비서실장 김종수 (대통령제 길잡이)
가공 도구를 거치지 않고 **`assets/sprites/npcs/named/`에 바로** 넣습니다. 크기 200x200(기존 김판관 초상 `kim_pangwan_tier0.png`와 같게), 배경 투명.

- 한 장만 넣을 때: `kim_secretary.png`
- 김판관처럼 추천 정확도에 따라 세 모습으로 바꾸려면: `kim_secretary_tier0.png`(어벙) · `kim_secretary_tier1.png`(착실) · `kim_secretary_tier2.png`(엘리트)

대통령제(또는 계엄 통치)가 되면 길잡이 이름이 '비서실장 김종수'로 바뀌고 이 초상이 나옵니다. 파일이 없으면 김판관 초상 그대로입니다.

---

# 시민

## MN01 — 양복 신사 · 근대 노동자
저장: `art_inbox/npcs/MN01.png` · 들어가는 것: `npc_modern_gentleman`, `npc_modern_worker`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Korean gentleman in a dark gray three-piece Western suit with a white shirt and tie, a black fedora hat, round glasses and a short mustache, holding a walking cane.

Bottom row — second character: Korean factory worker in a light blue work shirt with rolled sleeves, brown suspenders and work trousers, a flat newsboy cap, carrying a wrench over his shoulder.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## MN02 — 모던걸 · 양장 부인
저장: `art_inbox/npcs/MN02.png` · 들어가는 것: `npc_modern_girl`, `npc_modern_lady`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Korean "modern girl": short bobbed black hair, a reformed hanbok with a short white jeogori and a calf-length pleated pastel pink skirt, white stockings and black strap shoes, holding a small handbag.

Bottom row — second character: Korean lady in Western dress: a long navy blue wool coat over a long skirt, a small cloche hat, gloves, holding an open white lace parasol.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## MN03 — 남학생 · 여학생
저장: `art_inbox/npcs/MN03.png` · 들어가는 것: `npc_modern_student`, `npc_modern_schoolgirl`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Korean schoolboy in a black high-collared school uniform with gold buttons and a black peaked student cap, carrying a leather satchel.

Bottom row — second character: Korean schoolgirl with a long single braid tied with a red ribbon, a white jeogori and a long black skirt, holding books wrapped in a cloth bundle (bojagi).

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## MN04 — 자전거 탄 사람 · 신문팔이 소년
저장: `art_inbox/npcs/MN04.png` · 들어가는 것: `npc_modern_cyclist`, `npc_modern_vendor`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Korean man in a brown suit and flat cap riding an old black bicycle with a high frame and a small basket on the handlebar. In this row the "walking" poses are riding poses with the pedals in a different position.

Bottom row — second character: Korean newspaper boy in a gray flat cap, short jacket and knee-length trousers, carrying a thick bundle of folded newspapers under one arm and holding one paper up in the other hand.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## MN05 — 근대 공무원 · 근대 경찰
저장: `art_inbox/npcs/MN05.png` · 들어가는 것: `npc_modern_official`, `npc_modern_police`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly TWO rows, two different characters.

Top row — first character: Korean government official in a black Western suit with a high white collar and a black bow tie, neatly parted short hair, holding a leather document folder under one arm.

Bottom row — second character: Korean police officer in a dark navy uniform with brass buttons, a peaked cap with a small badge, a white belt and white gloves, holding a short wooden baton.

In each row draw that row's character exactly 4 times, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. In a row, all four figures are the same person with the same clothes, hat and held item in the same hand. Never mix the two characters: the top row is only the first character, the bottom row is only the second.
```

## MN06 — 근대 소방관
저장: `art_inbox/npcs/MN06.png` · 들어가는 것: `npc_modern_firefighter`

```
Pixel art game sprite sheet, Korea in the early 1900s modernization era, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly ONE row, one character: Korean firefighter in a dark blue double-breasted fire coat with brass buttons, a shiny brass fire helmet with a crest, tall black boots, carrying a coiled canvas fire hose over one shoulder and a small fire axe in the other hand.

Draw the character exactly 4 times in the row, evenly spaced, all the same height, each with a small dark oval shadow: 1) front three-quarter view, standing, facing the lower-left. 2) the same front view walking toward the lower-left, one foot forward. 3) back three-quarter view, standing, facing away toward the upper-left. 4) the same back view walking toward the upper-left, one foot forward. All four figures are the same person with the same clothes, helmet and held items in the same hands.
```

---

# 도로

## MT01 — 전철 궤도 · 아스팔트 도로
저장: `art_inbox/terrain/MT01.png` · 들어가는 것: `road_tram`, `road_asphalt`

```
Pixel art isometric ground tiles in the same art style as the attached image if one is attached, for an isometric city game set in Korea around 1900-1930. Detailed but readable pixel art, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background. No text, no labels, no frames.

IMPORTANT tile shape: each tile is ONE flat isometric diamond (rhombus) seen from above, exactly twice as wide as it is tall (2:1), with the four corners at top, right, bottom and left. Completely flat: NO thickness, NO side walls, NO outline around the diamond. The texture fills the whole diamond to its edges, and the edges should tile seamlessly when the same tile is placed next to itself. Nothing sticks out of the diamond.

Draw exactly 2 tiles in ONE row, evenly spaced with wide gaps, all the same size, in this order left to right:
1) streetcar track road: gray granite cobblestone paving with two parallel shiny steel rails running straight through the middle from the lower-left edge to the upper-right edge.
2) asphalt road: smooth dark charcoal asphalt with a faint dashed white center line running from the lower-left edge to the upper-right edge and slightly lighter worn tire tracks.
```
