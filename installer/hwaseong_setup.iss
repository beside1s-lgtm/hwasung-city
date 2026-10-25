; 화성성역 Windows 설치 파일 스크립트 (Inno Setup 6)
;
; 만드는 법:
;   1. Godot에서 Windows Desktop을 "출시"로 내보내 ..\build 에 exe와 pck를 만든다.
;   2. 이 파일을 Inno Setup으로 열고 Compile(또는 명령줄: ISCC.exe hwaseong_setup.iss).
;   3. ..\dist_installer 에 설치 파일이 생긴다.
; 새 버전을 낼 때는 아래 MyAppVersion만 올리면 된다. AppId는 절대 바꾸지 않는다(바꾸면 다른 프로그램으로 취급되어 업데이트가 안 된다).

#define MyAppName "화성성역: 정조의 신도시 시뮬레이션"
#define MyAppShortName "화성성역"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "KIS Wallaby"
#define MyAppExeName "Hwaseong Seongyeok.exe"
#define MyAppPckName "Hwaseong Seongyeok.pck"
#define BuildDir "..\build"

[Setup]
AppId={{509532D8-335C-4E6B-84B5-1FFDFDBF0C49}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (c) 2026 KIS Kang Jiwook
DefaultDirName={autopf}\{#MyAppShortName}
DefaultGroupName={#MyAppShortName}
DisableProgramGroupPage=yes
; 관리자 권한 없이도 "나만 설치"를 고를 수 있게 한다
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\godot_hwashung\assets\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
OutputDir=..\dist_installer
OutputBaseFilename=HwaseongSeongyeok_Setup_{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; exe와 pck는 항상 같은 폴더에 있어야 게임이 실행된다
Source: "{#BuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\{#MyAppPckName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\godot_hwashung\assets\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#MyAppShortName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\app_icon.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppShortName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
