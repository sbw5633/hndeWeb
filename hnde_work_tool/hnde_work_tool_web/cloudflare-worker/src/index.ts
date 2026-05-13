import { jwtVerify, createRemoteJWKSet } from "jose";

export interface Env {
  FILES: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  ADMIN_UIDS: string;
  R2_PUBLIC_BASE_URL: string;
  DOWNLOAD_SIGN_SECRET: string;
  /** wrangler secret put GEMINI_API_KEY */
  GEMINI_API_KEY?: string;
  /** 선택, 기본 gemini-2.0-flash */
  GEMINI_MODEL?: string;
  /** wrangler secret put KAKAO_REST_API_KEY — Flutter 웹에서 카카오 주소 검색 프록시용 */
  KAKAO_REST_API_KEY?: string;
  /** wrangler secret put TOUR_API_SERVICE_KEY — TourAPI(공공데이터포털) 프록시용 */
  TOUR_API_SERVICE_KEY?: string;
}

const jwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
  )
);

/** multipart 값은 `File | string`; `instanceof File`은 TS2358(원시 타입 포함) 회피 */
function isFormDataFile(v: File | string | null): v is File {
  return v != null && typeof v !== "string";
}

function corsHeaders(origin: string | null): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Max-Age": "86400",
  };
}

async function verifyFirebase(
  token: string,
  projectId: string
): Promise<{ uid: string }> {
  const { payload } = await jwtVerify(token, jwks, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  const uid = payload.sub;
  if (!uid || typeof uid !== "string") {
    throw new Error("no uid");
  }
  return { uid };
}

function parseBearer(request: Request): string | null {
  const h = request.headers.get("Authorization");
  if (!h?.startsWith("Bearer ")) return null;
  return h.slice(7).trim();
}

function isAdminUid(env: Env, uid: string): boolean {
  const raw = (env.ADMIN_UIDS ?? "").trim();
  if (!raw) return false;
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .includes(uid);
}

async function hmacHex(message: string, secret: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  const bytes = new Uint8Array(sig);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function buildFileKey(safeName: string): string {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const ms = now.getTime();
  return `uploads/${y}/${m}/${ms}_${safeName}`;
}

export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");
    const c = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: c });
    }

    try {
      const path = url.pathname.replace(/\/$/, "") || "/";

      if (path === "/v1/download" && request.method === "GET") {
        return handleDownloadGet(url, env, c);
      }

      if (path === "/v1/upload" && request.method === "POST") {
        return await handleUpload(request, env, c);
      }

      if (path === "/v1/sign-download" && request.method === "POST") {
        return await handleSignDownload(request, env, c);
      }

      if (path === "/v1/list" && request.method === "GET") {
        return await handleList(request, env, c);
      }

      if (path === "/v1/object" && request.method === "DELETE") {
        return await handleDeleteObject(request, env, c);
      }

      if (path === "/v1/gemini/chat" && request.method === "POST") {
        return await handleGeminiChat(request, env, c);
      }

      if (path === "/v1/kakao/address" && request.method === "GET") {
        return await handleKakaoAddress(url, env, c);
      }

      if (path === "/v1/kakao/keyword" && request.method === "GET") {
        return await handleKakaoKeyword(url, env, c);
      }

      if (path.startsWith("/v1/tour/kor/") && request.method === "GET") {
        return await handleTourKorProxy(url, env, c);
      }

      // Flutter Web에서 혼합콘텐츠(http)·CORS로 이미지가 깨지는 경우를 대비한 안전 프록시.
      // allowlist 도메인만 허용해 오픈 프록시 악용 방지.
      if (path === "/v1/tour/media" && request.method === "GET") {
        return await handleTourMediaProxy(url, c);
      }

      if (path === "/v1/culture-day/generate" && request.method === "POST") {
        return await handleCultureDayGenerate(request, env, c);
      }

      if (path === "/health" && request.method === "GET") {
        return json({ ok: true }, 200, c);
      }

      return json({ error: "not_found" }, 404, c);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return json({ error: msg }, 500, c);
    }
  },
};

