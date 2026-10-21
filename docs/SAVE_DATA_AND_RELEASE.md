# 저장 데이터 위치와 배포(설치 파일) 약속

## 1. 게임 데이터가 저장되는 곳

게임은 실행 파일 폴더가 아니라 **사용자 폴더**(Godot의 `user://`)에만 저장합니다.

```
%APPDATA%\Godot\app_userdata\화성성역- 정조의 24년 (Hwashung City Tycoon)\
    saves\slot_1.json      실록 제1권
    saves\slot_2.json      실록 제2권
    saves\slot_3.json      실록 제3권
    saves\autosave.json    실록 제0권(자동 저장)
    encyclopedia_puzzle.save   도감·퍼즐 진행
    settings.cfg               설정
```

- 코드상 위치: `scripts/SaveSystem.gd`의 `SAVE_DIR = "user://saves/"`.
- 폴더 이름은 `project.godot`의 `config/name`에서 나옵니다(`:`는 `-`로 바뀜). 이름을 바꾸면 저장 폴더도 바뀌니, 바꾸지 마세요.

## 2. 배포 약속

1. 프로젝트 폴더(`godot_hwashung`, 곧 `res://`)에는 저장 파일을 두지 않습니다.
2. `export_presets.cfg`의 `exclude_filter`가 저장 파일 이름(`saves/*`, `slot_*.json`, `autosave.json`, `*.save`, `settings.cfg`)과 `art_inbox/*`를 뺍니다.
3. 설치 스크립트(`installer/hwashung_installer.iss`, `installer.iss`)의 `[Files]`에는 실행 파일, pck, 아이콘만 넣습니다. 사용자 저장 폴더는 넣지 않습니다.
4. 설치 파일을 만들기 전에 아래 점검을 돌려 통과를 확인합니다.

```bash
python tools/check_release.py
```

## 3. 알아 둘 것

- 새로 설치한 컴퓨터에서는 저장된 실록이 0권부터 시작합니다.
- **개발하던 이 컴퓨터**에서 설치본을 실행하면, 사용자 폴더에 남은 기존 실록이 그대로 보입니다. 설치 파일에 들어간 것은 아닙니다.
  - 빈 상태로 시험하려면 위 사용자 폴더의 이름을 잠시 바꿔 두고 실행한 뒤, 다시 원래 이름으로 되돌리세요.
- 제거 프로그램은 사용자 폴더의 실록을 지우지 않습니다. 다시 설치해도 이어서 할 수 있게 하려는 것입니다.
