import {
  getStoreAppByPackage,
  getStoreAppById,
  getStoreAppsByDeveloper,
  getAllStoreApps,
  createStoreApp,
  setAppRepoVerified,
  setAppSigningKeyHash,
  setAppTrustLevel,
  setAppStatus,
  setAppCategory,
  setAppImages,
  createSubmission,
  getSubmissionById,
  getSubmissionsByApp,
  getSubmissionsByDeveloper,
  getSubmissionsByStatus,
  advanceSubmissionToScan,
  markSubmissionScanning,
  recordScanResult,
  approveSubmission,
  rejectSubmission,
  cancelSubmission,
  getSubmissionsDueForAutoApproval,
  SUBMISSION_STATUS,
  APP_STATUS,
  TRUST_LEVEL,
} from "./store_db.js";

import {
  getIndex,
  putIndex,
  addOrUpdateApp,
  addVersionToApp,
  removeApp,
  getPresignedStagingUploadUrl,
  getPresignedDownloadUrl,
  getPresignedImageUploadUrl,
  publicImageUrl,
  headStagingObject,
  copyToProduction,
  copyStagingToProduction,
  putImageObject,
  deleteStagingApk,
  apkKey,
  stagingKey,
  imageKey,
  IMAGE_SLOTS,
  CATEGORIES,
} from "./storage.js";

import { handleRatingsRoute, handleAdminRatingsRoute } from "./modules/ratings.js";
import { runGitHubBootstrapImport } from "./modules/git_store_job.js";

export { runGitHubBootstrapImport };

const nowUnix = () => Math.floor(Date.now() / 1000);

const cryptoRandomHex = (bytes) => {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
};

const corsHeaders = {
  "access-control-allow-origin":  "*",
  "access-control-allow-methods": "GET,POST,DELETE,OPTIONS",
  "access-control-allow-headers": "authorization,content-type,x-vps-auth",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...corsHeaders },
  });

const readJson = async (req) => {
  const ct = req.headers.get("content-type") || "";
  if (!ct.toLowerCase().includes("application/json")) return null;
  try { return await req.json(); } catch { return null; }
};

const unauthorized = () => json({ error: "unauthorized" }, 401);
const forbidden    = () => json({ error: "forbidden" }, 403);
const badRequest   = (msg = "bad_request") => json({ error: msg }, 400);
const notFound     = () => json({ error: "not_found" }, 404);

const isScannerAuth = (env, request) => {
  const provided = (request.headers.get("x-vps-auth") || "").trim();
  const secret   = (env.SH_SCANNER_SECRET || "").trim();
  return !!(provided && secret && provided === secret);
};

const REPO_VERIFY_FILE = ".safehaven";
const COMMUNITY_DEVELOPER_ID = "safehaven-community";

const buildRawFileUrl = (repoUrl) => {
  const url = (repoUrl || "").toString().trim().replace(/\/$/, "").replace(/\.git$/, "");
  const gh  = url.match(/^https?:\/\/github\.com\/([^/]+\/[^/]+)$/);
  if (gh) return `https://raw.githubusercontent.com/${gh[1]}/HEAD/${REPO_VERIFY_FILE}`;
  const gl  = url.match(/^https?:\/\/gitlab\.com\/([^/]+\/[^/]+)$/);
  if (gl) return `https://gitlab.com/${gl[1]}/-/raw/main/${REPO_VERIFY_FILE}`;
  return null;
};

const parseScreenshots = (json) => {
  if (!json) return [];
  try { return JSON.parse(json); } catch { return []; }
};

const normalizeStoreText = (value) => {
  if (value === null || value === undefined) return null;

  const clean = value
    .toString()
    .replace(/\\r\\n/g, "\n")
    .replace(/\\n/g, "\n")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n[ \t]+/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  return clean || null;
};

const buildAppEntry = (env, app) => ({
  packageName:  app.package_name,
  name:         app.name,
  summary:      normalizeStoreText(app.summary),
  description:  normalizeStoreText(app.description),
  repoUrl:      app.repo_url,
  trustLevel:   app.trust_level,
  category:     app.category    || null,
  iconUrl:      app.icon_key ? publicImageUrl(env, app.icon_key) : null,
  screenshots:  parseScreenshots(app.screenshots_json).map((k) => publicImageUrl(env, k)),
});

const buildVersionEntry = (submission) => ({
  versionName: submission.version_name,
  versionCode: submission.version_code,
  apkPath:     apkKey(submission.package_name, submission.version_code),
  apkSize:     submission.apk_size   || null,
  sha256:      submission.apk_sha256 || null,
  scannedAt:   submission.scanned_at || null,
  added:       submission.submitted_at,
});

