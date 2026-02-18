@echo off
REM hnde_home_admin Firebase 호스팅 배포 스크립트 (Windows, PROD)

chcp 65001 >nul
setlocal

REM Flutter/Firebase CLI 존재 확인
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ flutter 명령을 찾을 수 없습니다.
    echo    - Flutter SDK의 bin 경로를 PATH에 추가하거나,
    echo    - Flutter가 인식되는 터미널에서 실행하세요.
    exit /b 1
)

where firebase >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ firebase 명령을 찾을 수 없습니다.
    echo    - npm i -g firebase-tools 후 다시 시도하세요.
    exit /b 1
)

echo 🚀 hnde_home_admin PROD 배포 시작...

REM Flutter 웹 빌드 (PROD Firebase)
echo 📦 Flutter 웹 빌드 중 (FIREBASE_ENV=prod)...
flutter build web --release --dart-define=FIREBASE_ENV=prod

if %errorlevel% neq 0 (
    echo ❌ 빌드 실패
    exit /b 1
)

REM Firebase 배포 (PROD 프로젝트)
echo 🔥 Firebase 호스팅 배포 중 (prod, target=admin)...
firebase deploy --project hnde-homepage-prod --only hosting:admin

if %errorlevel% equ 0 (
    echo ✅ PROD 배포 완료!
) else (
    echo ❌ PROD 배포 실패
    exit /b 1
)


