@echo off
setlocal
cd /d "%~dp0"

REM Build output outside repo - OneDrive shader writes - use LocalAppData.
set "WEB_OUT=%LOCALAPPDATA%\hnde_work_tool_web_hosting_dev"
if "%WEB_OUT%"=="" (
  echo ERROR: WEB_OUT is empty. Save this .bat as ANSI or UTF-8 with BOM.
  exit /b 1
)

REM Firebase dev project ID - override with FIREBASE_PROJECT_DEV.
if not defined FIREBASE_PROJECT_DEV set "FIREBASE_PROJECT_DEV=hnde-work-dev"
REM Firestore artifacts doc id - override with FIRESTORE_APP_ID_DEV - default is project id.
if not defined FIRESTORE_APP_ID_DEV set "FIRESTORE_APP_ID_DEV=%FIREBASE_PROJECT_DEV%"

echo [deploy_dev] FIREBASE_PROJECT_DEV=%FIREBASE_PROJECT_DEV%
echo [deploy_dev] FIRESTORE_APP_ID_DEV=%FIRESTORE_APP_ID_DEV%
echo [deploy_dev] WEB_OUT=%WEB_OUT%
echo [deploy_dev] flutter build web ...
set "DEFINE_FILES="
if exist "%~dp0env.worker" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.worker"
if exist "%~dp0env.tour" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.tour"
if exist "%~dp0env.kakao" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.kakao"
REM Split with ^ so a soft-wrapped line cannot break into a stray "--dart-define" command.
call flutter build web --release ^
  --dart-define=FIREBASE_ENV=dev ^
  --dart-define=FIRESTORE_APP_ID=%FIRESTORE_APP_ID_DEV% ^
  %DEFINE_FILES% ^
  --no-wasm-dry-run ^
  -o "%WEB_OUT%"
if errorlevel 1 exit /b 1

echo [deploy_dev] generating firebase.hosting.deploy.tmp.json ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\write_firebase_hosting_only_json.ps1" -PublicDir "%WEB_OUT%"
if errorlevel 1 exit /b 1

echo [deploy_dev] firebase deploy ...
call firebase deploy --project "%FIREBASE_PROJECT_DEV%" --only hosting --config firebase.hosting.deploy.tmp.json
set DEPLOY_ERR=%ERRORLEVEL%
del "%~dp0firebase.hosting.deploy.tmp.json" 2>nul
if not %DEPLOY_ERR%==0 exit /b %DEPLOY_ERR%

echo [deploy_dev] done.
endlocal
