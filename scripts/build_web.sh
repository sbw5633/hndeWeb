#!/bin/bash

# 웹 빌드 시 환경변수 자동 주입 스크립트

echo "🚀 Flutter 웹 빌드 시작..."

# 환경변수 확인
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "⚠️  AWS 환경변수가 설정되지 않았습니다."
    echo "개발 환경으로 빌드합니다."
    export ENVIRONMENT="development"
else
    echo "✅ AWS 환경변수 설정 완료"
    export ENVIRONMENT="production"
fi

# Flutter 웹 빌드
echo "📱 Flutter 웹 빌드 중..."
flutter build web --release

# 환경변수 자동 주입
echo "🔧 환경변수 자동 주입 중..."

# web/index.html에 환경변수 스크립트 추가
cat > web/env_script.js << EOF
// 자동 생성된 환경변수 스크립트
window.ENV = {
    AWS_ACCESS_KEY_ID: "$AWS_ACCESS_KEY_ID",
    AWS_SECRET_ACCESS_KEY: "$AWS_SECRET_ACCESS_KEY",
    AWS_REGION: "${AWS_REGION:-ap-northeast-2}",
    AWS_S3_BUCKET: "${AWS_S3_BUCKET:-hnde-web-files}",
    ENVIRONMENT: "$ENVIRONMENT"
};
EOF

# web/index.html에 스크립트 태그 추가
if [ -f "web/index.html" ]; then
    # </head> 태그 앞에 스크립트 추가
    sed -i 's|</head>|<script src="env_script.js"></script>\n</head>|' web/index.html
    echo "✅ 환경변수 스크립트가 index.html에 추가되었습니다."
fi

echo "🎉 웹 빌드 완료!"
echo "📁 빌드 결과: build/web/"
echo "�� 환경: $ENVIRONMENT"
