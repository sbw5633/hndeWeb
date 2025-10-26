# 🚀 개발 환경 설정 가이드

## 📋 필수 설정

### 1. AWS S3 환경변수 설정

**중요**: `.env` 파일이 없어도 앱은 실행되지만, AWS S3 기능은 작동하지 않습니다.

프로젝트 루트에 `.env` 파일을 생성하고 다음 내용을 입력하세요:

```bash
# AWS S3 설정 (실제 키 값 입력 필요)
AWS_ACCESS_KEY_ID=AKIA...실제_액세스_키
AWS_SECRET_ACCESS_KEY=실제_시크릿_키
AWS_REGION=ap-northeast-2
AWS_S3_BUCKET=your-actual-bucket-name

# 환경 설정
ENVIRONMENT=development
DEBUG=true
```

**파일 생성 방법**:
```bash
# Windows PowerShell
New-Item -Path ".env" -ItemType File
notepad .env

# 또는 VS Code에서
code .env
```

**주의사항**:
- `.env` 파일은 `.gitignore`에 포함되어 있어 Git에 커밋되지 않습니다
- 실제 AWS 키를 입력해야 S3 업로드가 작동합니다
- 개발 환경에서는 임시 키를 사용해도 됩니다

### 2. AWS S3 버킷 생성 및 설정

1. **AWS S3 버킷 생성**
   ```bash
   # AWS Console에서 새 버킷 생성
   # 버킷 이름: hnde-web-files (또는 원하는 이름)
   # 리전: ap-northeast-2 (서울)
   ```

2. **IAM 사용자 생성 및 권한 설정**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:GetObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::your-bucket-name",
           "arn:aws:s3:::your-bucket-name/*"
         ]
       }
     ]
   }
   ```

3. **액세스 키 생성**
   - IAM 사용자 → Security credentials → Create access key
   - 생성된 키를 `.env` 파일에 입력

### 3. Firebase 설정

1. **Firebase 프로젝트 생성**
2. **Firestore 데이터베이스 생성**
3. **Authentication 활성화**
4. **firebase_options.dart 파일 업데이트**

## 🔧 개발 서버 실행

```bash
# 의존성 설치
flutter pub get

# 개발 서버 실행
flutter run -d chrome
```

## ✅ 확인 방법

개발 서버 실행 후 콘솔에서 다음 메시지 확인:

```
✅ 개발 환경 설정 완료
=== AWS 설정 정보 ===
환경: 개발
플랫폼: 웹
리전: ap-northeast-2
버킷: your-bucket-name
액세스 키 설정: 완료
시크릿 키 설정: 완료
```

## 🚨 문제 해결

### 환경변수 로딩 실패
```
flutter clean
flutter pub get
flutter run -d chrome
```

### AWS 연결 실패
1. `.env` 파일이 프로젝트 루트에 있는지 확인
2. AWS 키가 올바른지 확인
3. S3 버킷 권한 설정 확인

### 파일 업로드 실패
1. S3 버킷 CORS 설정 확인
2. IAM 사용자 권한 확인
3. 버킷 이름과 리전이 올바른지 확인

## 🔒 보안 주의사항

- `.env` 파일은 절대 Git에 커밋하지 마세요
- `.gitignore`에 `.env`가 포함되어 있는지 확인
- 실제 AWS 키는 안전하게 보관하세요
- 개발용 키와 운영용 키를 분리해서 사용하세요
