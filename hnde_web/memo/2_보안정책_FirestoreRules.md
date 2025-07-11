# 2단계: Firestore 보안정책 (Security Rules)

## 2.1 역할 기반 Firestore Security Rules 예시

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

## 2.2 특수 케이스 설명
- 승인 전 사용자는 모든 데이터 접근 차단
- 익명 게시판도 Firestore에는 createdBy 저장(관리자만 식별)
- 각 컬렉션별로 역할 기반 접근 제어 