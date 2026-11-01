# =====================================================================
#  Membangun aplikasi Windows lalu mengemasnya jadi installer.
#
#  Jalankan dari akar repo:
#    powershell -ExecutionPolicy Bypass -File installer\build.ps1
#
#  Dibuat setelah satu installer sempat terkirim tanpa kredensial di
#  dalamnya: perintah build-nya diketik ulang dari ingatan dan
#  --dart-define-from-file kelewat, sehingga aplikasinya terpasang lalu
#  membuka layar "Kredensial Supabase belum diisi". Perintahnya sekarang
#  tinggal di satu tempat supaya tidak ada lagi yang mengetiknya ulang.
#  Tambahkan -Android untuk sekalian membangun APK:
#    powershell -ExecutionPolicy Bypass -File installer\build.ps1 -Android
# =====================================================================

param([switch]$Android)

$ErrorActionPreference = 'Stop'

$akar = Split-Path -Parent $PSScriptRoot
$app  = Join-Path $akar 'app'
$env_ = Join-Path $app 'env.json'

if (-not (Test-Path $env_)) {
  throw "env.json tidak ada di $app. Lihat README untuk isinya."
}

Write-Host '== Uji dulu ==' -ForegroundColor Cyan
Push-Location $app
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze gagal.' }

  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test gagal.' }

  Write-Host '== Build release ==' -ForegroundColor Cyan
  flutter build windows --release --dart-define-from-file=env.json
  if ($LASTEXITCODE -ne 0) { throw 'flutter build gagal.' }

  if ($Android) {
    Write-Host '== Build APK ==' -ForegroundColor Cyan
    flutter build apk --release --dart-define-from-file=env.json
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk gagal.' }
  }
}
finally { Pop-Location }

# Memastikan kredensialnya benar-benar ikut tertanam. Alamat proyek
# dibaca dari env.json, bukan ditulis di sini -- berkas ini masuk git,
# env.json tidak.
$ref = ([regex]'https://([a-z0-9]+)\.supabase\.co').Match(
  (Get-Content $env_ -Raw)).Groups[1].Value
if (-not $ref) { throw 'Alamat Supabase tidak terbaca dari env.json.' }

$so = Join-Path $app 'build\windows\x64\runner\Release\data\app.so'
if (-not (Select-String -Path $so -Pattern $ref -SimpleMatch -Quiet)) {
  throw 'Kredensial tidak tertanam di hasil build. Build dihentikan.'
}
Write-Host 'Kredensial tertanam (Windows).' -ForegroundColor Green

if ($Android) {
  # Kode Dart di APK terletak di lib/<abi>/libapp.so, di dalam zip. Satu
  # ABI cukup diperiksa: ketiganya dibangun dari sumber yang sama.
  $apk = Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk'
  if (-not (Test-Path $apk)) { throw "APK tidak ada di $apk" }

  $keluar = Join-Path ([IO.Path]::GetTempPath()) "apkcek-$(Get-Random)"
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($apk)
    try {
      $isi = $zip.GetEntry('lib/arm64-v8a/libapp.so')
      if (-not $isi) { throw 'libapp.so arm64-v8a tidak ada di dalam APK.' }
      New-Item -ItemType Directory -Force $keluar | Out-Null
      $tujuan = Join-Path $keluar 'libapp.so'
      [IO.Compression.ZipFileExtensions]::ExtractToFile($isi, $tujuan)
    }
    finally { $zip.Dispose() }

    if (-not (Select-String -Path $tujuan -Pattern $ref -SimpleMatch -Quiet)) {
      throw 'Kredensial tidak tertanam di APK. Build dihentikan.'
    }
    Write-Host 'Kredensial tertanam (Android).' -ForegroundColor Green
    Write-Host "APK: $apk" -ForegroundColor Green
  }
  finally {
    if (Test-Path $keluar) { Remove-Item -Recurse -Force $keluar }
  }
}

Write-Host '== Kemas installer ==' -ForegroundColor Cyan
# Winget memasangnya per pengguna; pemasang biasa ke Program Files.
$iscc = @(
  'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
  (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 tidak ditemukan.' }

& $iscc (Join-Path $PSScriptRoot 'setup.iss')
if ($LASTEXITCODE -ne 0) { throw 'ISCC gagal.' }

Write-Host 'Selesai. Hasilnya di installer\output\.' -ForegroundColor Green
