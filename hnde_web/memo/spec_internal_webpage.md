# 📘 [최종] 사내 내부 업무 시스템 기획서

---

## 1. 시스템 개요
- **목적:** 회사 내부 자료 공유, 요청/제출, 업무 관리(연차, 휴무, 4대보험 등), 공지 전달, 게시판 커뮤니케이션 통합 플랫폼 구축
- **기술 스택:** Flutter(Web), Firebase(Auth, Firestore), Wasabi(File Storage, 모든 업로드 파일)
- **디자인:** 밝은 푸른 계열, 세련되고 직관적인 업무형 레이아웃 (소노호텔/한국도로공사 참고)

---

## 2. 핵심 메뉴 구조
| 메뉴         | 하위 구성/설명                                   |
|--------------|-------------------------------------------------|
| 로그인/회원가입 | 로그인, 회원가입, 승인 대기 화면                  |
| 대시보드      | 공지 요약, 자료요청 현황, 연차사용 요약(카드형)     |
| 공지사항      | 공지 목록, 상세, 작성 (권한별, 전 사업소 공지)      |
| 게시판        | 일반 게시판(댓글/작성자), 익명 게시판(작성자 숨김)  |
| 자료 요청/제출 | 요청 등록, 제출현황, 파일 제출                    |
| 회사 정보     | 조직도, 부서별 구성도 (정적/이미지 기반)           |
| 업무기능      | 연차/휴무/4대보험 관리                            |
| 관리자 기능   | 사용자 승인/관리, 역할 및 소속 설정                |

---

## 3. 사용자 권한 및 접근 범위
| 역할           | 설명                        | 접근 가능 범위 요약                       |
|----------------|-----------------------------|-------------------------------------------|
| 메인 관리자    | 전체 운영자(기술관리자)     | 사용자 승인/수정, 모든 데이터 접근         |
| 본사 관리자    | 본사 소속 일반 관리자        | 모든 지점 자료 열람, 전 사업소 공지 작성   |
| 사업소 관리자  | 지점별 자료/공지 담당자      | 자기 지점 요청/제출/공지 관리             |
| 일반 직원      | 기본 사무직 구성원           | 자료요청/제출/업무기능 불가, 열람만 가능   |

---

## 4. 주요 기능 흐름
### 4.1 회원가입/승인
- 가입 시 approved=false, 메인관리자 승인 필요
- 승인 전 로그인 시 “승인 대기 중” 메시지 및 기능 차단

### 4.2 공지사항
- 본사 관리자 이상만 작성 가능
- “전 사업소 공지” 체크박스(본사 관리자만 노출)
- 모든 사용자 열람, 소속별 필터링

### 4.3 자료 요청/제출
- 요청: 본사/지점 관리자만 가능
- 제출: 소속 지점 사용자만 가능
- 본사 관리자는 전체 제출현황 열람
- 제출 마감 전/후, 제출 여부 아이콘 표시

### 4.4 게시판
- 일반: 댓글, 작성자 표시
- 익명: 작성자 숨김(관리자만 Firestore에서 식별 가능)

### 4.5 업무기능
- 연차: 본인 연차 내역 확인
- 휴무: 지점별 휴무 등록
- 4대보험: 등록/열람(본사 전용)

---