function isAllowedTourMediaHost(host: string): boolean {
  const h = host.toLowerCase();
  const allowed = new Set<string>([
    "tong.visitkorea.or.kr",
    "korean.visitkorea.or.kr",
    "english.visitkorea.or.kr",
    "visitkorea.or.kr",
    "cdn.visitkorea.or.kr",
    "api.visitkorea.or.kr",
  ]);
  if (allowed.has(h)) return true;
  // 일부 리소스는 서브도메인으로 내려올 수 있어 보수적으로 허용
  if (h.endsWith(".visitkorea.or.kr")) return true;
  return false;
}

async function handleTourMediaProxy(url: URL, c: HeadersInit): Promise<Response> {
  const raw = (url.searchParams.get("url") ?? "").trim();
  if (!raw) {
    return json({ error: "missing_url" }, 400, c);
  }

  let upstream: URL;
  try {
    upstream = new URL(raw);
  } catch {
    return json({ error: "bad_url" }, 400, c);
  }

  if (upstream.protocol !== "http:" && upstream.protocol !== "https:") {
    return json({ error: "bad_scheme" }, 400, c);
  }
  if (!isAllowedTourMediaHost(upstream.hostname)) {
    return json(
      { error: "host_not_allowed", host: upstream.hostname },
      400,
      c
    );
  }

  const r = await fetch(upstream.toString(), {
    headers: {
      // 이미지 원본 서버가 UA에 민감한 경우가 있어 지정
      "User-Agent":
        "Mozilla/5.0 (compatible; HndeWorkTool/1; CloudflareWorker)",
      Accept: "image/*,*/*;q=0.8",
    },
  });
  if (r.status < 200 || r.status >= 300) {
    const text = await r.text();
    return json(
      {
        error: "tour_media_upstream",
        status: r.status,
        body: text.length > 400 ? text.slice(0, 400) + "…" : text,
      },
      502,
      c
    );
  }

  const contentType =
    r.headers.get("Content-Type") ?? "application/octet-stream";
  const cacheControl =
    r.headers.get("Cache-Control") ?? "public, max-age=86400";

  return new Response(r.body, {
    status: 200,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": cacheControl,
      ...c,
    },
  });
}

function json(
  body: unknown,
  status: number,
  cors: HeadersInit
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...cors,
    },
  });
}

/** 브라우저에서 카카오 REST 직접 호출(403) 대신 Worker가 키로 중계 */
async function handleKakaoAddress(
  url: URL,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const raw = env.KAKAO_REST_API_KEY;
  const apiKey =
    typeof raw === "string" ? raw.trim() : "";
  if (!apiKey) {
    return json({ error: "kakao_not_configured" }, 503, c);
  }
  const query = url.searchParams.get("query") ?? "";
  const size = url.searchParams.get("size") ?? "15";
  const kakaoUrl = new URL(
    "https://dapi.kakao.com/v2/local/search/address.json"
  );
  kakaoUrl.searchParams.set("query", query);
  kakaoUrl.searchParams.set("size", size);
  const r = await fetch(kakaoUrl.toString(), {
    headers: {
      Authorization: `KakaoAK ${apiKey}`,
      Accept: "application/json",
    },
  });
  const text = await r.text();
  if (r.status !== 200) {
    return json(
      {
        error: "kakao_upstream",
        kakaoStatus: r.status,
        kakaoBody: text.length > 800 ? text.slice(0, 800) + "…" : text,
      },
      502,
      c
    );
  }
  return new Response(text, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      ...c,
    },
  });
}

/** 브라우저에서 카카오 키워드(장소) 검색을 Worker가 중계 */
async function handleKakaoKeyword(
  url: URL,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const raw = env.KAKAO_REST_API_KEY;
  const apiKey =
    typeof raw === "string" ? raw.trim() : "";
  if (!apiKey) {
    return json({ error: "kakao_not_configured" }, 503, c);
  }
  const query = url.searchParams.get("query") ?? "";
  const size = url.searchParams.get("size") ?? "15";
  const kakaoUrl = new URL(
    "https://dapi.kakao.com/v2/local/search/keyword.json"
  );
  kakaoUrl.searchParams.set("query", query);
  kakaoUrl.searchParams.set("size", size);
  const r = await fetch(kakaoUrl.toString(), {
    headers: {
      Authorization: `KakaoAK ${apiKey}`,
      Accept: "application/json",
    },
  });
  const text = await r.text();
  if (r.status !== 200) {
    return json(
      {
        error: "kakao_upstream",
        kakaoStatus: r.status,
        kakaoBody: text.length > 800 ? text.slice(0, 800) + "…" : text,
      },
      502,
      c
    );
  }
  return new Response(text, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      ...c,
    },
  });
}

