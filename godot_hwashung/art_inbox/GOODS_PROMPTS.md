# 물품 그림 프롬프트 (수정 없이 그대로 사용)

공방 장인이 다루는 도구·재료, 짐꾼이 나르는 짐, 장터 좌판의 물건입니다. 지금은 코드로 그린 네모·동그라미라 투박해 보이던 것들을 바꿉니다.
한 장에 물건 6개(3열 × 2줄). 저장: `art_inbox/goods/G01.png` … 이름 목록(txt)은 이미 들어 있으니 그림만 넣으면 됩니다.

- 한 장마다 새 대화창에서 만드세요. 잘 나온 건물 그림을 첨부하고 `Match the art style of the attached image only.`를 앞에 붙이면 화풍이 맞습니다.
- 물건 수가 6개가 아니면 도구가 그 장을 건너뜁니다. 물건끼리 떨어뜨려 그리게 하세요.
- 그림이 없는 물건은 게임이 예전 코드 그림으로 대신 보여 줍니다.

## G01 — 공방 작업대·도구
저장: `art_inbox/goods/G01.png` · 들어가는 것: `anvil`(모루와 망치), `workbench`(목공 작업대), `stone_block`(다듬던 화강암), `dye_vat`(쪽물 독), `dyed_cloth`(물들인 천 장대), `paper_vat`(한지 뜨는 지통)

```
Pixel art game item icons, Joseon Korea 1790s, isometric 3/4 view from the upper front, clean dark brown outline, warm natural colors, soft light from the upper left, small cast shadow under each object. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no people.

Exactly 6 separate objects in a 3 by 2 grid (3 on the top row, 3 on the bottom row), evenly spaced with clear empty space between them, each drawn at a similar size, in this order left to right, top to bottom:
1) a black iron anvil on a wooden stump with a smith's hammer leaning on it.
2) a low wooden carpenter's workbench with a plane, a saw and wood shavings.
3) a half-carved light gray granite block with a chisel and mallet beside it.
4) a large brown earthenware jar full of deep indigo dye with a wooden stirring stick.
5) a wooden drying pole with long hanging cloths dyed indigo blue, red and yellow.
6) a wooden vat of milky pulp water with a bamboo papermaking screen resting on the rim.

Each object stands alone; do not let objects touch or overlap.
```

## G02 — 짐
저장: `art_inbox/goods/G02.png` · 들어가는 것: `log_bundle`(통나무 짐), `roof_tiles`(기와 한 짐), `crate`(나무 궤짝), `bundle`(보자기 보따리), `rice_sack`(쌀가마니), `salt_sack`(소금 섬)

```
Pixel art game item icons, Joseon Korea 1790s, isometric 3/4 view from the upper front, clean dark brown outline, warm natural colors, soft light from the upper left, small cast shadow under each object. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no people.

Exactly 6 separate objects in a 3 by 2 grid (3 on the top row, 3 on the bottom row), evenly spaced with clear empty space between them, each drawn at a similar size, in this order left to right, top to bottom:
1) a bundle of three pine logs tied with straw rope.
2) a neat stack of dark gray curved Korean roof tiles tied with rope.
3) a wooden storage chest with iron corner fittings and a lock.
4) a cloth bundle wrapped in a patterned bojagi cloth tied in a knot on top.
5) a woven straw rice sack (gamani) tied at both ends.
6) a straw bag of coarse white sea salt, some salt spilling at the top.

Each object stands alone; do not let objects touch or overlap.
```

## G03 — 장터 물건
저장: `art_inbox/goods/G03.png` · 들어가는 것: `onggi`(옹기 항아리), `brassware`(놋그릇 한 벌), `silk_bolt`(비단 필), `straw_shoes`(짚신 꾸러미), `gat`(갓), `herb_pack`(약첩 꾸러미)

