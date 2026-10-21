; Inno Setup 6 Script for Suwon Hwaseong Strategy Game
; 수원화성: 정조의 신도시 시뮬레이션

#define MyAppName "수원화성 (Suwon Hwaseong Strategy)"
#define MyAppEnglishName "SuwonHwaseong"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "조선 시뮬레이션 스튜디오"
#define MyAppExeName "SuwonHwaseong.exe"

[Setup]
AppId={{A5F23D91-7C8B-4B2E-9F1A-SUWONHWA_SIM}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SuwonHwaseong
DefaultGroupName=수원화성
OutputDir=dist
OutputBaseFilename=SuwonHwaseong_Setup_v1.0
SetupIconFile=build\windows\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
DisableProgramGroupPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕화면에 바로가기 아이콘 생성"; GroupDescription: "추가 작업:"; Flags: checkedonce

; -------------------------------------------------------------------------
; [배포 약속] 저장 데이터(실록)는 설치 파일에 넣지 않는다.
;  - 게임 저장 위치: %APPDATA%\Godot\app_userdata\화성성역- 정조의 24년 (Hwashung City Tycoon)\
;      saves\slot_1.json, slot_2.json, slot_3.json, autosave.json / encyclopedia_puzzle.save / settings.cfg
;  - 이 폴더는 게임 실행 파일·pck 밖(사용자 폴더)이라 [Files]에 넣지 않는다. 아래 [Files]에는 exe·pck·아이콘만.
;  - 내보내기 설정(export_presets.cfg exclude_filter)도 저장 파일 이름을 빼도록 되어 있다.
;  - 설치 파일을 만들기 전에 tools\check_release.py 를 돌려 확인한다(docs\SAVE_DATA_AND_RELEASE.md).
; -------------------------------------------------------------------------
[Files]
Source: "build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\수원화성 실행"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\수원화성 삭제"; Filename: "{uninstallexe}"
Name: "{autodesktop}\수원화성"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "수원화성 지금 실행하기"; Flags: nowait postinstall skipifsilent
