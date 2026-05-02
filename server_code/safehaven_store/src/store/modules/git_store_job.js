import { createSubmission, advanceSubmissionToScan } from "../store_db.js";
import { getPresignedStagingUploadUrl, getPresignedImageUploadUrl, imageKey } from "../storage.js";

const COMMUNITY_DEVELOPER_ID = "safehaven-community";
const IMPORT_LIMIT           = 50;
const MAX_APK_BYTES          = 100 * 1024 * 1024;
const MAX_ICON_BYTES         = 2 * 1024 * 1024;

const nowUnix = () => Math.floor(Date.now() / 1000);

const cryptoRandomHex = (bytes) => {
  const a = new Uint8Array(bytes);
  crypto.getRandomValues(a);
  return Array.from(a, (b) => b.toString(16).padStart(2, "0")).join("");
};

const githubHeaders = (env) => {
  const token = (env.GITHUB_TOKEN || "").trim();
  return {
    "user-agent": "SafeHaven-Store/1.0",
    accept:       "application/vnd.github+json",
    ...(token ? { authorization: `Bearer ${token}` } : {}),
  };
};

const normalizeGitHubRepoUrl = (repoUrl) => {
  const clean = (repoUrl || "").toString().trim().replace(/\.git$/, "").replace(/\/$/, "");
  const m = clean.match(/^https?:\/\/github\.com\/([^/]+)\/([^/]+)$/i);
  if (!m) return null;
  return `https://github.com/${m[1]}/${m[2]}`;
};

const repoUrlVariants = (repoUrl) => {
  const normal = normalizeGitHubRepoUrl(repoUrl);
  if (!normal) return [];
  return [normal, `${normal}/`, `${normal}.git`];
};

const githubSearch = async (env, query, perPage = 50) => {
  const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=${perPage}`;
  const res = await fetch(url, { headers: githubHeaders(env) });
  if (!res.ok) throw new Error(`github_search_failed:${res.status}`);

  const data = await res.json();

  return (data.items || [])
    .filter((item) => item?.full_name && item?.html_url)
    .map((item) => ({
      fullName:    item.full_name,
      name:        item.name || item.full_name.split("/").pop(),
      description: item.description || "",
      stars:       item.stargazers_count || 0,
      topics:      Array.isArray(item.topics) ? item.topics : [],
      repoUrl:     normalizeGitHubRepoUrl(item.html_url) || `https://github.com/${item.full_name}`,
      iconUrl:     item.owner?.avatar_url || null,
    }));
};

const githubRepoDetails = async (env, owner, repo) => {
  const res = await fetch(
    `https://api.github.com/repos/${owner}/${repo}`,
    { headers: githubHeaders(env) }
  );

  if (!res.ok) return null;

  const data = await res.json();

  return {
    fullName:    data.full_name || `${owner}/${repo}`,
    name:        data.name || repo,
    description: data.description || "",
    stars:       data.stargazers_count || 0,
    topics:      Array.isArray(data.topics) ? data.topics : [],
    repoUrl:     normalizeGitHubRepoUrl(data.html_url) || `https://github.com/${owner}/${repo}`,
    iconUrl:     data.owner?.avatar_url || null,
  };
};

const githubLatestRelease = async (env, owner, repo) => {
  const res = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/releases/latest`,
    { headers: githubHeaders(env) }
  );

  if (res.status === 404) return null;
  if (!res.ok) return null;

  const data = await res.json();
  if (data.prerelease || data.draft) return null;

  return data;
};

const decodeBase64Utf8 = (value) => {
  try {
    const binary = atob((value || "").replace(/\s/g, ""));
    const bytes  = new Uint8Array(binary.length);

    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }

    return new TextDecoder().decode(bytes);
  } catch {
    return "";
  }
};

const stripReadmeToDescription = (readme) => {
  const text = (readme || "")
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/!\[[^\]]*]\([^)]*\)/g, " ")
    .replace(/\[([^\]]+)]\([^)]*\)/g, "$1")
    .replace(/<img\b[^>]*>/gi, " ")
    .replace(/<picture\b[\s\S]*?<\/picture>/gi, " ")
    .replace(/<svg\b[\s\S]*?<\/svg>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/^#{1,6}\s*/gm, "")
    .replace(/^[>\-*+]\s*/gm, "")
    .replace(/\|/g, " ")
    .replace(/\[(?:!\[.*?)]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!text) return null;

  return text.slice(0, 4000);
};

const githubReadmeDescription = async (env, owner, repo) => {
  const res = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/readme`,
    { headers: githubHeaders(env) }
  );

  if (!res.ok) return null;

  const data = await res.json();
  const raw  = decodeBase64Utf8(data.content || "");

  return stripReadmeToDescription(raw);
};