/** 공공데이터포털 "인코딩" 키는 이미 %XX 형태 — URLSearchParams.set 시 %가 이중 인코딩됨 */
function isLikelyPreEncodedServiceKey(k: string): boolean {
  return /%[0-9A-Fa-f]{2}/.test(k.trim());
}

/** 클라이언트 쿼리 복사 후 serviceKey만 안전하게 붙임 */
function buildTourUpstreamSearch(incomingUrl: URL, serviceKey: string): string {
  const p = new URLSearchParams();
  incomingUrl.searchParams.forEach((v, k) => {
    if (k.toLowerCase() === "servicekey") {
      return;
    }
    p.set(k, v);
  });
  let qs = p.toString();
  const sk = serviceKey.trim();
  const skPart = isLikelyPreEncodedServiceKey(sk)
    ? sk
    : encodeURIComponent(sk);
  qs = qs ? `${qs}&serviceKey=${skPart}` : `serviceKey=${skPart}`;
  return qs;
}

/** pathname에서 KorService2 엔드포인트명만 추출·정규화 (슬래시/대소문자 오타 허용) */
function normalizeKorService2Endpoint(raw: string): string {
  let s = decodeURIComponent(raw).trim();
  s = s.replace(/\/+$/, "");
  const first = s.split("/")[0] ?? "";
  const lower = first.toLowerCase();
  const canon: Record<string, string> = {
    locationbasedlist2: "locationBasedList2",
    searchfestival2: "searchFestival2",
    searchkeyword2: "searchKeyword2",
    detailcommon2: "detailCommon2",
    detailintro2: "detailIntro2",
    detailimage2: "detailImage2",
  };
  return canon[lower] ?? first;
}

/** 브라우저 CORS 회피용: TourAPI(KorService2) GET 프록시 */
async function handleTourKorProxy(
  url: URL,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const raw = env.TOUR_API_SERVICE_KEY;
  const serviceKey = typeof raw === "string" ? raw.trim() : "";
  if (!serviceKey) {
    return json({ error: "tour_not_configured" }, 503, c);
  }

  // /v1/tour/kor/<endpointName>
  const prefix = "/v1/tour/kor/";
  const endpointRaw = url.pathname.startsWith(prefix)
    ? url.pathname.slice(prefix.length)
    : "";
  const endpoint = normalizeKorService2Endpoint(endpointRaw);
  const allowed = new Set([
    "locationBasedList2",
    "searchFestival2",
    "searchKeyword2",
    "detailCommon2",
    "detailIntro2",
    "detailImage2",
  ]);
  if (!allowed.has(endpoint)) {
    return json(
      {
        error: "tour_endpoint_not_allowed",
        endpoint,
        endpointRaw,
        hint:
          "배포된 Worker가 구버전이면 allowlist에 detailImage2가 없을 수 있습니다. `npx wrangler deploy` 로 최신 worker를 배포하세요.",
      },
      400,
      c
    );
  }

  const upstream = new URL(
    `https://apis.data.go.kr/B551011/KorService2/${endpoint}`
  );
  upstream.search = buildTourUpstreamSearch(url, serviceKey);

  const tourHeaders: Record<string, string> = {
    Accept: "application/json, application/xml;q=0.9",
    "User-Agent":
      "Mozilla/5.0 (compatible; HndeWorkTool/1; CloudflareWorker)",
  };

  let r = await fetch(upstream.toString(), { headers: tourHeaders });
  let text = await r.text();
  // 공공 API가 간헐적으로 500/502/503 을 내는 경우가 있어 1회만 재시도
  if (r.status === 500 || r.status === 502 || r.status === 503) {
    await new Promise<void>((resolve) => setTimeout(resolve, 800));
    r = await fetch(upstream.toString(), { headers: tourHeaders });
    text = await r.text();
  }

  if (r.status < 200 || r.status >= 300) {
    return json(
      {
        error: "tour_upstream",
        tourStatus: r.status,
        tourBody: text.length > 1200 ? text.slice(0, 1200) + "…" : text,
      },
      502,
      c
    );
  }
  return new Response(text, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      ...c,
    },
  });
}