const approveAndPublish = async (env, submission, reviewedBy = null) => {
  const { id, version_code, app_id } = submission;

  const app = await getStoreAppById(env, app_id);
  if (!app) throw new Error("app_not_found");

  const finalPackageName = (app.package_name || submission.package_name || "").toString().trim();
  if (!finalPackageName) throw new Error("package_name_missing");

  await copyStagingToProduction(env, submission.package_name, finalPackageName, version_code);

  const prodKey = apkKey(finalPackageName, version_code);

  await approveSubmission(env, id, prodKey, reviewedBy);
  await deleteStagingApk(env, submission.package_name, version_code);

  const updatedSubmission = {
    ...submission,
    package_name: finalPackageName,
    apk_key:      prodKey,
  };

  const updatedApp = await getStoreAppById(env, app_id);
  if (updatedApp) {
    await addOrUpdateApp(env, buildAppEntry(env, updatedApp));
    await addVersionToApp(env, finalPackageName, buildVersionEntry(updatedSubmission));
  }
};

const setAppSigningFlag = async (env, appId, flag) => {
  await env.api_control_db
    .prepare("UPDATE store_apps SET signing_flag = ?2, updated_at = ?3 WHERE id = ?1")
    .bind((appId || "").toString().trim(), flag, nowUnix())
    .run();
};

const saveScannerIcon = async (env, appId, packageName, body) => {
  const iconBase64  = (body.iconBase64 || "").toString().trim();
  const contentType = (body.iconContentType || "").toString().trim().toLowerCase();

  if (!iconBase64) return;
  if (!["image/png", "image/jpeg", "image/webp"].includes(contentType)) return;

  let bytes;
  try {
    const binary = atob(iconBase64);
    bytes = new Uint8Array(binary.length);

    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
  } catch {
    return;
  }

  if (!bytes.byteLength || bytes.byteLength > 2 * 1024 * 1024) return;

  const iconKey = await putImageObject(env, packageName, "icon", bytes, contentType);

  await setAppImages(env, appId, {
    iconKey,
    screenshotKeys: [],
  });
};


const createUnclaimedStoreApp = async (env, input) => {
  const packageName = (input.packageName || "").toString().trim();
  const name        = (input.name || "").toString().trim();
  const repoUrl     = (input.repoUrl || "").toString().trim();
  const summary     = normalizeStoreText(input.summary);
  const description = normalizeStoreText(input.description);
  const now         = nowUnix();
  if (!packageName || !name || !repoUrl) return null;

  const existing = await env.api_control_db
    .prepare("SELECT id, status FROM store_apps WHERE package_name = ?1 LIMIT 1")
    .bind(packageName)
    .first();

  if (existing) {
    if (existing.status !== APP_STATUS.ACTIVE) {
      await env.api_control_db
        .prepare(
          "UPDATE store_apps SET name = ?2, summary = ?3, description = ?4, repo_url = ?5, status = ?6, auto_tracked = 1, updated_at = ?7 WHERE id = ?1"
        )
        .bind(existing.id, name, summary, description, repoUrl, APP_STATUS.ACTIVE, now)
        .run();
    }
    return existing.id;
  }

  const id = cryptoRandomHex(16);
  await env.api_control_db
    .prepare(
      `INSERT INTO store_apps
        (id, developer_id, package_name, name, summary, description,
         repo_url, repo_token, repo_verified, trust_level, status,
         claimed, auto_tracked, created_at, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, '', 0, 'unverified', ?8, 0, 1, ?9, ?9)`
    )
    .bind(id, COMMUNITY_DEVELOPER_ID, packageName, name, summary, description, repoUrl, APP_STATUS.ACTIVE, now)
    .run();
  return id;
};

const getAppsForRepoPolling = async (env, maxAgeSeconds = 21600) => {
  const cutoff = nowUnix() - maxAgeSeconds;
  const rows = await env.api_control_db
    .prepare(
      `SELECT * FROM store_apps
       WHERE auto_tracked = 1
         AND status = 'active'
         AND (last_repo_check IS NULL OR last_repo_check <= ?1)
       ORDER BY last_repo_check ASC
       LIMIT 50`
    )
    .bind(cutoff)
    .all();
  return rows.results || [];
};

const setAppLastRepoCheck = async (env, appId) => {
  await env.api_control_db
    .prepare("UPDATE store_apps SET last_repo_check = ?2, updated_at = ?2 WHERE id = ?1")
    .bind((appId || "").toString().trim(), nowUnix())
    .run();
};

const setAppClaimed = async (env, appId, developerId) => {
  await env.api_control_db
    .prepare(
      "UPDATE store_apps SET claimed = 1, developer_id = ?2, trust_level = ?3, updated_at = ?4 WHERE id = ?1 AND claimed = 0"
    )
    .bind((appId || "").toString().trim(), developerId, TRUST_LEVEL.VERIFIED_SOURCE, nowUnix())
    .run();
};

const getSubmissionByVersionCode = async (env, appId, versionCode) =>
  env.api_control_db
    .prepare("SELECT * FROM store_submissions WHERE app_id = ?1 AND version_code = ?2 LIMIT 1")
    .bind((appId || "").toString().trim(), versionCode)
    .first();

