# 12대 멀티 엔딩 시네마틱 영상 배치 및 인코딩 가이드

본 문서는 《화성성역 1794: 정조의 24년》의 **12대 멀티 엔딩별 시네마틱 영상**을 게임에 적용하는 방법과 규격을 안내합니다.

---

## 1. 영상 저장 경로

영상 파일은 프로젝트의 `godot_hwashung/assets/endings/` 폴더에 위치합니다.

---

## 2. 12대 엔딩별 권장 파일명

엔딩별로 아래 표의 파일명 중 편한 방식으로 저장하시면 시스템이 자동으로 인식합니다:
(ID 기반 이름, 번호 기반 이름 모두 지원됩니다)

| 번호 | 엔딩 명칭 | ID (엔딩 코드) | 권장 파일명 (ID 기반) | 대체 파일명 (번호 기반) |
| :---: | :--- | :--- | :--- | :--- |
| **1** | 서학의 난 (무너진 사직) | `WESTERN_COLLAPSE` | `ending_western_collapse.ogv` | `ending_1.ogv` |
| **2** | 불효의 저주 (종묘사직의 진노) | `UNFILIAL_CURSE` | `ending_unfilial_curse.ogv` | `ending_2.ogv` |
| **3** | 피폐한 빈국 (재정 파탄) | `BANKRUPT_RUIN` | `ending_bankrupt_ruin.ogv` | `ending_3.ogv` |
| **4** | 사대부의 반정 (왕권 실추) | `COUP_DETAT` | `ending_coup_detat.ogv` | `ending_4.ogv` |
| **5** | 민초의 거대한 봉기 (민중 혁명) | `PEASANT_REVOLT` | `ending_peasant_revolt.ogv` | `ending_5.ogv` |
| **6** | 함락된 신도시 (국방 붕괴) | `FALLEN_CITY` | `ending_fallen_city.ogv` | `ending_6.ogv` |
| **7** | 약탈당한 풍요 (수탈 엔딩) | `PLUNDERED_WEALTH` | `ending_plundered_wealth.ogv` | `ending_7.ogv` |
| **8** | 피바람의 당쟁 (신사화) | `BLOODY_FACTION` | `ending_bloody_faction.ogv` | `ending_8.ogv` |
| **9** | 세도정치의 암운 (외척 발호) | `SEDO_DARKNESS` | `ending_sedo_darkness.ogv` | `ending_9.ogv` |
| **10** | 무지의 늪 (후진국화의 길) | `IGNORANCE_SWAMP` | `ending_ignorance_swamp.ogv` | `ending_10.ogv` |
| **11** | 미완의 개혁과 수호의 요새 | `DEFENSE_FORTRESS` | `ending_defense_fortress.ogv` | `ending_11.ogv` |
| **12** | 대조선 르네상스 [진 엔딩] | `TRUE_RENAISSANCE` | `ending_true_renaissance.ogv` | `ending_12.ogv` |
| **13** | 도적 떼의 행궁 함락 (중도 비극) | `BANDIT_FALL` | `ending_bandit_fall.ogv` | `ending_13.ogv` |

> **안전장치 (Fail-Safe)**:
> - 특정 엔딩 영상 파일이 아직 준비되지 않은 경우, 게임이 멈추지 않고 즉시 기존 실록 결산 팝업으로 안전하게 넘어갑니다.
> - 공통 대표 영상으로 `ending_default.ogv` 또는 `ending_video.ogv`를 두면 미준비 엔딩에 자동으로 대체 재생됩니다.
> - **13번 도적 함락 엔딩**은 1800년 이전 플레이 도중 방호력이 소진된 상태에서 도적 무리가 행궁 본궁에 도달했을 때 실시간으로 발화되는 중도 게임 오버 엔딩입니다.

---

## 3. MP4 -> OGV 변환 명령어 (FFmpeg)

보유하신 영상이 MP4 포맷인 경우 아래 명령어를 사용하여 변환할 수 있습니다:

### 단일 파일 변환 예시
```powershell
ffmpeg -i "서학의난.mp4" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 -y "godot_hwashung\assets\endings\ending_western_collapse.ogv"
```

### 13개 영상 일괄 변환 (PowerShell 스크립트 예시)
보유하신 13개 영상이 `1.mp4`, `2.mp4` ... `13.mp4` 형식으로 되어 있다면:
```powershell
1..13 | ForEach-Object {
    ffmpeg -i "$_.mp4" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 -y "godot_hwashung\assets\endings\ending_$_.ogv"
}
```

---

## 4. 인게임 동작

1. **엔딩 도달 (1800년 또는 함락/반정 발생)**:
   - 시뮬레이션 일시 정지 (`PAUSE`)
   - 해당 엔딩에 매핑된 영상 전체화면(16:9) 자동 재생
   - 초반 4초간 좌측 상단에 엔딩 타이틀 및 부제 뱃지 연출
   - `ESC`, `Space`, `Enter` 또는 마우스 좌클릭 시 건너뛰기 가능
2. **실록 결산 팝업 전환**:
   - 영상 종료(또는 스킵) 시 0.6초 페이드아웃 트윈 후 11개 지표 실록 결산 창 오픈
   - 팝업 하단에 `[시네마틱 다시보기 🎬]` 버튼이 생성되어 언제든 다시 감상 가능
