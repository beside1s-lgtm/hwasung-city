# 지형 프롬프트 — 나무·사계절 논·풀밭·길·저수지

지금 지형 그림(`assets/sprites/terrain/`)은 코드로 찍어 낸 것이라 건물·인물 그림과 따로 놉니다. 같은 화풍으로 다시 그려 바꿉니다.

**하는 법**
1. 장마다 **새 대화창**을 열고, 잘 나온 **건물 그림 한 장을 첨부**한 뒤 아래 영어 프롬프트를 붙여 넣습니다(화풍 맞추기).
2. 받은 그림을 `art_inbox/terrain/T01.png` …처럼 저장합니다. 이름 목록 txt(`T01.txt` …)는 만들어 두었습니다.
3. `python tools/art_ingest.py --check` → `art_inbox/_preview.png`로 확인 → 괜찮으면 `python tools/art_ingest.py`로 넣습니다.
4. 개수가 안 맞는다고 나오면 다시 생성하거나, txt 첫 줄에 `grid=4x2`처럼 칸 수를 적습니다.

**크기**: 나무 32×44(밑동이 아래 가운데), 바닥 타일 64×32 마름모(마름모 밖은 자동으로 투명). 작게 줄어드니 **굵고 또렷한 형태**가 중요합니다.

> ⚠ `grass_*`(풀밭) 4장은 지금 게임이 코드로 직접 칠해서 그림 파일을 아직 읽지 않습니다. 넣은 뒤 게임이 이 PNG를 쓰도록 코드 연결이 따로 필요합니다.

---

## T01 — 소나무 · 느티나무 (사계절)
저장: `art_inbox/terrain/T01.png` · 들어가는 것: `tree_pine_*` 4장, `tree_zelkova_*` 4장

```
Pixel art game sprites in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s (Suwon Hwaseong). Detailed but readable pixel art, rich shading with 3-4 tones per color, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no ground tiles, no grass under the trees — only a small dark oval shadow at the foot of each tree.

Exactly TWO rows of trees, 4 trees in each row, evenly spaced with wide gaps, all the same size, each tree taller than wide (about 3:4), trunk base at the bottom center.

Top row — Korean red pine (sonamu): crooked reddish-brown trunk, layered flat clumps of dark needle foliage, in this order left to right: 1) spring: fresh bright green tips on the needles. 2) summer: deep dark green needles. 3) autumn: dark green needles with a few brown needles. 4) winter: dark green needles with white snow lying on top of each foliage layer.

Bottom row — Korean zelkova (neutinamu), big round village guardian tree, thick gray-brown trunk splitting into branches, wide round crown, in this order left to right: 1) spring: light fresh green small leaves. 2) summer: dense full dark green crown. 3) autumn: orange and rust-red crown. 4) winter: bare branches with no leaves, a little snow on the branches.

Never mix the two kinds of tree.
```

## T02 — 버드나무 · 단풍나무 (사계절)
저장: `art_inbox/terrain/T02.png` · 들어가는 것: `tree_willow_*` 4장, `tree_maple_*` 4장

```
Pixel art game sprites in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s (Suwon Hwaseong). Detailed but readable pixel art, rich shading with 3-4 tones per color, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no ground tiles, no grass under the trees — only a small dark oval shadow at the foot of each tree.

Exactly TWO rows of trees, 4 trees in each row, evenly spaced with wide gaps, all the same size, each tree taller than wide (about 3:4), trunk base at the bottom center.

Top row — weeping willow (beodeunamu) by a stream, dark gnarled trunk, long thin branches hanging down like curtains, in this order left to right: 1) spring: hanging branches of pale yellow-green new leaves. 2) summer: dense hanging green leaves. 3) autumn: hanging yellow leaves. 4) winter: bare thin hanging twigs with a little snow on the top.

Bottom row — Korean maple (danpungnamu), slim dark trunk, round airy crown of hand-shaped leaves, in this order left to right: 1) spring: light green with a reddish tint. 2) summer: fresh green. 3) autumn: vivid crimson red and orange, a few red leaves falling. 4) winter: bare branching twigs with a little snow.

Never mix the two kinds of tree.
```

## T03 — 벚나무 (사계절)
저장: `art_inbox/terrain/T03.png` · 들어가는 것: `tree_cherry_*` 4장

```
Pixel art game sprites in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s (Suwon Hwaseong). Detailed but readable pixel art, rich shading with 3-4 tones per color, clean dark outline, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no ground tiles, no grass under the trees — only a small dark oval shadow at the foot of each tree.

Exactly ONE row of 4 trees, evenly spaced with wide gaps, all the same size, each tree taller than wide (about 3:4), trunk base at the bottom center.

Wild Korean cherry tree (beotnamu), dark brown trunk with horizontal bark stripes, rounded spreading crown, in this order left to right: 1) spring: full of pale pink blossoms, a few petals falling. 2) summer: dense green leaves with a few small dark red cherries. 3) autumn: orange-red and yellow leaves. 4) winter: bare dark branches with a little snow.
```

