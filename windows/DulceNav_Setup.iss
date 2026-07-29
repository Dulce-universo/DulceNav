; ==============================================================
; DulceNav — Inno Setup Script
; Script de compilación para instalador ejecutable profesional.
; ==============================================================

[Setup]
AppId={{5E6F892A-4B6C-4D2F-9A8E-1C2B3A4B5C6D}
AppName=DulceNav
AppVersion=1.8.1
AppPublisher=Dulce Universe
AppPublisherURL=https://dulceapps.lovable.app
AppSupportURL=https://dulceapps.lovable.app
AppUpdatesURL=https://dulceapps.lovable.app
DefaultDirName={autopf}\DulceNav
DisableProgramGroupPage=yes
LicenseFile=installer_resources\license.txt
InfoBeforeFile=installer_resources\about.txt
OutputDir=..\build\windows\installer
OutputBaseFilename=DulceNav_v1.8.1_Setup
SetupIconFile=..\assets\icons\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DefaultGroupName=DulceNav
UninstallDisplayIcon={app}\dulcenav.exe
VersionInfoVersion=1.8.1.0
VersionInfoCompany=Dulce Universe
VersionInfoDescription=DulceNav Installer
VersionInfoCopyright=Copyright (C) 2026 Dulce Universe
UsePreviousAppDir=yes
CloseApplications=yes
DirExistsWarning=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\dulcenav.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\DulceNav"; Filename: "{app}\dulcenav.exe"
Name: "{autodesktop}\DulceNav"; Filename: "{app}\dulcenav.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\dulcenav.exe"; Description: "{cm:LaunchProgram,DulceNav}"; Flags: nowait postinstall skipifsilent
