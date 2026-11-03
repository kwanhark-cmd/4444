; 윈도우 설치 파일 (Inno Setup). 앱 파일만 바꾸고 자료(%APPDATA%)는 건드리지 않습니다.
#define AppName "비우기 비서"
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif

[Setup]
; AppId는 절대 바꾸지 마세요 (바꾸면 덮어쓰기 대신 새 앱으로 설치됨)
AppId={{6F1C2B8E-3F7A-4C1D-9B2E-5A8D7C6E4F31}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Binugi
DefaultDirName={localappdata}\Programs\Binugi
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=binugi-windows-setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=yes
WizardStyle=modern
UninstallDisplayIcon={app}\binugi.exe

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 바로가기 만들기"; GroupDescription: "바로가기:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\binugi.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\binugi.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\binugi.exe"; Description: "{#AppName} 실행"; Flags: nowait postinstall skipifsilent
