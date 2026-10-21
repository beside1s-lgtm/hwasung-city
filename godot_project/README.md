# 화성성역: 정조의 24년 (Godot 4 2.5D Isometric 에디션)

본 디렉토리는 《화성성역: 정조의 24년》을 Godot 4 2D 전용 상용 모바일 게임으로 빌드하기 위한 프로젝트 구조입니다.

## 1. 프로젝트 개요
* 엔진 버전: Godot Engine 4.2+ (Mobile/Forward Plus)
* 뷰포트 해상도: 1280x720 (CanvasItems 가로 모드 / 1080x1920 세로 모드 전환 가능)
* 타일 규격: 64x32 아이소메트릭 다이아몬드 타일 (Isometric 2:1 투영)

## 2. 권장 노드 계층 구조 (scenes/Main.tscn)
```
Main (Node2D)
├── Camera2D (줌, 휠 드래그 패닝, 터치 핀치 줌 스크립트 연결)
├── WorldMap (TileMap)
│   ├── Layer 0: Ground (지형 타일 - 평지, 수원천 물길)
│   ├── Layer 1: Cliffs (3D 단면 절벽 Y-sort)
│   ├── Layer 2: Structures (성벽, 홍예문, 초가, 기와집 Y-sort)
│   └── Layer 3: AmbientCrowd (보부상, 장용영 순찰병 도트 애니메이션)
├── WeatherParticles (GPUParticles2D - 벚꽃, 햇살, 낙엽, 함박눈)
└── CanvasLayer (모바일 HUD & 팝업 UI)
    ├── HeaderHUD (자원, 턴, 충성도)
    ├── QuestBanner (어명 교지)
    ├── ThumbDock (하단 엄지 조작 버튼)
    └── ModalScroll (상소문 및 조정 인사 다이얼로그)
```

## 3. 에셋 매핑 가이드
`src/render/PixelArtSheets.ts`에서 프로그래머틱으로 생성한 고도화 픽셀 에셋(절벽, 기와, 초가, 성곽, 홍예문, 보부상, 장용영 병사)을 Godot의 `TileSet` 아틀라스 텍스처로 바로 임포트하여 사용할 수 있습니다.
