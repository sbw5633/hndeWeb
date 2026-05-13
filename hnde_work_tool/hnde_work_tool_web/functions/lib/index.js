import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
admin.initializeApp();
const db = admin.firestore();
const APP_ID = "hnde-work-web";
const ARTIFACTS = db.collection("artifacts").doc(APP_ID);
function usersCol() {
    return ARTIFACTS.collection("users");
}
function publicDataDoc() {
    return ARTIFACTS.collection("public").doc("data");
}
function publicCol(name) {
    return publicDataDoc().collection(name);
}
function userNotifCol(uid) {
    return usersCol().doc(uid).collection("notifications");
}
function buildNotif(params) {
    return {
        type: params.type,
        title: params.title,
        body: params.body,
        payload: params.payload ?? {},
        audience: params.audience ?? {},
        dedupeKey: params.dedupeKey ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readAt: null,
    };
}
async function listUsersByBranches(branchNames) {
    const branches = [...new Set(branchNames.map((b) => (b ?? "").trim()).filter(Boolean))];
    if (branches.length === 0)
        return [];
    // users/{uid} 문서에 branchName 또는 branch가 들어있다고 가정 (클라 저장 로직 기준)
    const uids = new Set();
    for (const b of branches) {
        const snap = await usersCol().where("branchName", "==", b).get();
        snap.docs.forEach((d) => uids.add(d.id));
        const snap2 = await usersCol().where("branch", "==", b).get();
        snap2.docs.forEach((d) => uids.add(d.id));
    }
    return [...uids];
}
async function fanoutToUsers(uids, doc) {
    const list = [...new Set(uids.map((u) => (u ?? "").trim()).filter(Boolean))];
    if (list.length === 0)
        return;
    const chunks = [];
    for (let i = 0; i < list.length; i += 450)
        chunks.push(list.slice(i, i + 450));
    for (const chunk of chunks) {
        const batch = db.batch();
        for (const uid of chunk) {
            batch.set(userNotifCol(uid).doc(), doc);
        }
        await batch.commit();
    }
}
// 1) 공지사항 등록 알림 (posts 생성)
// 요구: 공지는 "사업소 지정"이 필요. 필드명은 우선 branchNames(string[])로 가정.
export const onNoticeCreated = onDocumentCreated("artifacts/{appId}/public/data/posts/{postId}", async (event) => {
    const appId = event.params.appId;
    if (appId !== APP_ID)
        return;
    const data = event.data?.data();
    if (!data)
        return;
    const boardType = data["boardType"] ?? "";
    if (boardType !== "notice")
        return;
    const postId = event.params.postId;
    const title = (data["title"] ?? "").trim();
    const body = (data["body"] ?? "").trim();
    const branches = data["branchNames"] ?? [];
    const branchNames = branches.map((x) => String(x ?? "").trim()).filter(Boolean);
    const uids = await listUsersByBranches(branchNames);
    await fanoutToUsers(uids, buildNotif({
        type: "notice_created",
        title: title ? `공지: ${title}` : "새 공지사항",
        body: body ? (body.length > 120 ? `${body.slice(0, 120)}…` : body) : "공지사항이 등록되었습니다.",
        audience: { branchNames },
        payload: { boardType, postId },
        dedupeKey: `notice:${postId}`,
    }));
});
// 2) 자료송수신 등록 알림 (submissions 생성)
export const onSubmissionCreated = onDocumentCreated("artifacts/{appId}/public/data/submissions/{subId}", async (event) => {
    const appId = event.params.appId;
    if (appId !== APP_ID)
        return;
    const data = event.data?.data();
    if (!data)
        return;
    const subId = event.params.subId;
    const title = (data["title"] ?? "").trim();
    const dueAt = data["dueAt"];
    // sites 서브컬렉션에 대상 사업소 문서가 생긴다고 가정
    const sites = await publicCol("submissions").doc(subId).collection("sites").get();
    const branchNames = sites.docs.map((d) => (d.data()["label"] ?? d.id).trim()).filter(Boolean);
    const uids = await listUsersByBranches(branchNames);
    await fanoutToUsers(uids, buildNotif({
        type: "submission_created",
        title: title ? `자료 요청: ${title}` : "새 자료 요청",
        body: dueAt ? `마감: ${dueAt.toDate().toLocaleString("ko-KR")}` : "자료송수신 요청이 등록되었습니다.",
        audience: { branchNames },
        payload: { submissionId: subId },
        dedupeKey: `submission_created:${subId}`,
    }));
});
// 3) 댓글 등록 알림 (posts/{postId}/comments 생성)
export const onPostCommentCreated = onDocumentCreated("artifacts/{appId}/public/data/posts/{postId}/comments/{commentId}", async (event) => {
    const appId = event.params.appId;
    if (appId !== APP_ID)
        return;
    const data = event.data?.data();
    if (!data)
        return;
    const postId = event.params.postId;
    const commentId = event.params.commentId;
    const authorUid = (data["authorUid"] ?? "").trim();
    const body = (data["body"] ?? "").trim();
    const boardType = (data["boardType"] ?? "").trim();
    // 게시글 작성자 uid는 posts 문서에서 읽는다
    const postSnap = await publicCol("posts").doc(postId).get();
    const post = (postSnap.data() ?? {});
    const postAuthorUid = (post["authorUid"] ?? "").trim();
    const postTitle = (post["title"] ?? "").trim();
    // 기존 댓글 참여자(작성자들)
    const commentsSnap = await publicCol("posts").doc(postId).collection("comments").get();
    const participants = new Set();
    commentsSnap.docs.forEach((d) => {
        const du = (d.data()["authorUid"] ?? "").trim();
        if (du)
            participants.add(du);
    });
    if (postAuthorUid)
        participants.add(postAuthorUid);
    if (authorUid)
        participants.delete(authorUid); // 본인 제외
    const uids = [...participants];
    await fanoutToUsers(uids, buildNotif({
        type: "post_commented",
        title: postTitle ? `댓글: ${postTitle}` : "새 댓글",
        body: body ? (body.length > 120 ? `${body.slice(0, 120)}…` : body) : "댓글이 등록되었습니다.",
        payload: { boardType, postId, commentId },
        dedupeKey: `comment:${postId}:${commentId}`,
    }));
});
// 4) 소속변경 승인/반려 알림 (프로필 main 업데이트)
export const onProfileUpdated = onDocumentUpdated("artifacts/{appId}/users/{uid}/profile/main", async (event) => {
    const appId = event.params.appId;
    if (appId !== APP_ID)
        return;
    const uid = event.params.uid;
    const before = (event.data?.before.data() ?? {});
    const after = (event.data?.after.data() ?? {});
    const bStatus = before["pendingBranchStatus"] ?? "";
    const aStatus = after["pendingBranchStatus"] ?? "";
    if (!aStatus || aStatus === bStatus)
        return;
    if (aStatus !== "approved" && aStatus !== "rejected")
        return;
    const pendingBranch = (after["pendingBranch"] ?? "").trim();
    await fanoutToUsers([uid], buildNotif({
        type: "branch_change_decided",
        title: aStatus === "approved" ? "소속 변경 승인" : "소속 변경 반려",
        body: pendingBranch ? `요청 소속: ${pendingBranch}` : "요청 결과가 업데이트되었습니다.",
        payload: { status: aStatus, pendingBranch },
        dedupeKey: `branch_change:${uid}:${aStatus}:${pendingBranch}`,
    }));
});
// 5) 마감 임박 알림(스케줄): 제출하지 않은 사이트들
// submissionSites 문서에 `status: pending|submitted` 와 `dueAt`(submission에 있을 수 있음) 가 있다고 가정.
export const submissionDueSoon = onSchedule("every 10 minutes", async () => {
    const now = Date.now();
    const soonMs = 60 * 60 * 1000; // 1시간
    const subs = await publicCol("submissions").get();
    for (const sub of subs.docs) {
        const subId = sub.id;
        const d = (sub.data() ?? {});
        const dueAt = d["dueAt"];
        if (!dueAt)
            continue;
        const dueMs = dueAt.toMillis();
        const diff = dueMs - now;
        if (diff < 0 || diff > soonMs)
            continue;
        const title = (d["title"] ?? "").trim();
        const sites = await publicCol("submissions").doc(subId).collection("sites").get();
        const pendingBranches = [];
        for (const site of sites.docs) {
            const sd = site.data();
            const status = (sd["status"] ?? "pending").trim();
            if (status !== "pending")
                continue;
            const label = (sd["label"] ?? site.id).trim();
            if (label)
                pendingBranches.push(label);
        }
        if (pendingBranches.length === 0)
            continue;
        const uids = await listUsersByBranches(pendingBranches);
        await fanoutToUsers(uids, buildNotif({
            type: "submission_due_soon",
            title: title ? `마감 임박: ${title}` : "자료 제출 마감 임박",
            body: `마감 1시간 이내입니다. (${dueAt.toDate().toLocaleString("ko-KR")})`,
            audience: { branchNames: pendingBranches },
            payload: { submissionId: subId, dueAtMs: dueMs },
            dedupeKey: `dueSoon:${subId}:${Math.floor(dueMs / soonMs)}`, // 시간 윈도우당 1회 정도
        }));
    }
});
