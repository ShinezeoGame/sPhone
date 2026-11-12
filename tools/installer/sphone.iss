; Installateur Windows de sPhone (Inno Setup 6).
;
; Compilé par .github/workflows/build-windows.yml une fois l'application assemblée dans
; build\windows\x64\runner\Release (avec le dossier scrcpy) :
;
;     ISCC.exe /DAppVersion=1.0.12 tools\installer\sphone.iss
;
; L'installation se fait dans le profil de l'utilisateur : aucun droit d'administrateur requis.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{7C0B4C4E-6A0B-4C55-9B4E-5F1D2A9E3B61}
AppName=sPhone
AppVersion={#AppVersion}
AppPublisher=ShinezeoGame
AppPublisherURL=https://github.com/ShinezeoGame/sPhone
DefaultDirName={autopf}\sPhone
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..
OutputBaseFilename=sphone-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\sphone.exe
UninstallDisplayName=sPhone
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Une mise à jour ferme sPhone (et son service adb) avant de remplacer les fichiers.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\sPhone"; Filename: "{app}\sphone.exe"
Name: "{autodesktop}\sPhone"; Filename: "{app}\sphone.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sphone.exe"; Description: "{cm:LaunchProgram,sPhone}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Le service adb peut encore tourner si sPhone a été arrêté de force : on le coupe pour
; que ses fichiers puissent être supprimés.
Filename: "{app}\scrcpy\adb.exe"; Parameters: "kill-server"; Flags: runhidden skipifdoesntexist; RunOnceId: "ArretAdb"