```
Pixel art game item icons, Joseon Korea 1790s, isometric 3/4 view from the upper front, clean dark brown outline, warm natural colors, soft light from the upper left, small cast shadow under each object. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no people.

Exactly 6 separate objects in a 3 by 2 grid (3 on the top row, 3 on the bottom row), evenly spaced with clear empty space between them, each drawn at a similar size, in this order left to right, top to bottom:
1) three dark brown glazed onggi jars of different sizes standing together.
2) a set of shiny golden brass (yugi) bowls and a lidded rice bowl stacked.
3) three rolled bolts of silk fabric in red, jade green and sky blue.
4) several pairs of straw sandals (jipsin) hung together on a string.
5) a traditional Korean black horsehair gat hat with a wide brim.
6) small paper-wrapped herbal medicine packets tied in a string and a few dried roots.

Each object stands alone; do not let objects touch or overlap.
```

## G04 — 장터 먹거리
저장: `art_inbox/goods/G04.png` · 들어가는 것: `yeot_tray`(엿판과 가위), `tteok`(떡 시루), `dried_fish`(굴비 두름), `fish_basket`(생선 광주리), `fruit_basket`(과일 광주리), `makgeolli`(막걸리 동이)

```
Pixel art game item icons, Joseon Korea 1790s, isometric 3/4 view from the upper front, clean dark brown outline, warm natural colors, soft light from the upper left, small cast shadow under each object. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no people.

Exactly 6 separate objects in a 3 by 2 grid (3 on the top row, 3 on the bottom row), evenly spaced with clear empty space between them, each drawn at a similar size, in this order left to right, top to bottom:
1) a wooden tray of pale taffy yeot sticks with big iron candy-seller scissors.
2) an earthenware steamer of rice cakes with white and red bean tteok slices on top.
3) a string of ten dried yellow croakers (gulbi) tied with straw.
4) a round bamboo basket of fresh silver fish.
5) a round bamboo basket of red persimmons, pears and jujubes.
6) an earthenware jar of milky makgeolli rice wine with a gourd ladle and a small bowl.

Each object stands alone; do not let objects touch or overlap.
```


## G05 — 서책·그림·관아·들판
저장: `art_inbox/goods/G05.png` · 들어가는 것: `book_open`(펼친 선장본 책), `book_stack`(선장본 책 더미), `seoan`(서안·낮은 책상), `painting_sheet`(그림 그린 화지와 벼루), `scarecrow`(허수아비), `hyeongteul`(형틀)

서당·서원 학동이 무릎에 펼친 책, 유생이 옆구리에 낀 책, 관아 사또 앞 서안, 김홍도가 돗자리에 펴 놓고 그리는 그림, 들판 허수아비, 관아 형틀입니다. 지금은 코드로 그린 그림이 대신 나옵니다.

```
Pixel art game item icons, Joseon Korea 1790s, isometric 3/4 view from the upper front, clean dark brown outline, warm natural colors, soft light from the upper left, small cast shadow under each object. Wide landscape image (16:9). Plain flat light gray background, nothing else in the image. No text, no labels, no frames, no people.

Exactly 6 separate objects in a 3 by 2 grid (3 on the top row, 3 on the bottom row), evenly spaced with clear empty space between them, each drawn at a similar size, in this order left to right, top to bottom:
1) an open Korean thread-bound book (seonjangbon) lying flat: two cream hanji pages with tiny vertical lines of black brush writing, a yellow-brown cover edge.
2) a small stack of three closed Korean thread-bound books with yellow-brown covers, red thread stitching on the left spine and a white title label.
3) a low dark wooden Korean writing desk (seoan) with a sheet of paper, a brush, an ink stone and a small red seal box on top.
4) a sheet of white hanji paper lying flat with a Kim Hong-do style ink painting of two people and a pine tree with light color washes, a black ink stone and a bamboo brush holder beside it.
5) a Korean straw scarecrow on a wooden pole: a head made of a straw bundle with a face drawn in charcoal, a worn conical straw hat, a faded white ragged jacket on a crossbar with straw sticking out of the sleeves, a straw rope belt.
6) a Joseon punishment bench (hyeongteul): a long narrow dark wooden bench on four short legs with rope ties.

Each object stands alone; do not let objects touch or overlap.
```
