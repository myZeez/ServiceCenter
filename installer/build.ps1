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
# =====================================================================

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
Write-Host 'Kredensial tertanam.' -ForegroundColor Green

Write-Host '== Kemas installer ==' -ForegroundColor Cyan
$iscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) { throw "Inno Setup tidak ada di $iscc" }

& $iscc (Join-Path $PSScriptRoot 'setup.iss')
if ($LASTEXITCODE -ne 0) { throw 'ISCC gagal.' }

Write-Host 'Selesai. Hasilnya di installer\output\.' -ForegroundColor Green
