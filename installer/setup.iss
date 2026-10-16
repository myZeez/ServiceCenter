; =====================================================================
;  Installer Service Center
;
;  Dibangun dengan Inno Setup 6. Menghasilkan satu berkas exe yang bisa
;  dijalankan di PC mana pun tanpa perlu Flutter atau alat lain.
;
;  Cara membuat:
;    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup.iss
;
;  Jalankan "flutter build windows --release" lebih dulu.
; =====================================================================

#define NamaApp        "Service Center"
#define Versi          "2.35.23"
#define Penerbit       "Cellcom PLK"
#define NamaExe        "sc_management.exe"
#define SumberRelease  "..\app\build\windows\x64\runner\Release"
#define SumberCrt      "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT"

[Setup]
AppId={{7E3A1C42-9B5D-4F18-A6C7-2D8E5F0B4A91}
AppName={#NamaApp}
AppVersion={#Versi}
AppVerName={#NamaApp} {#Versi}
AppPublisher={#Penerbit}
DefaultDirName={autopf}\{#NamaApp}
DefaultGroupName={#NamaApp}
UninstallDisplayName={#NamaApp}
UninstallDisplayIcon={app}\{#NamaExe}
OutputDir=output
OutputBaseFilename=ServiceCenter-Setup-{#Versi}
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Dipasang per pengguna, bukan ke Program Files. Tidak memunculkan
; permintaan hak administrator, sehingga bisa dipasang di PC kantor yang
; akunnya bukan administrator.
PrivilegesRequired=lowest

[Languages]
Name: "id"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat pintasan di desktop"; \
  GroupDescription: "Pintasan:"

[Files]
; Seluruh hasil build Flutter, termasuk folder data.
Source: "{#SumberRelease}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; Runtime Visual C++ ditaruh bersebelahan dengan exe. Tanpa ini, aplikasi
; gagal terbuka di PC yang belum pernah dipasangi redistributable-nya --
; dan pesannya berupa kotak galat DLL yang tidak menjelaskan apa pun.
Source: "{#SumberCrt}\msvcp140.dll";      DestDir: "{app}"; Flags: ignoreversion
Source: "{#SumberCrt}\msvcp140_1.dll";    DestDir: "{app}"; Flags: ignoreversion
Source: "{#SumberCrt}\msvcp140_2.dll";    DestDir: "{app}"; Flags: ignoreversion
Source: "{#SumberCrt}\vcruntime140.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SumberCrt}\vcruntime140_1.dll";DestDir: "{app}"; Flags: ignoreversion
Source: "{#SumberCrt}\concrt140.dll";     DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#NamaApp}"; Filename: "{app}\{#NamaExe}"
Name: "{group}\Hapus {#NamaApp}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#NamaApp}"; Filename: "{app}\{#NamaExe}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#NamaExe}"; \
  Description: "Jalankan {#NamaApp} sekarang"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Basis data lokal disimpan di Documents dan sengaja TIDAK dihapus:
; di dalamnya bisa ada klaim yang belum sempat terkirim ke server.
Type: filesandordirs; Name: "{app}\data"