async function handleDownloadGet(
  url: URL,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const key = url.searchParams.get("key");
  const expStr = url.searchParams.get("exp");
  const sig = url.searchParams.get("sig");
  const filename = url.searchParams.get("filename") ?? "download";

  if (!key || !expStr || !sig) {
    return json({ error: "missing_params" }, 400, c);
  }

  const exp = parseInt(expStr, 10);
  if (Number.isNaN(exp) || exp < Math.floor(Date.now() / 1000)) {
    return json({ error: "expired" }, 403, c);
  }

  const secret = env.DOWNLOAD_SIGN_SECRET;
  if (!secret) {
    return json({ error: "server_misconfigured" }, 500, c);
  }

  const expected = await hmacHex(`${key}:${exp}:${filename}`, secret);
  if (expected !== sig) {
    return json({ error: "bad_sig" }, 403, c);
  }

  const obj = await env.FILES.get(key);
  if (obj === null) {
    return json({ error: "not_found" }, 404, c);
  }

  const safeName = filename.replace(/[^\w.\-가-힣 ]+/g, "_").slice(0, 200);
  const headers = new Headers(c);
  headers.set(
    "Content-Disposition",
    `attachment; filename*=UTF-8''${encodeURIComponent(safeName)}`
  );
  const ct = obj.httpMetadata?.contentType ?? "application/octet-stream";
  headers.set("Content-Type", ct);

  return new Response(obj.body, { headers });
}

async function handleUpload(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);

  await verifyFirebase(token, env.FIREBASE_PROJECT_ID);

  const form = await request.formData();
  const file = form.get("file");
  if (!isFormDataFile(file)) {
    return json({ error: "expected_file_field" }, 400, c);
  }

  const rawName = file.name || "file";
  const safeName = rawName.replace(/\s+/g, "_");
  const fileKey = buildFileKey(safeName);

  await env.FILES.put(fileKey, file.stream(), {
    httpMetadata: {
      contentType: file.type || "application/octet-stream",
    },
  });

  const base = env.R2_PUBLIC_BASE_URL.replace(/\/$/, "");
  const fileUrl = `${base}/${fileKey}`;

  return json({ fileKey, fileUrl }, 200, c);
}

async function handleSignDownload(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);

  await verifyFirebase(token, env.FIREBASE_PROJECT_ID);

  const body = (await request.json()) as { key?: string; fileName?: string };
  const key = body.key?.trim();
  const fileName = body.fileName?.trim() ?? "download";
  if (!key) return json({ error: "missing_key" }, 400, c);

  const secret = env.DOWNLOAD_SIGN_SECRET;
  if (!secret) {
    return json({ error: "server_misconfigured" }, 500, c);
  }

  const exp = Math.floor(Date.now() / 1000) + 3600;
  const sig = await hmacHex(`${key}:${exp}:${fileName}`, secret);

  const baseWorker = new URL(request.url).origin;
  const u = new URL("/v1/download", baseWorker);
  u.searchParams.set("key", key);
  u.searchParams.set("exp", String(exp));
  u.searchParams.set("sig", sig);
  u.searchParams.set("filename", fileName);

  return json({ url: u.toString() }, 200, c);
}

async function handleList(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);

  const { uid } = await verifyFirebase(token, env.FIREBASE_PROJECT_ID);
  if (!isAdminUid(env, uid)) {
    return json({ error: "forbidden" }, 403, c);
  }

  const objects: {
    key: string;
    lastModified: string | null;
    size: number | null;
  }[] = [];

  let cursor: string | undefined;
  for (;;) {
    const page = await env.FILES.list({ limit: 1000, cursor });
    for (const o of page.objects) {
      const uploaded = o.uploaded;
      objects.push({
        key: o.key,
        lastModified:
          uploaded != null ? new Date(uploaded as unknown as Date).toISOString() : null,
        size: o.size ?? null,
      });
    }
    if (!page.truncated) break;
    cursor = page.cursor;
    if (cursor === undefined) break;
  }

  objects.sort((a, b) => {
    const ta = a.lastModified ?? "";
    const tb = b.lastModified ?? "";
    return tb.localeCompare(ta);
  });

  return json({ objects }, 200, c);
}

