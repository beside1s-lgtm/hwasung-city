; =========================================================================
; 수원화성: 정조의 신도시 시뮬레이션 - Windows 정식 설치 프로그램 인스톨러 스크립트
; Inno Setup 6.x 호환
; =========================================================================

#define MyAppName "수원화성 - 정조의 신도시 시뮬레이션"
#define MyAppShortName "수원화성"
#define MyAppEnglishName "HwashungCity"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "조선 시뮬레이션 스튜디오"
#define MyAppExeName "HwashungCity.exe"

[Setup]
; 고유 애플리케이션 GUID
AppId={{9B7322E1-6893-4B9A-A3E5-7B1A43258810}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppEnglishName}
DefaultGroupName={#MyAppShortName}
AllowNoIcons=yes
OutputDir=c:\myapp\hwashung city\release_build
OutputBaseFilename=HwashungCity_Setup_v1.0.0
SetupIconFile=c:\myapp\hwashung city\release_build\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion=1.0.0.0
VersionInfoCompany=조선 시뮬레이션 스튜디오
VersionInfoDescription=수원화성 - 정조의 신도시 시뮬레이션 설치 프로그램
VersionInfoProductName=수원화성
VersionInfoProductVersion=1.0.0.0

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

; -------------------------------------------------------------------------
; [배포 약속] 저장 데이터(실록)는 설치 파일에 넣지 않는다.
;  - 게임 저장 위치: %APPDATA%\Godot\app_userdata\화성성역- 정조의 24년 (Hwashung City Tycoon)\
;      saves\slot_1.json, slot_2.json, slot_3.json, autosave.json / encyclopedia_puzzle.save / settings.cfg
;  - 이 폴더는 게임 실행 파일·pck 밖(사용자 폴더)이라 [Files]에 넣지 않는다. 아래 [Files]에는 exe·pck·아이콘만.
;  - 내보내기 설정(export_presets.cfg exclude_filter)도 저장 파일 이름을 빼도록 되어 있다.
;  - 설치 파일을 만들기 전에 tools\check_release.py 를 돌려 확인한다(docs\SAVE_DATA_AND_RELEASE.md).
; -------------------------------------------------------------------------
[Files]
Source: "c:\myapp\hwashung city\release_build\HwashungCity.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\myapp\hwashung city\release_build\HwashungCity.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\myapp\hwashung city\release_build\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppShortName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\app_icon.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppShortName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