const deleteSubmissionById = async (env, submissionId) => {
  await env.api_control_db
    .prepare("DELETE FROM store_submissions WHERE id = ?1")
    .bind((submissionId || "").toString().trim())
    .run();
};

const parseGitHubRepo = (repoUrl) => {
  const url = (repoUrl || "").toString().trim().replace(/\/$/, "").replace(/\.git$/, "");
  const m = url.match(/^https?:\/\/github\.com\/([^/]+)\/([^/]+)$/);
  return m ? { owner: m[1], repo: m[2] } : null;
};

const githubLatestRelease = async (owner, repo) => {
  const res = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/releases/latest`,
    { headers: { "user-agent": "SafeHaven-Store/1.0", accept: "application/vnd.github+json" } }
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`github_api_error:${res.status}`);
  const data = await res.json();
  if (data.prerelease || data.draft) return null;
  return data;
};

const findApkAsset = (release) =>
  (release.assets || []).find((a) =>
    a.name.endsWith(".apk") && a.state === "uploaded" && a.browser_download_url
  ) || null;

const tagToVersionCode = (tag) => {
  const raw = (tag || "").toString().trim();
  const clean = raw
    .replace(/^release[-_/]*/i, "")
    .replace(/^version[-_/]*/i, "")
    .replace(/^v/i, "");

  const match = clean.match(/^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-._](\d+))?$/);
  if (!match) return null;

  const major = Number(match[1] || 0);
  const minor = Number(match[2] || 0);
  const patch = Number(match[3] || 0);
  const build = Number(match[4] || 0);

  if (
    !Number.isSafeInteger(major) ||
    !Number.isSafeInteger(minor) ||
    !Number.isSafeInteger(patch) ||
    !Number.isSafeInteger(build)
  ) {
    return null;
  }

  if (major < 0 || minor < 0 || patch < 0 || build < 0) return null;
  if (major > 9999 || minor > 999 || patch > 999 || build > 99) return null;

  return major * 100000000 + minor * 100000 + patch * 100 + build;
};

const uploadBufferToStaging = async (env, packageName, versionCode, buffer) => {
  const url = await getPresignedStagingUploadUrl(env, packageName, versionCode, 300);
  const res = await fetch(url, {
    method:  "PUT",
    headers: { "content-type": "application/vnd.android.package-archive" },
    body:    buffer,
  });
  if (!res.ok) throw new Error(`staging_upload_failed:${res.status}`);
};

const pollAppRepo = async (env, app) => {
  const gh = parseGitHubRepo(app.repo_url);
  if (!gh) { await setAppLastRepoCheck(env, app.id); return; }

  await refreshGitHubMetadataForApp(env, app, gh.owner, gh.repo);

  const release = await githubLatestRelease(gh.owner, gh.repo);
  await setAppLastRepoCheck(env, app.id);
  if (!release) return;

  const asset = findApkAsset(release);
  if (!asset) return;

  const versionCode = tagToVersionCode(release.tag_name);
  if (!versionCode) return;
  const versionName = release.tag_name;

  const existing = await getSubmissionByVersionCode(env, app.id, versionCode);
  if (existing) return;

  const apkRes = await fetch(asset.browser_download_url, {
    headers: { "user-agent": "SafeHaven-Store/1.0" },
  });
  if (!apkRes.ok) throw new Error(`apk_download_failed:${apkRes.status}`);
  const apkBuffer = await apkRes.arrayBuffer();

  await uploadBufferToStaging(env, app.package_name, versionCode, apkBuffer);

  const submissionId = await createSubmission(env, {
    appId:       app.id,
    developerId: COMMUNITY_DEVELOPER_ID,
    packageName: app.package_name,
    versionName,
    versionCode,
    stagingKey:  `staging/${app.package_name}/${versionCode}/app.apk`,
  });

  if (!submissionId) throw new Error("submission_create_failed");
  await advanceSubmissionToScan(env, submissionId);

  console.log(JSON.stringify({
    tag:          "unclaimed_auto_update",
    appId:        app.id,
    packageName:  app.package_name,
    versionCode,
    submissionId,
  }));
};

export async function runUnclaimedRepoPolls(env) {
  const apps    = await getAppsForRepoPolling(env);
  const results = { checked: 0, updated: 0, errors: [] };
  for (const app of apps) {
    results.checked++;
    try {
      await pollAppRepo(env, app);
      results.updated++;
    } catch (e) {
      results.errors.push({ appId: app.id, error: String(e?.message || e) });
    }
  }
  return results;
}

// ── Auto approvals ────────────────────────────────────────────────────────────

export async function runStoreAutoApprovals(env) {
  const due = await getSubmissionsDueForAutoApproval(env);
  for (const submission of due) {
    try {
      await approveAndPublish(env, submission, null);
    } catch (e) {
      console.log(JSON.stringify({
        tag:           "auto_approval_failed",
        submission_id: submission.id,
        error:         String(e?.message || e),
      }));
    }
  }
  return due.length;
}

// ── Main handler ──────────────────────────────────────────────────────────────

export async function handleStore(request, env, auth) {
  const url    = new URL(request.url);
  const path   = url.pathname;
  const method = request.method;

  const getAuthedUser = async () => {
    if (!auth || typeof auth.getUser !== "function") return null;
    return await auth.getUser(request, env);
  };

  const requireUser = async () => {
    const me = await getAuthedUser();
    return me || null;
  };

  const requireDeveloper = async () => {
    const me = await requireUser();
    if (!me) return null;
    if (!me.developerEnabled) return false;
    return me;
  };

  if (method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {

    if (method === "GET" && path === "/store/index.json") {
      const index = await getIndex(env);
      return new Response(JSON.stringify(index), {
        headers: {
          "content-type":  "application/json; charset=utf-8",
          "cache-control": "public, max-age=60",
          ...corsHeaders,
        },
      });
    }

    if (method === "GET" && path.startsWith("/store/catalog/")) {
      const packageName = decodeURIComponent(path.replace("/store/catalog/", "")).trim();
      if (!packageName) return notFound();
      const index = await getIndex(env);
      const app   = index.apps.find((a) => a.packageName === packageName);
      if (!app) return notFound();
      return json(app);
    }

    if (method === "GET" && path.match(/^\/store\/apps\/[^/]+\/download\/[^/]+$/)) {
      const parts       = path.replace("/store/apps/", "").split("/download/");
      const packageName = decodeURIComponent(parts[0] || "").trim();
      const versionCode = Number(parts[1] || "");
      if (!packageName || !Number.isFinite(versionCode)) return badRequest("invalid_params");
      const index = await getIndex(env);
      const app   = index.apps.find((a) => a.packageName === packageName);
      if (!app) return notFound();
      const version = (app.versions ?? []).find((v) => v.versionCode === versionCode);
      if (!version) return notFound();
      const dlUrl = await getPresignedDownloadUrl(env, version.apkPath, 300);
      return json({ url: dlUrl });
    }

    if (method === "GET" && path === "/store/categories") {
      return json({ categories: CATEGORIES });
    }

    if (method === "POST" && path === "/store/apps") {
      const me = await requireDeveloper();
      if (!me) return unauthorized();
      if (me === false) return forbidden();

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const packageName = (body.packageName || "").toString().trim();
      const name        = (body.name        || "").toString().trim();
      const repoUrl     = (body.repoUrl     || "").toString().trim();
      const summary     = normalizeStoreText(body.summary);
      const description = normalizeStoreText(body.description);

      if (!packageName) return badRequest("missing_packageName");
      if (!name)        return badRequest("missing_name");
      if (!repoUrl)     return badRequest("missing_repoUrl");

      if (!/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(packageName)) {
        return badRequest("invalid_packageName");
      }

      const existing = await getStoreAppByPackage(env, packageName);
      if (existing) return json({ error: "package_already_registered" }, 409);

      const result = await createStoreApp(env, {
        developerId: me.id, packageName, name, summary, description, repoUrl,
      });
      if (!result) return json({ error: "create_failed" }, 500);

      return json({ ok: true, appId: result.id, repoToken: result.repoToken }, 201);
    }

    if (method === "GET" && path === "/store/apps") {
      const me = await requireUser();
      if (!me) return unauthorized();
      const apps = await getStoreAppsByDeveloper(env, me.id);
      return json({ apps });
    }

    if (method === "GET" && path === "/internal/store/pending-scans") {
      if (!isScannerAuth(env, request)) return unauthorized();
      const submissions = await getSubmissionsByStatus(env, SUBMISSION_STATUS.PENDING_SCAN);
      const withUrls = await Promise.all(
        submissions.map(async (s) => {
          const app = await getStoreAppById(env, s.app_id);
          return {
            ...s,
            downloadUrl:          await getPresignedDownloadUrl(env, s.staging_key),
            autoTracked:          app ? !!app.auto_tracked : false,
            storedSigningKeyHash: app?.signing_key_hash || null,
          };
        })
      );
      return json({ submissions: withUrls });
    }

    if (method === "GET" && path.match(/^\/store\/apps\/[^/]+$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app) return notFound();
      if (app.developer_id !== me.id && !me.admin) return forbidden();
      const submissions = await getSubmissionsByApp(env, appId);
      return json({ app, submissions });
    }

    if (method === "POST" && path.match(/^\/store\/apps\/[^/]+\/verify-repo$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").replace("/verify-repo", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app)                       return notFound();
      if (app.developer_id !== me.id) return forbidden();

      const rawUrl = buildRawFileUrl(app.repo_url);
      if (!rawUrl) return badRequest("unsupported_repo_host");

      let remoteContent;
      try {
        const res = await fetch(rawUrl, { headers: { "user-agent": "SafeHaven-Verifier/1.0" } });
        if (!res.ok) return json({ ok: false, reason: "file_not_found" }, 422);
        remoteContent = (await res.text()).trim();
      } catch {
        return json({ ok: false, reason: "fetch_failed" }, 422);
      }

      if (remoteContent !== (app.repo_token || "").trim()) {
        return json({ ok: false, reason: "token_mismatch" }, 422);
      }

      await setAppRepoVerified(env, appId, true);
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/store\/apps\/[^/]+\/submit$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").replace("/submit", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app)                             return notFound();
      if (app.developer_id !== me.id)       return forbidden();
      if (!app.repo_verified)               return json({ error: "repo_not_verified" }, 403);
      if (app.status !== APP_STATUS.ACTIVE) return json({ error: "app_not_active" }, 403);

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const versionName = (body.versionName || "").toString().trim();
      const versionCode = Number(body.versionCode);

      if (!versionName)                                      return badRequest("missing_versionName");
      if (!Number.isFinite(versionCode) || versionCode < 1) return badRequest("invalid_versionCode");

      const existingSubmissions = await getSubmissionsByApp(env, appId);
      const existingVersion     = existingSubmissions.find((s) => Number(s.version_code) === versionCode);

      if (existingVersion) {
        if (existingVersion.status === SUBMISSION_STATUS.PENDING_UPLOAD) {
          const uploadUrl = await getPresignedStagingUploadUrl(env, app.package_name, versionCode);
          return json({ ok: true, resumed: true, submissionId: existingVersion.id, uploadUrl }, 200);
        }
        return json({
          error:        "version_code_already_submitted",
          submissionId: existingVersion.id,
          status:       existingVersion.status,
        }, 409);
      }

      const submissionId = await createSubmission(env, {
        appId,
        developerId: me.id,
        packageName: app.package_name,
        versionName,
        versionCode,
        stagingKey:  stagingKey(app.package_name, versionCode),
      });
      if (!submissionId) return json({ error: "submission_failed" }, 500);

      const uploadUrl = await getPresignedStagingUploadUrl(env, app.package_name, versionCode);
      return json({ ok: true, submissionId, uploadUrl }, 201);
    }

    if (method === "POST" && path.match(/^\/store\/apps\/[^/]+\/image-upload-urls$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").replace("/image-upload-urls", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app)                       return notFound();
      if (app.developer_id !== me.id && app.developer_id !== COMMUNITY_DEVELOPER_ID && !me.admin) return forbidden();

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const requestedSlots = Array.isArray(body.slots) ? body.slots : [];
      const validSlots     = requestedSlots.filter((s) => IMAGE_SLOTS.includes(s));
      if (!validSlots.length) return badRequest("no_valid_slots");

      const urls = {};
      for (const slot of validSlots) {
        urls[slot] = await getPresignedImageUploadUrl(env, app.package_name, slot);
      }
      return json({ ok: true, urls });
    }

    if (method === "POST" && path.match(/^\/store\/apps\/[^/]+\/images$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").replace("/images", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app)                       return notFound();
      if (app.developer_id !== me.id && app.developer_id !== COMMUNITY_DEVELOPER_ID && !me.admin) return forbidden();

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const iconUploaded    = !!body.iconUploaded;
      const screenshotSlots = Array.isArray(body.screenshotSlots)
        ? body.screenshotSlots.map(Number).filter((n) => Number.isInteger(n) && n >= 1 && n <= 6)
        : [];

      const newIconKey          = iconUploaded ? imageKey(app.package_name, "icon") : (app.icon_key || null);
      const existingScreenshots = parseScreenshots(app.screenshots_json);
      const newScreenshotKeys   = screenshotSlots.length
        ? screenshotSlots.map((n) => imageKey(app.package_name, `screenshot_${n}`))
        : existingScreenshots;

      await setAppImages(env, appId, { iconKey: newIconKey, screenshotKeys: newScreenshotKeys });

      const updatedApp = await getStoreAppById(env, appId);
      if (updatedApp && updatedApp.status === APP_STATUS.ACTIVE) {
        await addOrUpdateApp(env, buildAppEntry(env, updatedApp));
      }
      return json({ ok: true });
    }

    if (method === "DELETE" && path.match(/^\/store\/submissions\/[^/]+$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const submissionId = path.replace("/store/submissions/", "").trim();
      const submission   = await getSubmissionById(env, submissionId);
      if (!submission) return notFound();
      if (submission.developer_id !== me.id) return forbidden();
      if (submission.status !== SUBMISSION_STATUS.PENDING_UPLOAD) return json({ error: "not_cancellable" }, 409);
      await cancelSubmission(env, submissionId);
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/store\/submissions\/[^/]+\/confirm-upload$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const submissionId = path.replace("/store/submissions/", "").replace("/confirm-upload", "").trim();
      const submission   = await getSubmissionById(env, submissionId);
      if (!submission)                       return notFound();
      if (submission.developer_id !== me.id) return forbidden();
      if (submission.status !== SUBMISSION_STATUS.PENDING_UPLOAD) {
        return json({ error: "invalid_status" }, 409);
      }

      await advanceSubmissionToScan(env, submissionId);
      return json({ ok: true });
    }

    if (method === "GET" && path.match(/^\/store\/submissions\/[^/]+$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const submissionId = path.replace("/store/submissions/", "").trim();
      const submission   = await getSubmissionById(env, submissionId);
      if (!submission) return notFound();
      if (submission.developer_id !== me.id && !me.admin) return forbidden();
      return json({ submission });
    }

    if (method === "POST" && path === "/internal/store/scan-result") {
      if (!isScannerAuth(env, request)) return unauthorized();

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const submissionId = (body.submissionId || "").toString().trim();
      if (!submissionId) return badRequest("missing_submissionId");

      const submission = await getSubmissionById(env, submissionId);
      if (!submission) return notFound();

      if (
        submission.status !== SUBMISSION_STATUS.PENDING_SCAN &&
        submission.status !== SUBMISSION_STATUS.SCANNING
      ) {
        return json({ error: "invalid_status" }, 409);
      }

      await markSubmissionScanning(env, submissionId);
      await recordScanResult(env, submissionId, {
        passed:    !!body.passed,
        detail:    body.detail    || null,
        apkSha256: body.apkSha256 || null,
        apkSize:   body.apkSize   || null,
      });

      if (body.signingKeyHash) {
        const app = await getStoreAppById(env, submission.app_id);
        if (app && !app.signing_key_hash) {
          await setAppSigningKeyHash(env, submission.app_id, body.signingKeyHash);
        }
        if (app && app.auto_tracked && !body.passed) {
          const detail = body.detail || {};
          if (detail.verdict === "signing_key_changed") {
            await setAppSigningFlag(env, submission.app_id, "signing_key_changed");
          }
        }
      }

      {
        const observedPkg = (body.packageName || "").toString().trim();
        const appForPkg   = await getStoreAppById(env, submission.app_id);

        if (appForPkg) {
          let finalPackageName = (appForPkg.package_name || "").toString().trim();

          if (observedPkg) {
            const isPlaceholder = !finalPackageName || finalPackageName.startsWith("pending.");
            const isCommunityImport = appForPkg.developer_id === COMMUNITY_DEVELOPER_ID || Number(appForPkg.auto_tracked || 0) === 1;

            if (isPlaceholder && isCommunityImport) {
              await env.api_control_db
                .prepare("UPDATE store_apps SET package_name = ?2, updated_at = ?3 WHERE id = ?1")
                .bind(appForPkg.id, observedPkg, nowUnix())
                .run();

              finalPackageName = observedPkg;
            } else if (finalPackageName && observedPkg !== finalPackageName) {
              await rejectSubmission(env, submissionId, "package_name_mismatch", null);

              return json({
                ok: false,
                error: "package_name_mismatch",
                expectedPackageName: finalPackageName,
                observedPackageName: observedPkg,
              }, 409);
            }
          }

          if (finalPackageName) {
            await saveScannerIcon(env, submission.app_id, finalPackageName, body);
          }
        }
      }

      return json({ ok: true });
    }

    if (method === "GET" && path === "/admin/store/submissions") {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();
      const statusFilter = url.searchParams.get("status") || SUBMISSION_STATUS.PENDING_REVIEW;
      const submissions  = await getSubmissionsByStatus(env, statusFilter);
      return json({ submissions });
    }

    if (method === "GET" && path === "/admin/store/apps") {
      const me = await requireUser();
      if (!me)       return unauthorized();
      if (!me.admin) return forbidden();
      const apps = await getAllStoreApps(env);
      return json({ apps });
    }

        if (method === "POST" && path === "/admin/store/clear-index") {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();

      await putIndex(env, {
        version: 1,
        timestamp: nowUnix(),
        categories: CATEGORIES,
        apps: [],
      });

      return json({ ok: true, cleared: true });
    }

    if (method === "POST" && path === "/admin/store/bootstrap-import") {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();

      const result = await runGitHubBootstrapImport(env);
      return json({ ok: true, result });
    }

    if (method === "POST" && path.match(/^\/admin\/store\/submissions\/[^/]+\/approve$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();
      const submissionId = path.replace("/admin/store/submissions/", "").replace("/approve", "").trim();
      const submission   = await getSubmissionById(env, submissionId);
      if (!submission) return notFound();
      if (submission.status !== SUBMISSION_STATUS.PENDING_REVIEW) {
        return json({ error: "invalid_status" }, 409);
      }
      await approveAndPublish(env, submission, me.id);
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/admin\/store\/submissions\/[^/]+\/reject$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();
      const submissionId = path.replace("/admin/store/submissions/", "").replace("/reject", "").trim();
      const submission   = await getSubmissionById(env, submissionId);
      if (!submission) return notFound();
      const body   = await readJson(request);
      const reason = (body?.reason || "").toString().trim() || null;
      await rejectSubmission(env, submissionId, reason, me.id);
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/admin\/store\/apps\/[^/]+\/trust-level$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();
      const appId      = path.replace("/admin/store/apps/", "").replace("/trust-level", "").trim();
      const body       = await readJson(request);
      if (!body) return badRequest("json_required");
      const trustLevel = body.trustLevel === null
        ? null
        : (body.trustLevel || "").toString().trim();

      if (trustLevel !== null && !Object.values(TRUST_LEVEL).includes(trustLevel)) {
        return badRequest("invalid_trustLevel");
      }
      const app = await getStoreAppById(env, appId);
      if (!app) return notFound();
      await setAppTrustLevel(env, appId, trustLevel);
      if (app.status === APP_STATUS.ACTIVE) {
        await addOrUpdateApp(env, { ...buildAppEntry(env, app), trustLevel });
      }
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/admin\/store\/apps\/[^/]+\/status$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.admin) return forbidden();

      const appId = path.replace("/admin/store/apps/", "").replace("/status", "").trim();
      const body  = await readJson(request);
      if (!body) return badRequest("json_required");

      const status = (body.status || "").toString().trim();
      if (!Object.values(APP_STATUS).includes(status)) return badRequest("invalid_status");

      const app = await getStoreAppById(env, appId);
      if (!app) return notFound();

      if (status === APP_STATUS.REMOVED) {
        await removeApp(env, app.package_name);

        await env.api_control_db
          .prepare("DELETE FROM store_submissions WHERE app_id = ?1")
          .bind(appId)
          .run();

        await env.api_control_db
          .prepare("DELETE FROM store_apps WHERE id = ?1")
          .bind(appId)
          .run();

        return json({ ok: true, removed: true });
      }

      await setAppStatus(env, appId, status);

      if (status === APP_STATUS.SUSPENDED) {
        await removeApp(env, app.package_name);
      }

      if (status === APP_STATUS.ACTIVE) {
        const updatedApp = await getStoreAppById(env, appId);
        if (updatedApp) {
          await addOrUpdateApp(env, buildAppEntry(env, updatedApp));
        }
      }

      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/store\/apps\/[^/]+\/category$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      const appId = path.replace("/store/apps/", "").replace("/category", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app) return notFound();
      if (app.developer_id !== me.id) return forbidden();
      const body = await readJson(request);
      if (!body) return badRequest("json_required");
      const category = (body.category || "").toString().trim() || null;
      if (category && !Object.keys(CATEGORIES).includes(category)) return badRequest("invalid_category");
      await setAppCategory(env, appId, category);
      if (app.status === APP_STATUS.ACTIVE) {
        await addOrUpdateApp(env, { ...buildAppEntry(env, app), category });
      }
      return json({ ok: true });
    }

    if (method === "POST" && path.match(/^\/admin\/store\/apps\/[^/]+\/category$/)) {
      const me = await requireUser();
      if (!me)       return unauthorized();
      if (!me.admin) return forbidden();
      const appId    = path.replace("/admin/store/apps/", "").replace("/category", "").trim();
      const body     = await readJson(request);
      if (!body) return badRequest("json_required");
      const category = (body.category || "").toString().trim() || null;
      if (category && !Object.keys(CATEGORIES).includes(category)) return badRequest("invalid_category");
      const app = await getStoreAppById(env, appId);
      if (!app) return notFound();
      await setAppCategory(env, appId, category);
      if (app.status === APP_STATUS.ACTIVE) {
        await addOrUpdateApp(env, { ...buildAppEntry(env, app), category });
      }
      return json({ ok: true });
    }

    if (method === "POST" && path === "/store/track") {
      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const repoUrl     = (body.repoUrl     || "").toString().trim();
      const name        = (body.name        || "").toString().trim();
      const packageName = (body.packageName || "").toString().trim();
      const summary     = normalizeStoreText(body.summary);
      const description = normalizeStoreText(body.description);
      const category    = (body.category    || "").toString().trim() || null;

      if (!repoUrl)     return badRequest("repoUrl_required");
      if (!name)        return badRequest("name_required");
      if (!packageName) return badRequest("packageName_required");

      const gh = parseGitHubRepo(repoUrl);
      if (!gh) return badRequest("only_github_repos_supported");

      let release;
      try {
        release = await githubLatestRelease(gh.owner, gh.repo);
      } catch (e) {
        return json({ error: "github_fetch_failed", detail: String(e?.message || e) }, 502);
      }
      if (!release) return json({ error: "no_stable_release_found" }, 422);

      const asset = findApkAsset(release);
      if (!asset) return json({ error: "no_apk_asset_in_release" }, 422);

      const MAX_APK_BYTES = 100 * 1024 * 1024;
      if (asset.size > MAX_APK_BYTES) return json({ error: "apk_too_large" }, 422);

      const versionName = release.tag_name;
      const versionCode = tagToVersionCode(release.tag_name);
      if (!versionCode) return json({ error: "unsupported_release_tag", tag: release.tag_name }, 422);

      const existing = await getStoreAppByPackage(env, packageName);
      let appId = existing?.id || null;

      if (!appId) {
        appId = await createUnclaimedStoreApp(env, { packageName, name, summary, description, repoUrl });
        if (!appId) return json({ error: "app_create_failed" }, 500);
      } else if (existing.status !== APP_STATUS.ACTIVE) {
        await setAppStatus(env, appId, APP_STATUS.ACTIVE);
      }

      const existingSubmission = await getSubmissionByVersionCode(env, appId, versionCode);
      if (existingSubmission) {
        if (existingSubmission.status === "live") {
          return json({ ok: true, appId, submissionId: existingSubmission.id, versionName, versionCode, imageOnly: true }, 200);
        }

        await deleteStagingApk(env, packageName, versionCode).catch(() => {});
        await deleteSubmissionById(env, existingSubmission.id);
      }

      let apkBuffer;
      try {
        const apkRes = await fetch(asset.browser_download_url, {
          headers: { "user-agent": "SafeHaven-Store/1.0" },
        });
        if (!apkRes.ok) throw new Error(`apk_download_failed:${apkRes.status}`);
        apkBuffer = await apkRes.arrayBuffer();
      } catch (e) {
        return json({ error: "apk_download_failed", detail: String(e?.message || e) }, 502);
      }

      if (apkBuffer.byteLength > MAX_APK_BYTES) return json({ error: "apk_too_large" }, 422);

      if (category) await setAppCategory(env, appId, category);

      try {
        await uploadBufferToStaging(env, packageName, versionCode, apkBuffer);
      } catch (e) {
        return json({ error: "staging_upload_failed", detail: String(e?.message || e) }, 500);
      }

      const submissionId = await createSubmission(env, {
        appId,
        developerId: COMMUNITY_DEVELOPER_ID,
        packageName,
        versionName,
        versionCode,
        stagingKey:  `staging/${packageName}/${versionCode}/app.apk`,
      });
      if (!submissionId) return json({ error: "submission_create_failed" }, 500);

      await advanceSubmissionToScan(env, submissionId);
      await setAppLastRepoCheck(env, appId);

      return json({ ok: true, appId, submissionId, versionName, versionCode }, 201);
    }

    if (method === "GET" && path.startsWith("/store/track/")) {
      const packageName = decodeURIComponent(path.replace("/store/track/", "")).trim();
      if (!packageName) return notFound();
      const app = await getStoreAppByPackage(env, packageName);
      if (!app) return notFound();
      return json({
        appId:         app.id,
        packageName:   app.package_name,
        name:          app.name,
        repoUrl:       app.repo_url,
        claimed:       !!app.claimed,
        trustLevel:    app.trust_level,
        signingFlag:   app.signing_flag || null,
        lastRepoCheck: app.last_repo_check || null,
      });
    }

    if (method === "POST" && path.match(/^\/store\/track\/[^/]+\/claim$/)) {
      const me = await requireUser();
      if (!me) return unauthorized();
      if (!me.developerEnabled) return forbidden();

      const appId = path.replace("/store/track/", "").replace("/claim", "").trim();
      const app   = await getStoreAppById(env, appId);
      if (!app) return notFound();
      if (app.claimed) return json({ error: "already_claimed" }, 409);

      const body = await readJson(request);
      if (!body) return badRequest("json_required");

      const providedHash = (body.signingKeyHash || "").toString().trim();
      if (!providedHash)          return badRequest("signingKeyHash_required");
      if (!app.signing_key_hash)  return json({ error: "no_signing_key_on_record_yet" }, 422);
      if (app.signing_key_hash !== providedHash) return json({ error: "signing_key_mismatch" }, 403);

      const gh = parseGitHubRepo(app.repo_url);
      if (!gh) return json({ error: "repo_not_verifiable" }, 422);

      const challengeRes = await fetch(
        `https://raw.githubusercontent.com/${gh.owner}/${gh.repo}/HEAD/.safehaven`,
        { headers: { "user-agent": "SafeHaven-Store/1.0" } }
      );
      if (!challengeRes.ok) return json({ error: "challenge_file_not_found" }, 403);
      const challengeBody = (await challengeRes.text()).trim();
      if (challengeBody !== app.repo_token) return json({ error: "challenge_mismatch" }, 403);

      await setAppClaimed(env, appId, me.id);
      await setAppRepoVerified(env, appId, true);
      return json({ ok: true, claimed: true });
    }

    const ratingsResponse = await handleRatingsRoute(request, env, path, method);
    if (ratingsResponse) return ratingsResponse;

    const me2 = await requireUser();
    const adminRatingsResponse = await handleAdminRatingsRoute(request, env, path, method, me2);
    if (adminRatingsResponse) return adminRatingsResponse;

    return notFound();

  } catch (e) {
    console.log(JSON.stringify({
      tag:   "store_error",
      error: String(e?.message || e),
      stack: String(e?.stack   || ""),
    }));
    return json({ error: "internal_error", detail: String(e?.message || e) }, 500);
  }
}