# 프로덕션 웹 빌드 — 프로젝트 루트에서: .\build_web.ps1
# run_web.ps1 과 동일하게 dart-define 파일을 합칩니다 (빌드에 박힐 값).
# 결과물: build/web/
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path "env.worker")) {
    Write-Host "env.worker 파일이 없습니다." -ForegroundColor Yellow
    exit 1
}
$defineArgs = @("--dart-define-from-file=env.worker")
if (Test-Path "env.tour") {
    $defineArgs += "--dart-define-from-file=env.tour"
}
if (Test-Path "env.kakao") {
    $defineArgs += "--dart-define-from-file=env.kakao"
}
flutter build web @defineArgs
