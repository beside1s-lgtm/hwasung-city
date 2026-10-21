# 동작 그림 프롬프트 (수정 없이 그대로 사용)

인물이 실제로 일하고 노는 모습(씨름·택견·탈춤·줄타기·강강술래·연날리기·빨래·낚시·전투·도둑질…)에 쓰는 그림입니다. 한 장에 동작 2개(위 줄·아래 줄), 각 줄에 그 동작의 4장면을 왼쪽부터 순서대로. 저장: `art_inbox/actions/A01.png` …

- 한 장마다 새 대화창에서 만드세요. 잘 나온 인물 그림을 첨부하고 `Match the art style of the attached image only; do not copy its characters.`를 앞에 붙이면 화풍이 맞습니다.
- 칸 수가 4개가 아니면 도구가 그 장을 건너뜁니다. 두 사람 동작(씨름·사자춤·널뛰기)은 한 장면의 두 사람을 서로 닿게 그리면 잘 잘립니다.
- 동작 그림이 없는 동안에는 게임이 서 있는 그림 + 코드 움직임으로 대신 보여 줍니다.


## A01 — 씨름 두 장사 · 택견 발차기
저장: `art_inbox/actions/A01.png` · 들어가는 것: `act_ssireum_pair`, `npc_taekkyeon__kick`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: two bare-chested ssireum wrestlers in white trousers with satba belts gripping each other's belts: 1) locked shoulder to shoulder, 2) one lifts the other off the ground, 3) swinging him around, 4) throwing him down to the sand. Each frame shows the whole group as one connected picture.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: taekkyeon fighter in white clothes and straw headband: 1) bouncing stance, 2) stepping forward, 3) high kick with the front leg, 4) landing back in stance. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A02 — 풍물패 상모돌리기 · 사자춤(두 사람이 쓴 사자)
저장: `art_inbox/actions/A02.png` · 들어가는 것: `act_pungmul_sangmo`, `act_lion_dance_pair`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: pungmul farmers' band player in white clothes with red, blue and yellow sashes and a sangmo hat with a long white ribbon, playing a small gong (kkwaenggwari): 1) knees bent, ribbon to the left, 2) hopping, ribbon circling up, 3) ribbon to the right, 4) hopping, ribbon circling down. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: Korean bukcheong lion dance: a shaggy lion costume worn by two dancers (only their legs show) with a big red-faced lion mask: 1) standing, 2) rearing its head up, 3) shaking its mane, 4) crouching low. Each frame shows the whole group as one connected picture.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A03 — 탈춤 · 남사당 줄타기 어름사니
저장: `art_inbox/actions/A03.png` · 들어가는 것: `act_talchum`, `act_rope_walker`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: talchum mask dancer in a yellow robe with very long white sleeves and a white wooden mask with red cheeks: 1) arms out, sleeves flowing, 2) one leg raised, 3) sleeves flung overhead, 4) spinning. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: namsadang tightrope walker in white clothes with a red sash holding an open red fan, balancing on a thin rope (draw only a short piece of rope under the feet): 1) balancing, 2) stepping, 3) bouncing up from the rope, 4) sitting down on the rope. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A04 — 강강술래 아낙 · 연날리는 아이(날리기)
저장: `art_inbox/actions/A04.png` · 들어가는 것: `act_ganggang`, `npc_kite_flyer__fly`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: village woman in a white jeogori and colorful long skirt dancing ganggangsullae, both arms stretched out sideways as if holding neighbors' hands: 1) step left, 2) step right, 3) arms swinging up, 4) skirt twirling. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: boy with a yellow headband flying a kite: holding a wooden kite reel, looking up toward the upper-left, the kite string going up and out of the picture: 1) holding, 2) pulling the string, 3) letting out string, 4) stepping back. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A05 — 쥐불놀이 아이 · 팽이 치는 아이
저장: `art_inbox/actions/A05.png` · 들어가는 것: `act_jwibul`, `act_paengi`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: boy in winter clothes swinging a can of glowing embers on a string in a big circle (jwibulnori): 1) can low, 2) can to the side, 3) can overhead, 4) can on the other side, with orange sparks. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: child whipping a spinning wooden top on ice with a small whip: 1) whip raised, 2) whip striking, 3) watching the top, 4) whip raised again. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A06 — 제기차기 아이 · 전기수 이야기
저장: `art_inbox/actions/A06.png` · 들어가는 것: `act_jegi`, `npc_jeongisu__tell`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: child kicking a jegi shuttlecock with the inner foot: 1) jegi in the air, 2) foot raised kicking, 3) jegi high, 4) hopping. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: storyteller (jeongisu) in a white robe and black gat sitting cross-legged on a straw mat with an open book, telling a story with dramatic gestures: 1) reading, 2) raising the fan, 3) slapping the knee, 4) pointing forward. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A07 — 빨래하는 아낙 · 낚시하는 어부
저장: `art_inbox/actions/A07.png` · 들어가는 것: `npc_peasant_woman__wash`, `npc_fisherman__fish`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: village woman with a white head cloth kneeling at a stream, washing clothes on a flat stone with a wooden laundry paddle: 1) paddle raised, 2) paddle striking, 3) rinsing the cloth, 4) wringing the cloth. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: fisherman in a straw hat sitting on a low stone holding a long fishing rod over water to the lower-left: 1) waiting, 2) rod twitching, 3) pulling up, 4) a small fish on the line. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A08 — 장용영 창 찌르기 · 장용영 조총 사격
저장: `art_inbox/actions/A08.png` · 들어가는 것: `npc_soldier__attack`, `npc_soldier__shoot`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: Jangyongyeong soldier in a black jeollip hat and studded armored coat with a long spear: 1) guard stance, 2) stepping in, 3) thrusting the spear far forward, 4) pulling back. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: Jangyongyeong soldier with a matchlock musket: 1) loading, 2) aiming, 3) firing with a flash and smoke, 4) lowering the musket. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A09 — 도둑 훔치기 · 도둑 도주
저장: `art_inbox/actions/A09.png` · 들어가는 것: `npc_thief__steal`, `npc_thief__run`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: thief in dark clothes with a black headband and cloth mask: 1) crouching and sneaking, 2) reaching out, 3) grabbing a cloth bundle, 4) tucking it under the arm. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: the same thief running away fast carrying a stolen cloth bundle on his back: four running frames. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A10 — 포박된 죄인 · 왈짜 주먹질
저장: `art_inbox/actions/A10.png` · 들어가는 것: `npc_thief__bound`, `npc_brawler__punch`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: the same thief with hands tied behind his back by a thick rope (oraeul), head down, walking: four walking frames, rope trailing behind. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: rough street brawler with a topknot and earth-brown clothes, sleeves rolled up: 1) fists up, 2) throwing a punch, 3) full punch, 4) pulling back. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A11 — 괭이질하는 농부 · 포수 조총 사격
저장: `art_inbox/actions/A11.png` · 들어가는 것: `npc_farmer__hoe`, `npc_hunter__shoot`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: farmer in a straw satgat and white hemp clothes working the field with a hoe: 1) hoe raised, 2) swinging down, 3) hoe in the soil, 4) pulling back. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: hunter in a fur cap and gray clothes with a matchlock musket: 1) kneeling and loading, 2) aiming, 3) firing with a flash and white smoke, 4) lowering the musket. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A12 — 화적 칼 휘두르기 · 포졸 육모방망이 제압
저장: `art_inbox/actions/A12.png` · 들어가는 것: `npc_bandit__attack`, `npc_patrol__subdue`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: bandit with a red headband and rough dark clothes swinging a curved sword: 1) sword raised, 2) slashing, 3) follow-through, 4) guard stance. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: patrol constable (pojol) in a black jeollip hat and blue uniform swinging a hexagonal wooden club (yungmo-bangmangi): 1) club raised, 2) striking down, 3) pressing down, 4) club raised again. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```

## A13 — 장용영 활쏘기 · 망치질하는 대장장이
저장: `art_inbox/actions/A13.png` · 들어가는 것: `npc_soldier__bow`, `npc_artisan_blacksmith__hammer`

```
Pixel art game sprite sheet, Joseon Korea 1790s, cute chibi proportions, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames.

Exactly 2 rows, each a different action.

Top row — exactly 4 frames of one motion, left to right, evenly spaced: Jangyongyeong soldier in a black jeollip hat and armored coat shooting a Korean horn bow: 1) nocking an arrow, 2) drawing the bow, 3) releasing, 4) reaching for the next arrow. The character faces the lower-left in all frames.

Bottom row — exactly 4 frames of one motion, left to right, evenly spaced: blacksmith in a leather apron hammering on an anvil (draw the small anvil): 1) hammer raised, 2) swinging, 3) striking with sparks, 4) lifting again. The character faces the lower-left in all frames.

Keep the same character, clothes and size in every frame of a row. Never mix the two rows.
```