## T04 — 논 (사계절 + 기본)
저장: `art_inbox/terrain/T04.png` · 들어가는 것: `farm_spring`, `farm_summer`, `farm_autumn`, `farm_winter`, `farm_normal`

```
Pixel art isometric ground tiles in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s. Detailed but readable pixel art, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background. No text, no labels, no frames.

IMPORTANT tile shape: each tile is ONE flat isometric diamond (rhombus) seen from above, exactly twice as wide as it is tall (2:1), with the four corners at top, right, bottom and left. Completely flat: NO thickness, NO side walls, NO dirt edge under it, NO outline around the diamond. The texture fills the whole diamond to its edges, and the edges should tile seamlessly when the same tile is placed next to itself. Nothing sticks out of the diamond.

Draw exactly 5 tiles in ONE row, evenly spaced with wide gaps, all the same size, a Korean rice paddy (non) with neat rows of rice running diagonally along the diamond and a thin raised earth ridge along the edges, in this order left to right:
1) spring: flooded paddy, shining blue-gray water with rows of small young green rice seedlings just planted.
2) summer: lush tall bright green rice plants densely filling the paddy.
3) autumn: ripe golden-yellow rice with drooping heavy heads.
4) winter: harvested paddy, short pale stubble in rows, patches of white snow and thin ice.
5) neutral: plowed brown mud paddy with a little water, ready for planting.
```

## T05 — 풀밭 (사계절)

> 겨울 풀밭이 마음에 안 들면 이 프롬프트로 T05를 다시 받아 넣으면 됩니다(네 장 모두 새 그림으로 바뀜). 큰 눈덩이 무늬는 칸마다 반복되어 바둑판처럼 보이니, 고운 무늬가 나올 때까지 다시 생성하세요.
저장: `art_inbox/terrain/T05.png` · 들어가는 것: `grass_spring`, `grass_summer`, `grass_autumn`, `grass_winter`

```
Pixel art isometric ground tiles in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s. Detailed but readable pixel art, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background. No text, no labels, no frames.

IMPORTANT tile shape: each tile is ONE flat isometric diamond (rhombus) seen from above, exactly twice as wide as it is tall (2:1), with the four corners at top, right, bottom and left. Completely flat: NO thickness, NO side walls, NO dirt edge under it, NO outline around the diamond. The texture fills the whole diamond to its edges, and the edges should tile seamlessly when the same tile is placed next to itself. Nothing sticks out of the diamond. Keep the texture subtle and even (no big single objects), because hundreds of these tiles are laid side by side.

Draw exactly 4 tiles in ONE row, evenly spaced with wide gaps, all the same size, a natural Korean meadow ground, in this order left to right:
1) spring: fresh light green short grass with a few tiny yellow and purple wildflowers.
2) summer: deep rich green thick grass with small clover clumps.
3) autumn: dry olive and golden-brown grass with a few fallen orange leaves.
4) winter: an even, thin layer of fine powdery snow over pale dry grass, with tiny grass tips showing through everywhere. Fine small speckled texture only — NO big snow patches, NO large bare spots, no blobs.
```

## T06 — 흙길 · 돌길 · 저수지 물
저장: `art_inbox/terrain/T06.png` · 들어가는 것: `dirt_road`, `stone_road`, `reservoir`

```
Pixel art isometric ground tiles in the same art style as the attached image if one is attached, for an isometric city game set in Joseon Korea 1790s. Detailed but readable pixel art, soft light from the upper left. Wide landscape image (16:9). Plain flat light gray background. No text, no labels, no frames.

IMPORTANT tile shape: each tile is ONE flat isometric diamond (rhombus) seen from above, exactly twice as wide as it is tall (2:1), with the four corners at top, right, bottom and left. Completely flat: NO thickness, NO side walls, NO outline around the diamond. The texture fills the whole diamond to its edges, and the edges should tile seamlessly when the same tile is placed next to itself. Nothing sticks out of the diamond.

Draw exactly 3 tiles in ONE row, evenly spaced with wide gaps, all the same size, in this order left to right:
1) dirt road: packed light brown earth with faint cart wheel ruts, footprints and small pebbles.
2) stone road: irregular flat gray granite paving stones fitted together with thin dark gaps and a little moss.
3) reservoir water: calm deep blue-green pond water with soft light ripples and small highlights, no shore, no plants.
```