## 5. UI/UX 디자인 가이드
- **컬러:** 밝은 푸른 계열 (#D0E8F2, #4DA3D2, #336699)
- **레이아웃:** 좌측 고정 사이드바 + 상단 AppBar
- **폰트:** Noto Sans KR, Pretendard
- **아이콘:** Lucide, Material Icons
- **카드/박스:** 소프트 그림자, rounded-2xl
- **반응형:** 데스크탑 우선, 모바일 대응(사이드바 접힘)

#### 예시 UI
- AppBar: 로고 + 사용자 프로필 + 로그아웃
- SideNav: 대시보드, 공지, 자료, 게시판, 업무, 회사정보
- Dashboard: 공지/미제출/내연차 카드
- Notices: 리스트/작성/열람
- Boards: 탭 전환(일반/익명), 댓글
- DataRequests: 요청목록 + 지점별 제출표
- UserApproval: 승인/검색/수정(관리자)

---

## 6. 기술/보안 설계
- **인증:** Firebase Auth(Email/Password) + 승인여부 체크
- **DB:** Firestore(사용자, 공지, 자료요청, 제출, 게시판 등)
- **파일:** Wasabi Presigned URL(모든 업로드)
- **보안:** Firestore 규칙(UID+역할 기반), 파일 50MB 이하 권장
- **관리자 보호:** 메인 관리자만 사용자 승인/수정 가능

---

## 7. Firestore 구조 예시
### Users
```json
{
  "uid": "abc123",
  "name": "홍길동",
  "email": "hong@example.com",
  "affiliation": "서울본사",
  "role": "hq_admin", // main_admin | hq_admin | branch_admin | employee
  "approved": true
}
```
### Notices
```json
{
  "title": "6월 전체공지",
  "targetScope": "all", // all | branch
  "createdBy": "uid",
  "createdAt": "timestamp"
}
```
### DataRequests / DataSubmissions
- 요청자가 사업소 선택 → 제출자는 제출 및 상태 표시
- 본사 관리자는 전체 테이블 열람

---

## 8. 추후 확장 고려
- 전자결재
- 모바일 앱 푸시 알림
- 급여명세 연동
- 출장보고서 제출
- 사내 교육 수강/확인

---

**[중요/주의]**
- 모든 파일 업로드는 Wasabi 사용(게시판 첨부 포함)
- 익명 게시판도 Firestore에는 작성자 정보 저장(관리자만 식별)
- 업무기능(연차/휴무/4대보험)은 권한 차이 외 별도 요구사항 없음
- 모바일 앱은 추후, 현재는 웹 완성 우선

---

## 9. Firestore 역할별 접근 권한표

| 컬렉션         | main_admin | hq_admin | branch_admin | employee |
|----------------|:----------:|:--------:|:------------:|:--------:|
| Users          | CRUD       | R        | R            | R        |
| Notices        | CRUD       | CRUD     | CR           | R        |
| Boards         | CRUD       | CRUD     | CRUD         | CR       |
| DataRequests   | CRUD       | CRUD     | CR           | R        |
| DataSubmissions| R          | R        | R            | CR       |
| Departments    | CRUD       | R        | R            | R        |

- C: 생성(Create), R: 조회(Read), U: 수정(Update), D: 삭제(Delete)
- 승인되지 않은 사용자는 모든 컬렉션 접근 불가
- 익명 게시판: Firestore에는 작성자 UID 저장, UI에만 숨김

---

## 10. Firestore Security Rules 예시

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 유저 정보
    match /Users/{userId} {
      allow read: if isSignedIn() && isApproved();
      allow write: if isMainAdmin();
    }
    // 공지사항
    match /Notices/{noticeId} {
      allow read: if isSignedIn() && isApproved();
      allow create, update, delete: if isMainAdmin() || isHQAdmin() || (isBranchAdmin() && resource.data.targetScope == 'branch');
    }
    // 게시판
    match /Boards/{boardId} {
      allow read: if isSignedIn() && isApproved();
      allow create: if isSignedIn() && isApproved();
      allow update, delete: if isMainAdmin() || isHQAdmin() || isBranchAdmin() || (isEmployee() && request.resource.data.createdBy == request.auth.uid);
    }
    // 자료 요청
    match /DataRequests/{requestId} {
      allow read: if isSignedIn() && isApproved();
      allow create: if isMainAdmin() || isHQAdmin() || isBranchAdmin();
      allow update, delete: if isMainAdmin() || isHQAdmin();
    }
    // 자료 제출
    match /DataSubmissions/{submissionId} {
      allow read: if isSignedIn() && isApproved();
      allow create: if isEmployee() && request.resource.data.submittedBy == request.auth.uid;
    }
    // 부서 정보
    match /Departments/{deptId} {
      allow read: if isSignedIn() && isApproved();
      allow write: if isMainAdmin();
    }

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    function isApproved() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.approved == true;
    }
    function isMainAdmin() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'main_admin';
    }
    function isHQAdmin() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'hq_admin';
    }
    function isBranchAdmin() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'branch_admin';
    }
    function isEmployee() {
      return get(/databases/$(database)/documents/Users/$(request.auth.uid)).data.role == 'employee';
    }
  }
}
```

- 승인 전 사용자는 모든 데이터 접근 차단
- 익명 게시판도 Firestore에는 createdBy 저장(관리자만 식별)
- 각 컬렉션별로 역할 기반 접근 제어