; Script generated for Hwashung City Tycoon
; Inno Setup 6 Script

#define MyAppName "화성성역 - 정조의 24년"
#define MyAppEnglishName "Hwashung City Tycoon"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Hwashung City"
#define MyAppExeName "HwashungCity.exe"

[Setup]
AppId={{8B8497C1-872A-4F71-B5F7-1C05252873E4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\HwashungCity
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=c:\myapp\hwashung city\dist_installer
OutputBaseFilename=HwashungCity_Setup_v1.0.0
SetupIconFile=c:\myapp\hwashung city\release_build\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "c:\myapp\hwashung city\release_build\HwashungCity.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\myapp\hwashung city\release_build\HwashungCity.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\myapp\hwashung city\release_build\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
