# Cloudinary 설정 가이드

## Cloudinary 무료 플랜

Cloudinary는 무료 플랜을 제공합니다:
- **25GB 저장 공간**
- **25GB 월간 대역폭**
- 무제한 변환
- 이미지 최적화
- CDN 자동 제공

## 설정 방법

1. Cloudinary 계정 생성: https://cloudinary.com/users/register/free

2. Dashboard에서 다음 정보 확인:
   - Cloud Name
   - API Key
   - API Secret

3. Upload Preset 설정:
   - Settings → Upload → Upload presets
   - "ml_default" 또는 원하는 이름으로 생성
   - Signing mode: Unsigned (프론트엔드에서 직접 업로드하는 경우)

4. 프로젝트 설정:
   - `lib/core/file_upload_service.dart`의 생성자에 Cloudinary 정보 입력
   - 또는 환경 변수 사용

## 환경 변수 사용 (권장)

`.env` 파일 생성:
```
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
CLOUDINARY_UPLOAD_PRESET=ml_default
```

## 보안 주의사항

- API Secret은 서버 측에서만 사용해야 합니다
- 프론트엔드에서는 Unsigned Preset 사용 권장
- Signed Preset을 사용하려면 서버 측에서 서명 생성 필요