async function handleDeleteObject(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);

  const { uid } = await verifyFirebase(token, env.FIREBASE_PROJECT_ID);
  if (!isAdminUid(env, uid)) {
    return json({ error: "forbidden" }, 403, c);
  }

  const url = new URL(request.url);
  const key = url.searchParams.get("key")?.trim();
  if (!key) return json({ error: "missing_key" }, 400, c);

  await env.FILES.delete(key);
  return json({ ok: true }, 200, c);
}

const GEMINI_SYSTEM =
  "당신은 hnde-work 시스템의 AI 비서입니다. 사용자의 업무(4대보험, 자료송수신, 캘린더 등)를 보조하고 시스템 사용법을 친절히 안내하십시오.";

async function handleGeminiChat(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);

  await verifyFirebase(token, env.FIREBASE_PROJECT_ID);

  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey || apiKey.length === 0) {
    return json({ error: "gemini_not_configured" }, 503, c);
  }

  const body = (await request.json()) as { text?: string };
  const userText = body.text?.trim() ?? "";
  if (!userText) return json({ error: "missing_text" }, 400, c);

  const model = (env.GEMINI_MODEL ?? "gemini-2.0-flash").trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const geminiRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: userText }] }],
      systemInstruction: {
        parts: [{ text: GEMINI_SYSTEM }],
      },
    }),
  });

  const raw = (await geminiRes.json()) as Record<string, unknown>;

  if (!geminiRes.ok) {
    return json(
      { error: "gemini_upstream", detail: raw },
      geminiRes.status,
      c
    );
  }

  const candidates = raw["candidates"] as
    | Array<Record<string, unknown>>
    | undefined;
  const first = candidates?.[0];
  const content = first?.["content"] as
    | { parts?: Array<{ text?: string }> }
    | undefined;
  const part = content?.parts?.[0];
  const text = part?.text?.trim();
  if (text) {
    return json({ text }, 200, c);
  }
  return json({ error: "empty_reply" }, 200, c);
}

