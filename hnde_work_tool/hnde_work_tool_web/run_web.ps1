# 프로젝트 루트: .\run_web.ps1
# env.worker 에 R2_WORKER_URL_PROD 만 채우면 됨 (디버그도 배포 Worker)
# env.tour 에 TOUR_API_SERVICE_KEY (문화의 날 TourAPI) — 있으면 함께 주입
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path "env.worker")) {
    Write-Host "env.worker 파일이 없습니다." -ForegroundColor Yellow
    Write-Host "  env.worker.example 을 복사해 env.worker 로 저장한 뒤"
    Write-Host "  R2_WORKER_URL_PROD 를 채우세요."
    exit 1
}
$defineArgs = @("--dart-define-from-file=env.worker")
if (Test-Path "env.tour") {
    $defineArgs += "--dart-define-from-file=env.tour"
} else {
    Write-Host "env.tour 없음 — TourAPI(문화의 날) 키는 env.tour.example 을 env.tour 로 복사해 넣으세요." -ForegroundColor DarkGray
}
if (Test-Path "env.kakao") {
    $defineArgs += "--dart-define-from-file=env.kakao"
} else {
    Write-Host "env.kakao 없음 — 사업소 주소 검색(카카오)은 env.kakao.example 을 참고하세요." -ForegroundColor DarkGray
}
flutter run -d chrome @defineArgs
