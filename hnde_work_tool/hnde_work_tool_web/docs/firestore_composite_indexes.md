# 게시물(`posts`) 목록용 복합 인덱스 — 콘솔 입력 그대로

앱 코드: `where('boardType', isEqualTo: …)` + `orderBy('createdAt', descending: true)`  
→ **복합 인덱스 1개**만 있으면 됩니다.

---

## 1) 색인 화면 URL (한국어)

아래 주소로 들어간 뒤 **복합** 탭 → **색인 만들기**(또는 **인덱스 추가**).

```
https://console.firebase.google.com/u/1/project/hnde-work-web/firestore/databases/-default-/indexes?hl=ko
```

`/u/1/`은 로그인 계정에 따라 `u/0` 등으로 바뀔 수 있습니다.

---

## 2) 콘솔 폼에 넣을 값 (복사용)

| 항목 | 입력 값 |
|------|---------|
| **데이터베이스** | `(default)` |
| **컬렉션 ID** | `posts` |
| **쿼리 범위** | **컬렉션** (Collection) — “컬렉션 그룹”이 아님 |

**색인할 필드 (순서 그대로, 2줄)**

| 순서 | 필드 경로 | 순서(오름·내림) |
|------|-----------|-----------------|
| 1 | `boardType` | **오름차순** (Ascending) |
| 2 | `createdAt` | **내림차순** (Descending) |

- 첫 번째 필드 `boardType`은 `where` **동등(==)** 에 대응 → 콘솔에서는 보통 **오름차순**으로 둡니다.
- 두 번째 필드 `createdAt`은 `orderBy(..., descending: true)` → **내림차순**.

작성 후 **만들기** → 빌드 완료까지 수 분 걸릴 수 있음.

---

## 3) `firestore.indexes.json`과 동일 정의 (참고)

배포 시 아래와 같은 정의가 올라갑니다.

```json
{
  "collectionGroup": "posts",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "boardType", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

CLI:

```bash
firebase deploy --only firestore:indexes
```

---

## 4) 댓글 `comments` (복합 아님)

게시글 상세에서 `comments`에 대해 `orderBy('createdAt', …)` 만 쓰면 **단일 필드 색인**으로 처리되는 경우가 많아, 위와 같은 **추가 복합 인덱스는 보통 필요 없습니다.** (오류가 나면 콘솔 안내에 따라 단일 필드 색인만 켜면 됨.)

---

## 5) 메신저 대화방 `conversations` (복합)

앱 코드: `where('participantUids', arrayContains: …)` + `orderBy('updatedAt', descending: true)`  
→ **복합 인덱스 1개** 필요합니다. `firestore.indexes.json`에 이미 포함되어 있으면 `firebase deploy --only firestore:indexes` 로 배포하세요.

| 항목 | 입력 값 |
|------|---------|
| **컬렉션 ID** | `conversations` |
| **쿼리 범위** | **컬렉션** |

**색인할 필드**

| 순서 | 필드 경로 | 순서 |
|------|-----------|------|
| 1 | `participantUids` | **배열에 포함**(array-contains) |
| 2 | `updatedAt` | **내림차순** |

---

## 6) 대화방 메시지 `conversations/{id}/messages` (단일 필드)

`orderBy('createdAt')` 만 사용하면 보통 **추가 복합 인덱스 없이** 동작합니다.