/** yyyyMMdd (로컬 날짜 — ISO 문자열 파싱 결과 기준) */
function ymdFromDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}${m}${day}`;
}

/** HTTP 200이어도 `resultCode`가 오류이면 본문에 items가 없을 수 있음 (Flutter `_throwIfHeaderError` 와 동일) */
function assertTourApiResultOk(root: Record<string, unknown>): void {
  const response = root["response"];
  if (!response || typeof response !== "object") return;
  const header = (response as Record<string, unknown>)["header"];
  if (!header || typeof header !== "object") return;
  const h = header as Record<string, unknown>;
  const code = String(h["resultCode"] ?? "").trim();
  if (!code || code === "0000") return;
  const msg = String(h["resultMsg"] ?? "").trim();
  throw new Error(`tour_api_error:${code}:${msg}`);
}

function tourBodyTotalCount(body: unknown): number {
  if (!body || typeof body !== "object") return 0;
  const v = (body as Record<string, unknown>)["totalCount"];
  if (typeof v === "number") return v;
  if (typeof v === "string") return parseInt(v, 10) || 0;
  return parseInt(String(v ?? "0"), 10) || 0;
}

function tourItemsFromBody(body: unknown): Record<string, unknown>[] {
  if (!body || typeof body !== "object") return [];
  const items = (body as Record<string, unknown>)["items"];
  if (!items || typeof items !== "object") return [];
  const item = (items as Record<string, unknown>)["item"];
  if (item == null) return [];
  if (Array.isArray(item)) {
    return item.filter((x) => x && typeof x === "object") as Record<
      string,
      unknown
    >[];
  }
  if (typeof item === "object") return [item as Record<string, unknown>];
  return [];
}

function compactFestivalRow(it: Record<string, unknown>): Record<string, unknown> {
  return {
    contentid: it["contentid"] ?? it["contentId"],
    title: it["title"],
    addr1: it["addr1"] ?? it["addr"],
    eventstartdate: it["eventstartdate"] ?? it["eventStartDate"],
    eventenddate: it["eventenddate"] ?? it["eventEndDate"],
    firstimage: it["firstimage"] ?? it["firstImage"],
    mapx: it["mapx"] ?? it["mapX"],
    mapy: it["mapy"] ?? it["mapY"],
  };
}

const tourFetchHeaders: Record<string, string> = {
  Accept: "application/json, application/xml;q=0.9",
  "User-Agent": "Mozilla/5.0 (compatible; HndeWorkTool/1; CloudflareWorker)",
};

/** API 상한 20km 원을 여러 거점에서 호출해 전국 행사를 합칩니다(중복 contentid 제거). */
const FESTIVAL_SEARCH_GRID_KR: ReadonlyArray<{ mapX: number; mapY: number }> = [
  { mapX: 126.978, mapY: 37.5665 }, // 서울
  { mapX: 127.3845, mapY: 36.3504 }, // 대전
  { mapX: 128.6014, mapY: 35.8714 }, // 대구
  { mapX: 129.0756, mapY: 35.1796 }, // 부산
  { mapX: 129.3114, mapY: 35.5384 }, // 울산
  { mapX: 126.8526, mapY: 35.1595 }, // 광주
  { mapX: 127.148, mapY: 35.8242 }, // 전주
  { mapX: 128.8761, mapY: 37.7519 }, // 강릉
  { mapX: 126.7052, mapY: 37.4563 }, // 인천
  { mapX: 126.5312, mapY: 33.4996 }, // 제주
];

async function tourFetchText(url: string): Promise<{ status: number; text: string }> {
  let r = await fetch(url, { headers: tourFetchHeaders });
  let text = await r.text();
  if (r.status === 500 || r.status === 502 || r.status === 503) {
    await new Promise<void>((resolve) => setTimeout(resolve, 800));
    r = await fetch(url, { headers: tourFetchHeaders });
    text = await r.text();
  }
  return { status: r.status, text };
}

/** 한 거점·반경에 대해 searchFestival2 페이지를 모읍니다. */
async function fetchSearchFestival2AtPoint(
  sk: string,
  eventStart: string,
  eventEnd: string,
  mapX: number,
  mapY: number,
  radiusM: number
): Promise<Record<string, unknown>[]> {
  const rClamped = Math.min(Math.max(Math.round(radiusM), 500), 20000);
  const all: Record<string, unknown>[] = [];
  const seen = new Set<string>();
  for (let pageNo = 1; pageNo <= 50; pageNo++) {
    const qp = new URLSearchParams();
    qp.set("eventStartDate", eventStart);
    qp.set("eventEndDate", eventEnd);
    qp.set("mapX", String(mapX));
    qp.set("mapY", String(mapY));
    qp.set("radius", String(rClamped));
    qp.set("_type", "json");
    qp.set("MobileOS", "ETC");
    qp.set("MobileApp", "HndeWorkTool");
    qp.set("arrange", "E");
    qp.set("numOfRows", "100");
    qp.set("pageNo", String(pageNo));

    const incoming = new URL("https://x/");
    incoming.search = qp.toString();
    const qs = buildTourUpstreamSearch(incoming, sk);
    const upstream = new URL(
      `https://apis.data.go.kr/B551011/KorService2/searchFestival2?${qs}`
    );
    const { status, text } = await tourFetchText(upstream.toString());
    if (status < 200 || status >= 300) {
      throw new Error(`tour_upstream ${status}: ${text.slice(0, 500)}`);
    }
    let root: Record<string, unknown>;
    try {
      root = JSON.parse(text) as Record<string, unknown>;
    } catch {
      throw new Error("tour_bad_json");
    }
    assertTourApiResultOk(root);
    const body = (root["response"] as Record<string, unknown> | undefined)?.[
      "body"
    ];
    const batch = tourItemsFromBody(body);
    if (batch.length === 0) break;
    for (const row of batch) {
      const id = String(row["contentid"] ?? row["contentId"] ?? "").trim();
      if (id && !seen.has(id)) {
        seen.add(id);
        all.push(row);
      }
    }
    const total = tourBodyTotalCount(body);
    if (batch.length < 100) break;
    if (total > 0 && all.length >= total) break;
  }
  return all;
}

