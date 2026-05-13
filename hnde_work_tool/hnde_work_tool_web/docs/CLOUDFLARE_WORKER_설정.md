# Cloudflare Worker + R2 연동 설정

---

## Wrangler가 뭔데?

**대시보드(dash.cloudflare.com) 어디를 눌러도 「Wrangler」 메뉴는 없습니다.** Wrangler는 **웹 메뉴가 아니라**, **본인 PC의 터미널**에서만 쓰는 명령입니다.

**Wrangler**는 Cloudflare가 만든 **공식 명령줄(CLI) 도구**입니다. **터미널에서** Worker를 배포하고 R2와 연결할 때 쓰는 도구예요.

- 설치 없이 쓰려면: 프로젝트 폴더에서 `npx wrangler` (앞에 `npx` 붙이면 됨)
- 하는 일 예시: 브라우저로 Cloudflare 계정 로그인 연결(`wrangler login`), Worker 코드 업로드(`wrangler deploy`), 로컬에서 Worker만 띄우기(`wrangler dev`)

**R2만 쓰던 것과 다른 점:** 파일 업로드/다운로드를 **브라우저에서 직접 R2 키로 하지 않기 위해** 그 중간에 **Worker(작은 서버 코드)** 를 하나 두는 겁니다. 그 Worker를 Cloudflare에 **올려야** 해서 Wrangler(또는 대시보드)가 필요합니다.

### 여기서 만들면 안 되는 것: **Workers KV**

왼쪽 메뉴 **Storage & databases → Workers KV** 에서 **「Create a KV namespace」** 를 **만들 필요 없습니다.**

| 서비스 | 이 프로젝트에서 쓰나 |
|--------|----------------------|
| **R2 Object Storage** | 예 — 파일 저장 (이미 만드신 버킷) |
| **Workers & Pages (Worker)** | 예 — 중간 프록시 코드 배포 |
| **Workers KV** | **아니요** — 키–값 DB라서, 우리가 쓰는 R2·비밀값 저장소가 **아님** |

비밀 값(`DOWNLOAD_SIGN_SECRET`)은 **해당 Worker의 Settings → Variables / Secrets** 에 넣거나, 터미널에서 `wrangler secret put` 으로 넣습니다. **KV 네임스페이스와는 무관**합니다.

---

## Cloudflare 대시보드에서 어디 들어가서 뭘 하면 되나 (R2는 이미 만든 경우)

아래는 **웹 브라우저에서 클릭하는 순서**입니다. (메뉴 이름은 Cloudflare가 가끔 바꿀 수 있어서, 비슷한 이름이면 같은 메뉴입니다.)

### A. R2 버킷 이름·파일 URL 앞부분 확인

