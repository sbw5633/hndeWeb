#!/bin/bash

# hnde_homepage Firebase 호스팅 배포 스크립트

echo "🚀 hnde_homepage 배포 시작..."

# Flutter 웹 빌드
echo "📦 Flutter 웹 빌드 중..."
flutter build web --release --dart-define=FIREBASE_ENV=dev

if [ $? -ne 0 ]; then
    echo "❌ 빌드 실패"
    exit 1
fi

# Firebase 배포
echo "🔥 Firebase 호스팅 배포 중 (dev, target=homepage)..."
firebase deploy --project hnde-homepage-db --only hosting:homepage

if [ $? -eq 0 ]; then
    echo "✅ 배포 완료!"
else
    echo "❌ 배포 실패"
    exit 1
fi

