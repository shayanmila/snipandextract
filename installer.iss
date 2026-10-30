#define MyAppName "Snip & Extract"
#define MyAppVersion "1.0.1"
#define MyAppExeName "snipandextract.exe"
[Setup]
AppId={{D5A6B631-4B5A-40E0-9B56-88A9EACB1A63}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=MasoomDev
DefaultDirName={autopf}\\SnipAndExtract
DefaultGroupName={#MyAppName}
OutputDir=installer-output
OutputBaseFilename=SnipAndExtract-Setup-Windows
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
LicenseFile=LICENSE.txt
SetupIconFile=windows\\runner\\resources\\app_icon.ico
UninstallDisplayIcon={app}\\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"
[Files]
Source: "build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch Snip & Extract"; Flags: nowait postinstall skipifsilent
