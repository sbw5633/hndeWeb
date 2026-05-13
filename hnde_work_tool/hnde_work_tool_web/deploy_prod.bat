@echo off
setlocal
cd /d "%~dp0"

REM Build output outside repo - OneDrive shader writes - use LocalAppData.
set "WEB_OUT=%LOCALAPPDATA%\hnde_work_tool_web_hosting"
if "%WEB_OUT%"=="" (
  echo ERROR: WEB_OUT is empty. Save this .bat as ANSI or UTF-8 with BOM.
  exit /b 1
)

REM Firebase prod project ID - override with FIREBASE_PROJECT_PROD.
if not defined FIREBASE_PROJECT_PROD set "FIREBASE_PROJECT_PROD=hnde-work-web"
REM Firestore artifacts doc id - override with FIRESTORE_APP_ID_PROD - default is project id.
if not defined FIRESTORE_APP_ID_PROD set "FIRESTORE_APP_ID_PROD=%FIREBASE_PROJECT_PROD%"

echo [deploy_prod] FIREBASE_PROJECT_PROD=%FIREBASE_PROJECT_PROD%
echo [deploy_prod] FIRESTORE_APP_ID_PROD=%FIRESTORE_APP_ID_PROD%
echo [deploy_prod] WEB_OUT=%WEB_OUT%
echo [deploy_prod] flutter build web ...
set "DEFINE_FILES="
if exist "%~dp0env.worker" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.worker"
if exist "%~dp0env.tour" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.tour"
if exist "%~dp0env.kakao" set "DEFINE_FILES=%DEFINE_FILES% --dart-define-from-file=env.kakao"
REM Split with ^ so a soft-wrapped line cannot break into a stray "--dart-define" command.
call flutter build web --release ^
  --dart-define=FIREBASE_ENV=prod ^
  --dart-define=FIRESTORE_APP_ID=%FIRESTORE_APP_ID_PROD% ^
  %DEFINE_FILES% ^
  --no-wasm-dry-run ^
  -o "%WEB_OUT%"
if errorlevel 1 exit /b 1

echo [deploy_prod] generating firebase.hosting.deploy.tmp.json ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\write_firebase_hosting_only_json.ps1" -PublicDir "%WEB_OUT%"
if errorlevel 1 exit /b 1

echo [deploy_prod] firebase deploy ...
call firebase deploy --project "%FIREBASE_PROJECT_PROD%" --only hosting --config firebase.hosting.deploy.tmp.json
set DEPLOY_ERR=%ERRORLEVEL%
del "%~dp0firebase.hosting.deploy.tmp.json" 2>nul
if not %DEPLOY_ERR%==0 exit /b %DEPLOY_ERR%

echo [deploy_prod] done.
endlocal
