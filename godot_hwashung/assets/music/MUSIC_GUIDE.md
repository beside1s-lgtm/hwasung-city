# 배경음악 넣는 법

게임은 `assets/music/<곡이름>.ogg` 파일이 있으면 그 곡을, 없으면 코드로 합성한 **임시 곡**을 반복 재생합니다.
파일 하나를 넣는 순간 그 자리의 임시 곡이 진짜 곡으로 바뀝니다(코드 수정 불필요, 게임을 다시 켜면 적용).

- 형식: **OGG Vorbis 권장**(mp3·wav도 인식). 이어 붙여도 어색하지 않은 **반복(루프)용** 곡이면 좋습니다.
- 길이 1.5~3분, 음량은 너무 크지 않게(대략 -14 LUFS). 곡이 바뀔 때 2.2초 교차 페이드가 들어갑니다.
- 파일을 넣은 뒤 Godot 편집기를 한 번 열면 자동 가져오기(import)가 됩니다(내보내기 전에 필수).
- 설정 화면의 "배경음악 크기" 슬라이더로 크기를 조절하고, 소리 끄기는 기존 음소거 버튼이 같이 처리합니다.

## 언제 어떤 곡이 나오나 (위에 있을수록 우선)

| 상황 | 곡 이름 |
|---|---|
| 엔딩 팝업이 뜰 때 | `ending_<엔딩ID>` (아래 13곡). 엔딩 영상이 도는 동안은 배경음악이 꺼집니다 |
| 타이틀 화면(인트로 영상이 끝난 뒤) | `main_theme` |
| 반란·외침으로 성을 공격해 올 때 | `event_rebel` / `event_invasion` |
| 도적 침입·교전 | `event_bandit` |
| 화재 | `event_fire` |
| 수해 위기(홍수) | `event_flood` |
| 을묘원행(1795) | `event_eulmyo` |
| 역병 | `event_plague` |
| 흉년(가뭄 또는 쌀 0) | `event_famine` |
| 평상시 | `season_spring` · `season_summer` · `season_autumn` · `season_winter` (계절이 바뀌면 곡도 바뀜) |

위험한 상황이 닥치면 곧바로 그 곡으로 넘어가고, 평상시로 돌아올 때는 한 곡을 최소 18초는 듣도록 늦춰서 곡이 깜빡이지 않게 했습니다.

## 곡 목록 (총 26곡)

| 파일 이름 | 이름 | 임시 곡 템포 |
|---|---|---|
| `main_theme.ogg` | 메인 테마 — 화성의 아침 | 66 | 
| `season_spring.ogg` | 봄 — 꽃이 피는 성 | 84 | 
| `season_summer.ogg` | 여름 — 푸른 둔전 | 76 | 
| `season_autumn.ogg` | 가을 — 황금 들녘 | 70 | 
| `season_winter.ogg` | 겨울 — 눈 덮인 성곽 | 54 | 
| `event_famine.ogg` | 흉년 — 빈 곳간 | 50 | 
| `event_flood.ogg` | 홍수 — 불어난 물 | 108 | 
| `event_fire.ogg` | 화재 — 번지는 불길 | 120 | 
| `event_bandit.ogg` | 도적 — 어둠 속의 그림자 | 100 | 
| `event_rebel.ogg` | 반란 — 성문 앞의 함성 | 92 | 
| `event_invasion.ogg` | 외침 — 몰려오는 군세 | 96 | 
| `event_eulmyo.ogg` | 을묘원행 — 봉수당 진찬연 | 80 | 
| `event_plague.ogg` | 역병 — 닫힌 문 | 46 | 
| `ending_western_collapse.ogg` | 엔딩 — 서쪽 성벽의 붕괴 | 52 | 
| `ending_unfilial_curse.ogg` | 엔딩 — 불효의 저주 | 48 | 
| `ending_bankrupt_ruin.ogg` | 엔딩 — 텅 빈 국고 | 56 | 
| `ending_coup_detat.ogg` | 엔딩 — 한밤의 정변 | 88 | 
| `ending_peasant_revolt.ogg` | 엔딩 — 들불처럼 번진 민란 | 94 | 
| `ending_fallen_city.ogg` | 엔딩 — 함락된 신도시 | 50 | 
| `ending_plundered_wealth.ogg` | 엔딩 — 약탈당한 곳간 | 58 | 
| `ending_bloody_faction.ogg` | 엔딩 — 피로 물든 붕당 | 72 | 
| `ending_sedo_darkness.ogg` | 엔딩 — 세도의 어둠 | 52 | 
| `ending_ignorance_swamp.ogg` | 엔딩 — 무지의 늪 | 54 | 
| `ending_defense_fortress.ogg` | 엔딩 — 수호의 성 | 68 | 
| `ending_true_renaissance.ogg` | 엔딩 — 대조선의 르네상스 | 84 |
| `ending_bandit_fall.ogg` | 엔딩 — 도적에게 넘어간 화성 | 60 | 

## 곡 만들 때 참고 (AI 음악 도구에 넣을 만한 설명)

공통: 조선 후기 궁중·민속 국악 느낌, 가야금·대금·해금·장구·북 중심, 보컬 없음, 반복해도 질리지 않는 잔잔한 구성.

- 메인 테마: 웅장하고 차분한 대금 선율과 가야금 아르페지오, 새로 짓는 도시의 희망, 느린 템포
- 봄/여름/가을/겨울: 계절감(봄=경쾌한 가야금, 여름=푸르고 느긋, 가을=풍성한 해금, 겨울=고요하고 성긴 음)
- 흉년·역병: 낮은 지속음과 성긴 해금, 쓸쓸하고 무거운 분위기
- 홍수·화재: 빠른 장구/북, 몰아치는 가야금 트레몰로, 긴박
- 도적·반란·외침: 낮은 북 위에 긴장되는 선율, 점점 고조
- 을묘원행: 화려하고 경사스러운 궁중 연회 음악(진찬연), 밝고 장중
- 엔딩: 비극 엔딩은 느리고 처연하게(계면조), 수호 엔딩은 담담하고 희망적으로, 대조선의 르네상스는 웅장하고 환하게 마무리