const parseOpenHubXml = (xml) => {
  const results       = [];
  const projectBlocks = xml.match(/<project\b[^>]*>[\s\S]*?<\/project>/g) || [];

  for (const block of projectBlocks) {
    const name        = (block.match(/<name>([\s\S]*?)<\/name>/)               || [])[1]?.trim() || "";
    const description = (block.match(/<description>([\s\S]*?)<\/description>/) || [])[1]?.trim() || "";

    const urlTags = block.match(/<url>(https?:\/\/github\.com\/[^<]+)<\/url>/g) || [];

    for (const tag of urlTags) {
      const raw     = (tag.match(/<url>([\s\S]*?)<\/url>/) || [])[1]?.trim() || "";
      const repoUrl = normalizeGitHubRepoUrl(raw);

      if (!repoUrl) continue;

      const m = repoUrl.match(/^https:\/\/github\.com\/([^/]+)\/([^/]+)$/i);
      if (!m) continue;

      results.push({
        fullName:    `${m[1]}/${m[2]}`,
        name:        name || m[2],
        description: description.replace(/<[^>]+>/g, ""),
        stars:       0,
        repoUrl,
        iconUrl:     null,
      });

      break;
    }
  }

  return results;
};

const openHubSearch = async (env, query, page = 1) => {
  const apiKey = (env.OPENHUB_API_KEY || "").trim();
  if (!apiKey) return [];

  const url = `https://www.openhub.net/projects.xml?query=${encodeURIComponent(query)}&sort=rating&page=${page}&api_key=${apiKey}`;
  const res = await fetch(url, { headers: { "user-agent": "SafeHaven-Store/1.0" } });
  if (!res.ok) throw new Error(`openhub_search_failed:${res.status}`);

  const xml = await res.text();
  return parseOpenHubXml(xml);
};

const findApkAsset = (release) =>
  (release?.assets || []).find(
    (a) => a.name.endsWith(".apk") && a.state === "uploaded" && a.browser_download_url
  ) || null;