/**
 * 문화의 날 수집: 기본은 전국 격자(여러 거점×20km) 병합.
 * `nationwide === false` 이면 단일 (mapX,mapY,radius) 만 사용.
 */
async function fetchSearchFestival2All(
  env: Env,
  eventStart: string,
  eventEnd: string,
  mapX: number,
  mapY: number,
  radius: number,
  nationwide: boolean
): Promise<Record<string, unknown>[]> {
  const sk = env.TOUR_API_SERVICE_KEY?.trim();
  if (!sk) {
    throw new Error("tour_not_configured");
  }
  const rSingle = Math.min(Math.max(Math.round(radius), 500), 20000);
  const centers = nationwide
    ? FESTIVAL_SEARCH_GRID_KR
    : [{ mapX, mapY }];
  const radiusEach = nationwide ? 20000 : rSingle;

  const merged: Record<string, unknown>[] = [];
  const seenGlobal = new Set<string>();
  for (const c of centers) {
    const part = await fetchSearchFestival2AtPoint(
      sk,
      eventStart,
      eventEnd,
      c.mapX,
      c.mapY,
      radiusEach
    );
    for (const row of part) {
      const id = String(row["contentid"] ?? row["contentId"] ?? "").trim();
      if (id && !seenGlobal.has(id)) {
        seenGlobal.add(id);
        merged.push(row);
      }
    }
  }
  return merged;
}

function extractJsonObject(text: string): Record<string, unknown> {
  const t = text.trim();
  const fenced = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced ? fenced[1]!.trim() : t;
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start < 0 || end <= start) {
    throw new Error("gemini_no_json_object");
  }
  const slice = body.slice(start, end + 1);
  return JSON.parse(slice) as Record<string, unknown>;
}

async function geminiGenerateJson(
  env: Env,
  userPrompt: string,
  systemPrompt: string
): Promise<Record<string, unknown>> {
  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey || apiKey.length === 0) {
    throw new Error("gemini_not_configured");
  }
  const model = (env.GEMINI_MODEL ?? "gemini-2.0-flash").trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const geminiRes = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: userPrompt }] }],
      systemInstruction: { parts: [{ text: systemPrompt }] },
    }),
  });
  const raw = (await geminiRes.json()) as Record<string, unknown>;
  if (!geminiRes.ok) {
    throw new Error(`gemini_upstream: ${JSON.stringify(raw).slice(0, 800)}`);
  }
  const candidates = raw["candidates"] as
    | Array<Record<string, unknown>>
    | undefined;
  const first = candidates?.[0];
  const content = first?.["content"] as
    | { parts?: Array<{ text?: string }> }
    | undefined;
  const part = content?.parts?.[0];
  const text = part?.text?.trim();
  if (!text) {
    throw new Error("gemini_empty_reply");
  }
  return extractJsonObject(text);
}

const CULTURE_DAY_SYSTEM = `당신은 한국 관광공사 TourAPI(KorService2) 축제·행사 데이터 검수자입니다.
입력은 **공공 API searchFestival2 원본**만 사용합니다. 외부 웹 검색·추측으로 행사를 **새로 만들지 마세요**.
반드시 **유효한 JSON 한 덩어리만** 출력합니다. 코드블록·설명·마크다운 금지.
스키마: {"items":[{"id":"문자열(고유)","title":"...","summary":"한국어 짧은 요약","venue":"장소","region":"지역","startDate":"yyyyMMdd","endDate":"yyyyMMdd","imageUrl":null 또는 https,"detailUrl":null 또는 공식 URL,"tags":["선택"]}]}
id는 반드시 원본 행의 contentid 문자열과 동일하게 쓰세요.
관리자 지시에 맞지 않는 항목·중복·명백한 오류만 제거·정리하고, 나머지는 원본 필드를 최대한 보존하세요.
imageUrl은 Tour의 firstimage 등이 https/http이면 그대로 두고, 없으면 null.`;

