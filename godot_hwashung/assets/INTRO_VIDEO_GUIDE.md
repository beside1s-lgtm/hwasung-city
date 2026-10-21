# 화성성역 인트로 시네마틱 영상 교체 가이드

본 문서는 《화성성역 1794: 정조의 24년》의 인트로 오프닝 영상 파일을 새로운 영상으로 교체하거나 인코딩하는 절차와 기술 규격을 안내합니다.

---

## 1. 파일 저장 경로 및 파일명 규격

* **게임 엔진 로드 파일 경로**: `godot_hwashung/assets/intro_video.ogv`
* **원본 영상 백업 경로**: `godot_hwashung/assets/화성성역 인트로.mp4`
* **엔진 로더 클래스**: `VideoStreamTheora` (`IntroVideoLayer.gd`)

---

## 2. 권장 비디오/오디오 코덱 규격

Godot 4 엔진 및 Web(WASM/HTML5) 플랫폼은 H.264(MP4) 상용 특허 라이선스 제한 없이 크로스 플랫폼에서 안정적으로 구동하기 위해 오픈 포맷인 **Ogg Theora (.ogv)** 포맷을 표준 스트리밍 비디오로 지원합니다.

| 구분 | 권장 규격 | 설명 |
| :--- | :--- | :--- |
| **컨테이너 포맷** | Ogg (`.ogv`) | Godot 4 `VideoStreamTheora` 네이티브 지원 |
| **비디오 코덱** | Theora (`libtheora`) | 무특허 오픈소스 비디오 코덱 |
| **오디오 코덱** | Vorbis (`libvorbis`) | 44.1kHz 스테레오 오디오 |
| **해상도** | 1920 × 1080 (FHD) 또는 1280 × 720 (HD) | 16:9 와이드 화면 비율 고정 |
| **프레임레이트** | 30 fps 또는 24 fps (Cinematic) | 브라우저 및 저사양 PC 재생 최적화 |
| **비트레이트** | 가변 비트레이트 (VBR, Quality 7~8) | 용량과 화질의 최적 밸런스 유지 |

---

## 3. FFmpeg를 활용한 영상 변환 명령어

새로운 MP4, MOV, MKV 등의 영상을 보유하고 계신 경우, 터미널(PowerShell 또는 CMD)에서 무료 도구인 FFmpeg를 사용하여 즉시 Godot 최적화 `.ogv` 규격으로 변환할 수 있습니다.

### 기본 권장 변환 명령어 (1080p FHD)
```powershell
ffmpeg -i "새로운영상.mp4" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 -y "c:\myapp\hwashung city\godot_hwashung\assets\intro_video.ogv"
```

### 웹 로딩 속도 최적화 변환 (720p HD)
웹 브라우저 환경에서 초기 로딩 지연을 최소화하려면 720p 해상도로 스케일링하는 것을 권장합니다.
```powershell
ffmpeg -i "새로운영상.mp4" -vf "scale=1280:720" -c:v libtheora -q:v 6 -c:a libvorbis -q:a 4 -y "c:\myapp\hwashung city\godot_hwashung\assets\intro_video.ogv"
```

---

## 4. 영상 교체 단계별 절차

1. **새로운 영상 파일 준비**: 교체할 영상을 준비합니다 (예: `new_intro.mp4`).
2. **OGV 포맷 변환**: 상기 FFmpeg 명령어를 실행하여 `godot_hwashung/assets/intro_video.ogv` 위치에 덮어씁니다.
3. **확인 및 검증**:
   - 데스크톱 실행: Godot 실행 시 오프닝 인트로가 새 영상으로 재생되는지 확인.
   - 웹 배포: 프로젝트 루트에서 `dist_godot` 빌드 스크립트를 재실행하여 웹 번들에 패킹.
4. **트랜지션 동작**:
   - 영상 종료 시 마지막 프레임이 일시정지 상태로 고정되며, 0.8초 크로스페이드 트윈을 통해 배경의 타이틀 화면(`TitleScreenLayer`)으로 매끄럽게 연결됩니다.
   - 재생 중 `ESC`, `Space`, `Enter` 또는 마우스 클릭 시 건너뛰기가 즉각 작동합니다.
