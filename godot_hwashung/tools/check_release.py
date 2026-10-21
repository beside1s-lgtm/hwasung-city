# -*- coding: utf-8 -*-
"""배포(설치 파일) 만들기 전 점검: 저장 데이터(실록)가 배포물에 섞여 들어가지 않는지 확인한다.

약속 (docs/SAVE_DATA_AND_RELEASE.md)
  - 게임 저장은 user://(= %APPDATA%\\Godot\\app_userdata\\화성성역- 정조의 24년 (Hwashung City Tycoon)\\)에만 한다.
    saves\\slot_1.json · slot_2.json · slot_3.json · autosave.json, encyclopedia_puzzle.save, settings.cfg
  - 프로젝트 폴더(res://)에는 저장 파일을 두지 않는다.
  - export_presets.cfg 의 exclude_filter 가 저장 파일 이름을 뺀다.
  - 설치 스크립트(.iss) [Files]에는 실행 파일·pck·아이콘만 넣는다.

쓰는 법:  python tools/check_release.py      (godot_hwashung 폴더에서)
"""
import fnmatch
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)            # godot_hwashung
ROOT = os.path.dirname(PROJ)            # hwashung city
SAVE_PATTERNS = ["slot_*.json", "autosave.json", "*.save", "settings.cfg"]
NEED_EXCLUDE = ["saves/*", "slot_*.json", "autosave.json", "*.save", "settings.cfg"]
BUILD_DIRS = [os.path.join(ROOT, "release_build"), os.path.join(ROOT, "build", "windows")]
ISS_FILES = [os.path.join(ROOT, "installer", "hwashung_installer.iss"), os.path.join(ROOT, "installer.iss")]

problems = []

# 1) 프로젝트 폴더 안 저장 파일
for dp, dns, fns in os.walk(PROJ):
    dns[:] = [d for d in dns if d not in (".godot", "art_inbox", "node_modules")]
    rel = os.path.relpath(dp, PROJ)
    if rel.split(os.sep)[0] == "saves":
        problems.append("프로젝트 안에 saves 폴더가 있음: " + dp)
    for fn in fns:
        if any(fnmatch.fnmatch(fn, p) for p in SAVE_PATTERNS):
            problems.append("프로젝트 안 저장 파일: " + os.path.join(dp, fn))

# 2) 내보내기 제외 규칙
ep = os.path.join(PROJ, "export_presets.cfg")
txt = open(ep, encoding="utf-8").read()
for m in re.finditer(r'^name="([^"]+)"[\s\S]*?^exclude_filter="([^"]*)"', txt, re.M):
    name, ex = m.group(1), m.group(2)
    for need in NEED_EXCLUDE:
        if need not in ex:
            problems.append("export_presets '%s' exclude_filter에 '%s' 없음" % (name, need))

# 3) 빌드 폴더에 저장 파일
for bd in BUILD_DIRS:
    if not os.path.isdir(bd):
        continue
    for dp, _dns, fns in os.walk(bd):
        for fn in fns:
            if any(fnmatch.fnmatch(fn, p) for p in SAVE_PATTERNS) or fn.endswith(".json"):
                problems.append("빌드 폴더에 저장류 파일: " + os.path.join(dp, fn))

# 4) 설치 스크립트가 사용자 저장 폴더를 넣지 않는가
for iss in ISS_FILES:
    if not os.path.exists(iss):
        continue
    body = open(iss, encoding="utf-8-sig").read()
    files_sec = re.search(r"^\[Files\]([\s\S]*?)(^\[|\Z)", body, re.M)
    sec = files_sec.group(1) if files_sec else ""
    for line in sec.splitlines():
        l = line.strip()
        if not l or l.startswith(";"):
            continue
        low = l.lower()
        if "app_userdata" in low or "appdata" in low or "saves" in low or ".save" in low or "slot_" in low:
            problems.append("%s [Files]에 저장 데이터가 들어감: %s" % (os.path.basename(iss), l))

if problems:
    print("점검 실패 — 고친 뒤 설치 파일을 만드세요:")
    for p in problems:
        print("  ✗ " + p)
    sys.exit(1)
print("점검 통과: 배포물에 저장 데이터(실록)가 들어가지 않습니다. (새로 설치하면 실록 0권부터)")