const tagToVersionCode = (tag) => {
  const clean = (tag || "")
    .toString()
    .trim()
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

const CATEGORY_RULES = [
  {
    category: "security",
    weight: 5,
    terms: [
      "security", "privacy", "vpn", "proxy", "wireguard", "v2ray", "shadowsocks", "tor",
      "firewall", "dns", "adblock", "blocklist", "malware", "antivirus", "authenticator",
      "2fa", "totp", "password", "keepass", "vault", "encryption", "encrypted",
      "crypto", "cryptography", "keychain", "root", "magisk", "kernelsu", "apatch",
      "lsposed", "permission", "permissions", "tracker", "tracking", "secure"
    ],
  },
  {
    category: "communication",
    weight: 5,
    terms: [
      "communication", "chat", "messaging", "message", "sms", "mms", "email", "mail",
      "mastodon", "matrix", "xmpp", "telegram", "signal", "fediverse", "social",
      "client", "push", "notification", "notifications", "gotify", "ntfy", "forum",
      "lemmy", "reddit", "discord", "irc", "contacts", "dialer", "phone"
    ],
  },
  {
    category: "entertainment",
    weight: 4,
    terms: [
      "entertainment", "music", "audio", "video", "player", "media", "youtube",
      "stream", "streaming", "anime", "manga", "novel", "reader", "book", "books",
      "comic", "comics", "movie", "movies", "tv", "podcast", "radio", "game",
      "games", "emulator", "retro", "lyrics", "song", "songs", "gallery", "photo",
      "photos", "image", "images", "pixiv"
    ],
  },
  {
    category: "productivity",
    weight: 4,
    terms: [
      "productivity", "todo", "task", "tasks", "notes", "note", "notepad", "calendar",
      "planner", "schedule", "habit", "habits", "reminder", "reminders", "focus",
      "timer", "pomodoro", "journal", "diary", "memos", "documents", "document",
      "office", "markdown", "backup", "sync", "clipboard", "ocr", "scan", "scanner"
    ],
  },
  {
    category: "utilities",
    weight: 4,
    terms: [
      "utility", "utilities", "tool", "tools", "file", "files", "filemanager",
      "file-manager", "manager", "calculator", "calc", "keyboard", "launcher",
      "wallpaper", "weather", "clock", "alarm", "compass", "flashlight", "brightness",
      "volume", "wifi", "bluetooth", "adb", "logcat", "terminal", "shell", "termux",
      "widget", "widgets", "cleaner", "storage", "download", "downloader", "clipboard"
    ],
  },
  {
    category: "finance",
    weight: 5,
    terms: [
      "finance", "budget", "budgeting", "expense", "expenses", "money", "bank",
      "banking", "wallet", "crypto-wallet", "invoice", "accounting", "stocks",
      "portfolio", "payments", "payment"
    ],
  },
  {
    category: "health",
    weight: 5,
    terms: [
      "health", "fitness", "workout", "exercise", "medical", "medicine", "medication",
      "period", "sleep", "calorie", "calories", "nutrition", "wellness", "step",
      "steps", "running", "training"
    ],
  },
  {
    category: "education",
    weight: 5,
    terms: [
      "education", "learn", "learning", "study", "school", "university", "language",
      "dictionary", "translator", "flashcard", "flashcards", "anki", "kanji",
      "math", "calculator", "science", "quiz", "reader", "books", "library"
    ],
  },
];

const normaliseCategoryText = (parts) =>
  parts
    .filter(Boolean)
    .join(" ")
    .toLowerCase()
    .replace(/[^a-z0-9+#._-]+/g, " ");

const inferCategory = (candidate, readmeDescription = "") => {
  const topics = Array.isArray(candidate.topics) ? candidate.topics : [];

  const text = normaliseCategoryText([
    candidate.fullName,
    candidate.name,
    candidate.description,
    topics.join(" "),
    readmeDescription,
  ]);

  const padded = ` ${text} `;
  const scores = new Map();

  for (const rule of CATEGORY_RULES) {
    let score = 0;

    for (const term of rule.terms) {
      const clean = term.toLowerCase();
      const topicHit = topics.some((t) => t.toLowerCase() === clean);
      const textHit = padded.includes(` ${clean} `) || padded.includes(clean.replace(/-/g, " "));

      if (topicHit) score += rule.weight + 3;
      else if (textHit) score += rule.weight;
    }

    if (score > 0) {
      scores.set(rule.category, (scores.get(rule.category) || 0) + score);
    }
  }

  const ranked = [...scores.entries()].sort((a, b) => b[1] - a[1]);
  return ranked[0]?.[0] || "other";
};

const getAppByRepoUrl = async (env, repoUrl) => {
  const variants = repoUrlVariants(repoUrl);
  if (!variants.length) return null;

  const row = await env.api_control_db
    .prepare(
      `SELECT *
       FROM store_apps
       WHERE repo_url = ?1 OR repo_url = ?2 OR repo_url = ?3
       LIMIT 1`
    )
    .bind(variants[0], variants[1], variants[2])
    .first();

  return row || null;
};

const getAppByPackage = (env, packageName) =>
  env.api_control_db
    .prepare("SELECT id FROM store_apps WHERE package_name = ?1 LIMIT 1")
    .bind(packageName)
    .first();

const deleteAppById = async (env, appId) => {
  const id = (appId || "").toString().trim();
  if (!id) return;

  await env.api_control_db
    .prepare("DELETE FROM store_submissions WHERE app_id = ?1")
    .bind(id)
    .run();

  await env.api_control_db
    .prepare("DELETE FROM store_apps WHERE id = ?1 AND developer_id = ?2 AND claimed = 0")
    .bind(id, COMMUNITY_DEVELOPER_ID)
    .run();
};

const makePlaceholderPackageName = (fullName) => {
  const [ownerRaw, repoRaw] = (fullName || "").split("/");
  const norm = (s) => {
    const cleaned = (s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
    return cleaned || "x";
  };

  return `pending.github.${norm(ownerRaw)}.${norm(repoRaw)}`;
};

const displayNameOf = (candidate) =>
  (candidate.name || candidate.fullName.split("/").pop() || "Unknown App")
    .replace(/[-_]/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .trim();

const uploadBufferToStaging = async (env, packageName, versionCode, buffer) => {
  const url = await getPresignedStagingUploadUrl(env, packageName, versionCode, 300);

  const res = await fetch(url, {
    method:  "PUT",
    headers: { "content-type": "application/vnd.android.package-archive" },
    body:    buffer,
  });

  if (!res.ok) throw new Error(`staging_upload_failed:${res.status}`);
};

const uploadIconFromUrl = async (env, packageName, iconUrl) => {
  if (!iconUrl) return null;

  let res;

  try {
    res = await fetch(iconUrl, {
      headers: { "user-agent": "SafeHaven-Store/1.0" },
    });
  } catch {
    return null;
  }

  if (!res.ok) return null;

  const contentType = (res.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();

  if (!["image/png", "image/jpeg", "image/webp"].includes(contentType)) {
    return null;
  }

  const buffer = await res.arrayBuffer();
  if (buffer.byteLength > MAX_ICON_BYTES) return null;

  const url = await getPresignedImageUploadUrl(env, packageName, "icon", 300);

  const uploadRes = await fetch(url, {
    method:  "PUT",
    headers: { "content-type": contentType },
    body:    buffer,
  });

  if (!uploadRes.ok) return null;

  return imageKey(packageName, "icon");
};

const createUnclaimedStoreApp = async (env, { packageName, name, summary, description, repoUrl, iconKey, category }) => {
  const id  = cryptoRandomHex(16);
  const now = nowUnix();

  await env.api_control_db
    .prepare(
      `INSERT INTO store_apps
        (id, developer_id, package_name, name, summary, description,
         repo_url, repo_token, repo_verified, trust_level, status,
         claimed, auto_tracked, icon_key, category, created_at, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, '', 0, 'unverified', 'active', 0, 1, ?8, ?9, ?10, ?10)`
    )
    .bind(
      id,
      COMMUNITY_DEVELOPER_ID,
      packageName,
      name,
      summary || null,
      description || null,
      repoUrl,
      iconKey || null,
      category || "other",
      now
    )
    .run();

  return id;
};

const hydrateCandidate = async (env, candidate) => {
  const [owner, repo] = candidate.fullName.split("/");

  if (candidate.iconUrl && candidate.description && candidate.stars) {
    return candidate;
  }

  const details = await githubRepoDetails(env, owner, repo);
  if (!details) return candidate;

  return {
    ...candidate,
    name:        candidate.name || details.name,
    description: candidate.description || details.description,
    stars:       candidate.stars || details.stars,
    topics:      candidate.topics?.length ? candidate.topics : details.topics,
    repoUrl:     candidate.repoUrl || details.repoUrl,
    iconUrl:     candidate.iconUrl || details.iconUrl,
  };
};

const importCandidate = async (env, rawCandidate) => {
  const candidate = await hydrateCandidate(env, rawCandidate);
  const repoUrl   = normalizeGitHubRepoUrl(candidate.repoUrl);

  if (!repoUrl) return { skipped: true, reason: "invalid_repo_url" };

  const byRepo = await getAppByRepoUrl(env, repoUrl);

  if (byRepo) {
    const status      = (byRepo.status || "").toString().trim();
    const developerId = (byRepo.developer_id || "").toString().trim();
    const autoTracked = Number(byRepo.auto_tracked || 0) === 1;
    const claimed     = Number(byRepo.claimed || 0) === 1;

    if (status === "removed" && developerId === COMMUNITY_DEVELOPER_ID && autoTracked && !claimed) {
      await deleteAppById(env, byRepo.id);
    } else {
      return { skipped: true, reason: "already_tracked" };
    }
  }

  const [owner, repo] = candidate.fullName.split("/");
  if (!owner || !repo) return { skipped: true, reason: "invalid_full_name" };

  const release = await githubLatestRelease(env, owner, repo);
  if (!release) return { skipped: true, reason: "no_stable_release" };

  const asset = findApkAsset(release);
  if (!asset) return { skipped: true, reason: "no_apk_asset" };
  if (asset.size > MAX_APK_BYTES) return { skipped: true, reason: "apk_too_large" };

  const versionCode = tagToVersionCode(release.tag_name);
  if (!versionCode) return { skipped: true, reason: "unparseable_tag" };

  const packageName = makePlaceholderPackageName(candidate.fullName);
  const byPkg       = await getAppByPackage(env, packageName);
  if (byPkg) return { skipped: true, reason: "placeholder_collision" };

  let apkBuffer;

  try {
    const apkRes = await fetch(asset.browser_download_url, {
      headers: { "user-agent": "SafeHaven-Store/1.0" },
    });

    if (!apkRes.ok) return { skipped: true, reason: `apk_download_failed:${apkRes.status}` };

    apkBuffer = await apkRes.arrayBuffer();
  } catch (e) {
    return { skipped: true, reason: `apk_download_error:${String(e?.message || e)}` };
  }

  if (apkBuffer.byteLength > MAX_APK_BYTES) {
    return { skipped: true, reason: "apk_too_large_post_download" };
  }

  let readmeDescription = null;

  try {
    readmeDescription = await githubReadmeDescription(env, owner, repo);
  } catch {
    readmeDescription = null;
  }

  const summary     = (candidate.description || "").slice(0, 200).trim() || null;
  const description = readmeDescription || candidate.description || null;
  const iconKey     = await uploadIconFromUrl(env, packageName, candidate.iconUrl);
  const category = inferCategory(candidate, readmeDescription || "");

  const appId = await createUnclaimedStoreApp(env, {
    packageName,
    name: displayNameOf(candidate),
    summary,
    description,
    repoUrl,
    iconKey,
    category,
  });

  if (!appId) return { skipped: true, reason: "app_create_failed" };

  try {
    await uploadBufferToStaging(env, packageName, versionCode, apkBuffer);
  } catch (e) {
    await deleteAppById(env, appId);
    return { skipped: true, reason: `staging_failed:${String(e?.message || e)}`, appId };
  }

  const submissionId = await createSubmission(env, {
    appId,
    developerId: COMMUNITY_DEVELOPER_ID,
    packageName,
    versionName: release.tag_name,
    versionCode,
    stagingKey:  `staging/${packageName}/${versionCode}/app.apk`,
  });

  if (!submissionId) {
    await deleteAppById(env, appId);
    return { skipped: true, reason: "submission_create_failed", appId };
  }

  await advanceSubmissionToScan(env, submissionId);

  return {
    imported: true,
    appId,
    submissionId,
    packageName,
    versionCode,
    category,
    hasIcon: !!iconKey,
    hasReadmeDescription: !!readmeDescription,
  };
};

const collectCandidates = async (env) => {
  const seen       = new Set();
  const candidates = [];

  const add = (items) => {
    for (const item of items) {
      const repoUrl = normalizeGitHubRepoUrl(item.repoUrl);
      if (!repoUrl || !item.fullName) continue;

      const key = item.fullName.toLowerCase();

      if (!seen.has(key)) {
        seen.add(key);
        candidates.push({ ...item, repoUrl });
      }
    }
  };

  const GITHUB_QUERIES = [
    "topic:android language:kotlin",
    "topic:fdroid language:kotlin",
    "topic:android-app language:kotlin",
    "topic:android language:java",
  ];

  const OPENHUB_QUERIES = [
    "android mobile",
    "android app",
  ];

  for (const query of GITHUB_QUERIES) {
    if (candidates.length >= IMPORT_LIMIT * 4) break;

    try {
      add(await githubSearch(env, query, 50));
    } catch (e) {
      console.log(JSON.stringify({
        tag:    "bootstrap_search_error",
        source: "github",
        query,
        error:  String(e?.message || e),
      }));
    }
  }

  for (const query of OPENHUB_QUERIES) {
    if (candidates.length >= IMPORT_LIMIT * 4) break;

    try {
      add(await openHubSearch(env, query, 1));
      add(await openHubSearch(env, query, 2));
    } catch (e) {
      console.log(JSON.stringify({
        tag:    "bootstrap_search_error",
        source: "openhub",
        query,
        error:  String(e?.message || e),
      }));
    }
  }

  candidates.sort((a, b) => b.stars - a.stars);

  return candidates;
};

export async function runGitHubBootstrapImport(env) {
  const results = {
    imported: 0,
    skipped:  0,
    errors:   [],
    details:  [],
  };

  const candidates = await collectCandidates(env);

  for (const candidate of candidates) {
    if (results.imported >= IMPORT_LIMIT) break;

    try {
      const outcome = await importCandidate(env, candidate);

      if (outcome.imported) {
        results.imported++;

        console.log(JSON.stringify({
          tag:                   "bootstrap_import",
          repo:                  candidate.fullName,
          appId:                 outcome.appId,
          submissionId:          outcome.submissionId,
          packageName:           outcome.packageName,
          versionCode:           outcome.versionCode,
          hasIcon:               outcome.hasIcon,
          hasReadmeDescription:  outcome.hasReadmeDescription,
        }));
      } else {
        results.skipped++;
      }

      results.details.push({ repo: candidate.fullName, ...outcome });
    } catch (e) {
      results.errors.push({
        repo:  candidate.fullName,
        error: String(e?.message || e),
      });
    }
  }

  console.log(JSON.stringify({
    tag:      "bootstrap_import_complete",
    imported: results.imported,
    skipped:  results.skipped,
    errors:   results.errors.length,
  }));

  return results;
}