async function handleCultureDayGenerate(
  request: Request,
  env: Env,
  c: HeadersInit
): Promise<Response> {
  const token = parseBearer(request);
  if (!token) return json({ error: "unauthorized" }, 401, c);
  const { uid } = await verifyFirebase(token, env.FIREBASE_PROJECT_ID);
  if (!isAdminUid(env, uid)) {
    return json({ error: "forbidden" }, 403, c);
  }

  let body: {
    monthKey?: string;
    periodStart?: string;
    periodEnd?: string;
    instruction?: string;
    mapX?: number;
    mapY?: number;
    radius?: number;
    /** 기본 true: 전국 여러 거점×20km 병합. false면 mapX/mapY/radius 단일 원만 */
    nationwide?: boolean;
  };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return json({ error: "bad_json" }, 400, c);
  }

  const monthKey = body.monthKey?.trim();
  if (!monthKey || !/^\d{4}-\d{2}$/.test(monthKey)) {
    return json({ error: "bad_monthKey" }, 400, c);
  }
  const ps = body.periodStart?.trim();
  const pe = body.periodEnd?.trim();
  if (!ps || !pe) {
    return json({ error: "missing_period" }, 400, c);
  }
  const d0 = new Date(ps);
  const d1 = new Date(pe);
  if (Number.isNaN(d0.getTime()) || Number.isNaN(d1.getTime())) {
    return json({ error: "bad_period" }, 400, c);
  }

  const mapX = body.mapX ?? 126.978;
  const mapY = body.mapY ?? 37.5665;
  const radius = body.radius ?? 20000;
  const nationwide = body.nationwide !== false;
  const instruction = (body.instruction ?? "").trim();

  try {
    const eventStart = ymdFromDate(d0);
    const eventEnd = ymdFromDate(d1);

    const rawRows = await fetchSearchFestival2All(
      env,
      eventStart,
      eventEnd,
      mapX,
      mapY,
      radius,
      nationwide
    );
    const compact = rawRows.map(compactFestivalRow);
    const tourJson = JSON.stringify(compact);
    const tourCapped =
      tourJson.length > 100000
        ? tourJson.slice(0, 100000) + "…(truncated)"
        : tourJson;

    const areaDesc = nationwide
      ? `수집 범위: 전국 ${FESTIVAL_SEARCH_GRID_KR.length}거점 각 반경 20km 결과를 합침(중복 contentid 제거). UI참고 좌표: mapX=${mapX}, mapY=${mapY}.`
      : `수집 범위: 단일 원 mapX=${mapX}, mapY=${mapY}, 반경 ${Math.min(Math.max(Math.round(radius), 500), 20000)}m.`;
    const userPrompt = `관리자 지시:\n${instruction || "(없음)"}\n\n대상 월(번들 id): ${monthKey}\n기간(검색): ${eventStart} ~ ${eventEnd}\n${areaDesc}\n\n아래는 한국관광공사 KorService2 **searchFestival2**로만 수집한 행사 목록(JSON 배열)입니다.\n외부 정보를 추가하지 말고, 지시에 따라 필터·중복 제거·요약만 하여 스키마의 items를 채우세요.\n\n${tourCapped.length > 2 ? tourCapped : "[]"}`;

    const parsed = await geminiGenerateJson(env, userPrompt, CULTURE_DAY_SYSTEM);
    const items = parsed["items"];
    if (!Array.isArray(items)) {
      return json({ error: "gemini_bad_shape", detail: parsed }, 502, c);
    }

    return json(
      {
        items,
        meta: {
          monthKey,
          tourRawCount: rawRows.length,
          compactSentChars: tourCapped.length,
          period: { eventStart, eventEnd, mapX, mapY, radius },
          nationwide,
          gridPoints: nationwide ? FESTIVAL_SEARCH_GRID_KR.length : 1,
          model: (env.GEMINI_MODEL ?? "gemini-2.0-flash").trim(),
        },
      },
      200,
      c
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: "culture_day_generate_failed", message: msg }, 502, c);
  }
}