1. 브라우저에서 [https://dash.cloudflare.com](https://dash.cloudflare.com) 접속 후 로그인.
2. **왼쪽 사이드바**에서 **「R2」** 를 클릭합니다.  
   - 안 보이면 왼쪽 아래 **「더 보기」** 또는 상단 **검색창에 `R2`** 를 입력해 들어갑니다.
3. **버킷 목록**이 나옵니다. 이미 만든 버킷 이름을 확인합니다 (예: `hnde-work-files`).
4. **이 버킷 이름**이 프로젝트의 `cloudflare-worker/wrangler.toml` 안 `bucket_name = "..."` 와 **글자 하나까지 같아야** 합니다.  
   - 다르면: **둘 중 하나**를 맞춥니다 — (1) 대시보드에서 버킷 이름을 참고해 `wrangler.toml`의 `bucket_name`을 수정하거나, (2) 새 버킷을 `wrangler.toml`과 같은 이름으로 만듭니다.
5. 그 **버킷 줄을 클릭**해서 버킷 상세로 들어갑니다.
6. 상단 탭 중 **「설정(Settings)」** 을 클릭합니다.
7. **S3 API** 또는 **「S3 API 엔드포인트」** 같은 블록을 찾습니다.  
   - 여기에 `https://` 로 시작하는 **스토리지 엔드포인트 주소**가 나옵니다 (예: `xxxx.r2.cloudflarestorage.com` 형태).
8. **`R2_PUBLIC_BASE_URL`** 에 넣을 값은 보통 아래처럼 만듭니다.  
   - `https://` + (화면에 나온 **계정/엔드포인트 호스트**) + `/` + **버킷 이름**  
   - 예: `https://abcd1234deadbeef.r2.cloudflarestorage.com/hnde-work-files`  
   - **끝에 슬래시(/) 없이** `wrangler.toml`의 `R2_PUBLIC_BASE_URL`에 넣습니다. (정확한 형태는 해당 설정 화면에 안내된 URL을 따르는 것이 가장 안전합니다.)

### B. 계정 ID (가끔 필요)

1. 대시보드 **맨 오른쪽** 또는 **Workers & Pages** 들어가면 상단/사이드에 **Account ID** 가 보일 때가 있습니다.
2. 복사해 두었다가, 문서나 지원 요청에 쓰입니다. (일반적으로 `wrangler login`만 하면 자동으로 연결됩니다.)

### C. Worker는 대시보드에서 “만들기”만 할 수도 있지만, 이 프로젝트는 **터미널 배포**가 기본

1. 왼쪽에서 **「Workers & Pages」** (또는 **Compute → Workers**) 를 클릭합니다.
2. **처음 배포 전**에는 여기에 Worker가 없을 수 있습니다.
3. 이 저장소에서는 **PC에서** `cloudflare-worker` 폴더로 가서 `npx wrangler deploy` 를 실행하면, **여기 목록에 Worker 이름**(예: `hnde-r2-proxy`)이 생깁니다.
4. 배포가 끝난 뒤 **같은 메뉴(Workers & Pages)** 에서 **방금 만든 Worker 이름**을 클릭합니다.
5. 화면에 **접속 URL** 이 나옵니다. 보통 **`https://이름.계정.workers.dev`** 형태입니다.
6. 이 **전체 주소**(https 포함)를 Flutter `env.worker` 의 **`R2_WORKER_URL_PROD`** 에 넣습니다.

### D. R2 ↔ Worker 연결(바인딩)을 대시보드에서 확인하고 싶을 때

1. **Workers & Pages** → 해당 Worker 클릭.
2. **「설정(Settings)」** 탭.
3. **「바인딩(Bindings)」** 또는 **「Variables」** 안에 **R2** 가 버킷 이름과 연결되어 있는지 봅니다.  
4. `wrangler deploy` 로 배포했다면 `wrangler.toml` 의 `[[r2_buckets]]` 때문에 **자동으로** 여기에 생깁니다. 수동으로 누르지 않아도 됩니다.  
5. 없으면: **Add binding → R2 bucket** 을 눌러 **이름 `FILES`**, 버킷은 위에서 쓴 버킷을 선택 (이름은 `wrangler.toml`의 `binding = "FILES"` 와 같아야 함).

### E. 비밀 값 `DOWNLOAD_SIGN_SECRET` · `GEMINI_API_KEY`

1. **Workers & Pages** → 해당 Worker → **설정(Settings)**.
2. **Variables and Secrets** → **Secret** 추가  
   - `DOWNLOAD_SIGN_SECRET` — 다운로드 URL 서명용 임의 긴 문자열  
   - `GEMINI_API_KEY` — Google AI Studio 등에서 발급한 **Gemini API 키** (Flutter·웹 번들에는 넣지 않음)

또는 `cloudflare-worker` 폴더에서 터미널:

```bash
npx wrangler secret put DOWNLOAD_SIGN_SECRET
npx wrangler secret put GEMINI_API_KEY
```

`GEMINI_API_KEY` 없이 배포하면 AI 비서는 **503**과 안내 문구로 동작합니다.

---

## 0. “프로젝트 안에서만 다 되나?” → **아니요**

| 어디서 하는 일 | 설명 |
|----------------|------|
| **이 저장소** | Worker **소스 코드**(`cloudflare-worker/`), Flutter가 붙을 **URL 규칙** |
| **반드시 Cloudflare에서 할 일** | 계정·**R2 버킷 생성**, `wrangler login`으로 CLI 연결, **`wrangler deploy`로 Worker 배포**, 대시보드에서 R2·Worker 확인 |
| **로컬 PC** | Worker 코드 수정 시에만 `cloudflare-worker`에서 `npm run dev` / `deploy` (일상 개발은 배포 URL만 쓰면 됨) |

즉, **코드는 깃에 있지만**, 실제 동작은 **Cloudflare 계정 위의 R2·Worker**에서 이루어집니다. 아무 설정 없이 “폴더만 열면 된다”는 구조가 **아닙니다.**

---

## 1. Flutter `env.worker` — **배포 Worker 한 줄** (디버그·릴리즈 동일)

일상 개발은 **실서버에 올린 Worker**만 쓰면 됩니다. `env.worker`에는 **`R2_WORKER_URL_PROD`** 만 넣습니다.

```env
R2_WORKER_URL_PROD=https://배포후-나온-주소.workers.dev
```

| 실행 방식 | 어떤 URL 쓰나 |
|-----------|----------------|
| **`flutter run` (디버그)** | **PROD** (배포 Worker) |
| **`flutter build web` (릴리즈)** | **PROD** |

로컬에서 `wrangler dev`로 Worker 소스만 따로 뜨워 테스트할 때만 아래를 **추가**합니다.

```env
WORKER_MODE=local
R2_WORKER_URL_LOCAL=http://127.0.0.1:8787
```

| `WORKER_MODE` | 의미 (디버그/프로파일만) |
|---------------|---------------------------|
| `auto`(기본) | **배포 Worker** (`R2_WORKER_URL_PROD`) |
| `local` | 로컬 `wrangler dev` (`R2_WORKER_URL_LOCAL`) |

---

## 2. Cloudflare에서 꼭 해야 하는 것 (체크리스트)

1. [Cloudflare 대시보드](https://dash.cloudflare.com) 로그인  
2. **R2** 메뉴에서 **버킷 생성** — 이름이 `cloudflare-worker/wrangler.toml`의 `bucket_name`과 같아야 함  
3. PC 터미널에서 `cd cloudflare-worker` 후 `npx wrangler login` — 브라우저로 계정 연결  
4. `wrangler.toml`의 `[vars]` 수정: `FIREBASE_PROJECT_ID`, `ADMIN_UIDS`, `R2_PUBLIC_BASE_URL`  
5. `npx wrangler secret put DOWNLOAD_SIGN_SECRET`  
6. `npx wrangler deploy` — 출력되는 **https://….workers.dev** 를 `R2_WORKER_URL_PROD`에 넣음  

Worker는 **R2 바인딩**으로 버킷에 붙습니다. R2 **S3 API 키를 Flutter에 넣지 않습니다.**

---

## 3. 사전 준비

- Cloudflare 계정, R2 사용 가능
- Node.js 18+
- Firebase 프로젝트 ID가 Worker의 `FIREBASE_PROJECT_ID`와 동일

---

## 4. `cloudflare-worker/wrangler.toml` 수정

| 항목 | 설명 |
|------|------|
| `bucket_name` | R2 버킷 이름과 동일 |
| `FIREBASE_PROJECT_ID` | 웹 앱과 동일 |
| `ADMIN_UIDS` | R2 **목록·삭제** 허용용 **Firebase Authentication uid** (쉼표 구분). Firestore `role` 과 자동 연동되지 않음 — 아래 참고 |
| `R2_PUBLIC_BASE_URL` | `https://<계정>.r2.cloudflarestorage.com/<버킷>` (슬래시 없이 접두만) |

**Firestore “메인관리자”와 `ADMIN_UIDS`:** 앱 UI·권한은 Firestore 프로필(역할)로 판별하지만, **Worker는 DB를 읽지 않고** JWT의 **uid**만 알 수 있습니다. 그래서 파일 목록/삭제 API는 **Cloudflare에 적어 둔 `ADMIN_UIDS`** 와만 비교합니다. Firestore에서 메인관리자로 보이더라도, **같은 계정의 Auth uid**를 `ADMIN_UIDS`에 넣고 `wrangler deploy`(또는 대시보드 변수 저장)해야 합니다. uid 확인: Firebase Console → Authentication → 사용자 → **사용자 UID**.

---

## 5. 비밀: `DOWNLOAD_SIGN_SECRET`

다운로드 서명·`/v1/sign-download` 에 필요합니다. **없으면** Worker가 `{"error":"server_misconfigured"}` **500** 을 반환합니다.

```bash
cd cloudflare-worker
npm install
npx wrangler secret put DOWNLOAD_SIGN_SECRET
```

배포된 Worker에도 동일하게 넣었는지 확인하세요(로컬 `wrangler dev`와 배포 환경은 시크릿이 따로입니다).

---

## 6. 로컬 Worker (선택 — Worker 코드만 손볼 때)

일상 **`flutter run`은 배포 Worker만** 쓰면 되므로 이 절은 **필수가 아닙니다.**  
`cloudflare-worker` 소스를 수정하고 로컬에서 먼저 검증할 때만:

```bash
cd cloudflare-worker
npm install
npm run dev
```

→ `http://127.0.0.1:8787/health` 가 `{"ok":true}` 이면 정상.  
그때 Flutter `env.worker`에 `WORKER_MODE=local` 과 `R2_WORKER_URL_LOCAL` 을 넣습니다.  
Flutter 웹은 `--web-port=5000` 등으로 띄워 **8787과 포트가 겹치지 않게** 합니다.

터미널 2 — Flutter:

- `env.worker`에 `R2_WORKER_URL_PROD` (기본) 또는 위 로컬 모드  
- `.\run_web.ps1` 또는 **Flutter Web (Chrome, env.worker)** 로 실행  

---

## 7. 배포 Worker

```bash
cd cloudflare-worker
npx wrangler deploy
```

나온 URL을 `R2_WORKER_URL_PROD`에 넣은 뒤:

```powershell
.\build_web.ps1
```

릴리즈 빌드는 **자동으로 PROD URL만** 사용합니다.

---

## 8. CORS·보안

- `Authorization: Bearer <Firebase ID 토큰>` 필수(업로드·목록·삭제·sign-download)  
- 목록/삭제는 `ADMIN_UIDS`  
- 브라우저 새 창 다운로드는 서명 URL (`/v1/download?...`)

---

## 9. 문제 해결

| 증상 | 확인 |
|------|------|
| Worker URL 없음 | `env.worker`에 `R2_WORKER_URL_PROD` (또는 구 `R2_WORKER_URL`) |
| 릴리즈 빌드 오류 | `R2_WORKER_URL_PROD` 비었는지 |
| 업로드 401 | Firebase 로그인 |
| 목록 403 | `ADMIN_UIDS`에 uid, `wrangler deploy` |
| 다운로드 500 | `DOWNLOAD_SIGN_SECRET` |

---

## 10. 구 방식

클라이언트에 R2 Access/Secret 넣던 방식은 제거되었고, **Worker 경유만** 사용합니다.
