#!/bin/bash

# hnde_home_admin Firebase 호스팅 배포 스크립트 (PROD)

echo "🚀 hnde_home_admin PROD 배포 시작..."

# Flutter 웹 빌드 (PROD Firebase)
echo "📦 Flutter 웹 빌드 중 (FIREBASE_ENV=prod)..."
flutter build web --release --dart-define=FIREBASE_ENV=prod

if [ $? -ne 0 ]; then
    echo "❌ 빌드 실패"
    exit 1
fi

# Firebase 배포 (PROD 프로젝트)
echo "🔥 Firebase 호스팅 배포 중 (prod, target=admin)..."
firebase deploy --project hnde-homepage-prod --only hosting:admin

if [ $? -eq 0 ]; then
    echo "✅ PROD 배포 완료!"
else
    echo "❌ PROD 배포 실패"
    exit 1
fi


