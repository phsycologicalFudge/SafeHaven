export const renderDashboardHtml = () => `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover" />
<title>SafeHaven Admin</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial; background: #0B1220; color: #EAF1FF; -webkit-font-smoothing: antialiased; }

  .loginWrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px; }
  .loginCard { width: 100%; max-width: 380px; background: rgba(255,255,255,.03); border: 1px solid rgba(255,255,255,.08); border-radius: 20px; padding: 36px; }
  .loginTitle { font-size: 20px; font-weight: 850; margin: 0 0 4px; }
  .loginSub { font-size: 13px; color: rgba(234,241,255,.4); margin: 0 0 28px; }
  label { font-size: 11px; color: rgba(234,241,255,.4); letter-spacing: .07em; text-transform: uppercase; display: block; margin-bottom: 5px; }
  input, select { width: 100%; padding: 10px 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,.09); background: rgba(255,255,255,.04); color: #EAF1FF; outline: none; font-size: 13px; font-family: inherit; }
  input:focus, select:focus { border-color: rgba(120,168,255,.4); box-shadow: 0 0 0 3px rgba(120,168,255,.1); }
  .btn { padding: 9px 16px; border-radius: 8px; border: 1px solid rgba(120,168,255,.22); background: rgba(120,168,255,.09); color: #EAF1FF; font-weight: 700; font-size: 13px; cursor: pointer; font-family: inherit; }
  .btn:hover { background: rgba(120,168,255,.17); }
  .btn.full { width: 100%; margin-top: 16px; padding: 11px; }
  .btn.danger { border-color: rgba(248,113,113,.18); background: transparent; color: #f87171; }
  .btn.danger:hover { background: rgba(248,113,113,.07); }
  .st { margin-top: 8px; font-size: 12px; min-height: 16px; }
  .ok { color: #4ade80; }
  .bad { color: #f87171; }

  .app { min-height: 100vh; display: grid; grid-template-columns: 200px 1fr; }
  .side { border-right: 1px solid rgba(255,255,255,.06); padding: 20px 12px; height: 100vh; overflow: auto; position: sticky; top: 0; display: flex; flex-direction: column; }
  .brandTitle { font-size: 13px; font-weight: 800; margin: 0 0 2px 6px; }
  .brandSub { font-size: 11px; color: rgba(234,241,255,.35); margin: 0 0 22px 6px; }
  .nav { display: flex; flex-direction: column; gap: 2px; }
  .navBtn { width: 100%; text-align: left; padding: 9px 10px; border-radius: 7px; border: none; background: transparent; color: rgba(234,241,255,.5); font-weight: 600; font-size: 13px; cursor: pointer; font-family: inherit; }
  .navBtn:hover { color: rgba(234,241,255,.85); background: rgba(255,255,255,.04); }
  .navBtn.active { color: #EAF1FF; background: rgba(255,255,255,.07); }
  .sideFoot { margin-top: auto; padding-top: 16px; }

  .main { padding: 24px 28px; overflow-x: hidden; min-width: 0; }
  .topbar { display: flex; align-items: center; gap: 12px; margin-bottom: 22px; }
  .burger { display: none; border: 1px solid rgba(255,255,255,.1); background: transparent; color: #EAF1FF; border-radius: 7px; padding: 8px 12px; font-weight: 700; font-size: 13px; cursor: pointer; font-family: inherit; }
  .meLabel { font-size: 12px; color: rgba(234,241,255,.3); }

  .section { display: none; }
  .section.show { display: block; }
  .pgTitle { font-size: 15px; font-weight: 800; margin: 0 0 3px; }
  .pgSub { font-size: 13px; color: rgba(234,241,255,.38); margin: 0 0 18px; }

  .surface { background: rgba(255,255,255,.025); border: 1px solid rgba(255,255,255,.065); border-radius: 9px; padding: 16px; margin-bottom: 12px; }
  .row { display: grid; grid-template-columns: 1fr auto; gap: 10px; align-items: end; margin-top: 12px; }

  .subtabs { display: flex; margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,.06); }
  .subtab { padding: 9px 14px; font-size: 13px; font-weight: 600; color: rgba(234,241,255,.4); background: transparent; border: none; cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -1px; font-family: inherit; }
  .subtab:hover { color: rgba(234,241,255,.75); }
  .subtab.active { color: #EAF1FF; border-bottom-color: #78a8ff; }

  .mrwrap { border-bottom: 1px solid rgba(255,255,255,.045); }
  .mrwrap:last-child { border-bottom: none; }
  .mr { display: flex; align-items: center; gap: 10px; padding: 11px 0; flex-wrap: wrap; }
  .abtn { padding: 5px 11px; border-radius: 6px; font-size: 12px; font-weight: 700; cursor: pointer; border: 1px solid rgba(255,255,255,.09); background: transparent; color: rgba(234,241,255,.65); font-family: inherit; white-space: nowrap; }
  .abtn:hover { background: rgba(255,255,255,.06); color: #EAF1FF; }
  .abtn.primary { border-color: rgba(120,168,255,.28); background: rgba(120,168,255,.1); color: #EAF1FF; }
  .abtn.primary:hover { background: rgba(120,168,255,.2); }
  .abtn.danger { border-color: rgba(248,113,113,.18); color: #f87171; }
  .abtn.danger:hover { background: rgba(248,113,113,.07); }

  .scrim { position: fixed; inset: 0; background: rgba(0,0,0,.5); display: none; z-index: 40; }
  .scrim.open { display: block; }

  @media (max-width: 860px) {
    .app { grid-template-columns: 1fr; }
    .side { position: fixed; inset: 0 auto 0 0; width: 240px; transform: translateX(-110%); transition: transform .18s ease; z-index: 50; background: #0d1628; height: 100vh; }
    .side.open { transform: translateX(0); }
    .burger { display: inline-flex; }
    .main { padding: 16px 14px; }
    .row { grid-template-columns: 1fr; }
  }
</style>
</head>
<body>

<div id="loginScreen" class="loginWrap">
  <div class="loginCard">
    <p class="loginTitle">SafeHaven Admin</p>
    <p class="loginSub">Enter your admin token to continue.</p>
    <div>
      <label>Admin Token</label>
      <input id="tokenInput" type="password" placeholder="admin-token-change-me" />
    </div>
    <button class="btn full" id="loginBtn">Sign in</button>
    <div id="loginStatus" class="st"></div>
  </div>
</div>

<div id="adminScreen" style="display:none;">
  <div class="scrim" id="scrim"></div>
  <div class="app">
    <aside class="side" id="side">
      <p class="brandTitle">SafeHaven Admin</p>
      <p class="brandSub">Store Dashboard</p>
      <div class="nav">
        <button class="navBtn active" id="navSubmissions">Submissions</button>
        <button class="navBtn" id="navApps">Apps</button>
        <button class="navBtn" id="navRatings">Ratings</button>
      </div>
      <div class="sideFoot">
        <button class="btn danger" style="width:100%;font-size:12px;padding:7px;" id="logoutBtn">Sign out</button>
      </div>
    </aside>

    <main class="main">
      <div class="topbar">
        <button class="burger" id="burger">Menu</button>
        <span class="meLabel" id="meLabel"></span>
      </div>

      <div class="section show" id="secSubmissions">
        <p class="pgTitle">Submissions</p>
        <p class="pgSub">Approve or reject apps waiting for manual review.</p>
        <div class="surface">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span style="font-size:13px;font-weight:700;">Pending review</span>
            <button class="abtn" id="refreshSubmissions">Refresh</button>
          </div>
          <div id="submissionsStatus" class="st"></div>
          <div id="submissionsList"></div>
        </div>
      </div>

      <div class="section" id="secApps">
        <p class="pgTitle">Apps</p>
        <p class="pgSub">Manage category, trust level, and status for live apps.</p>
        <div class="surface">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span style="font-size:13px;font-weight:700;">All apps</span>
            <button class="abtn" id="refreshApps">Refresh</button>
          </div>
          <div id="appsStatus" class="st"></div>
          <div id="appsList"></div>
        </div>
      </div>

      <div class="section" id="secRatings">
        <p class="pgTitle">Ratings</p>
        <p class="pgSub">View and reset app ratings.</p>
        <div class="surface">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;">
            <span style="font-size:13px;font-weight:700;">App ratings</span>
            <button class="abtn" id="refreshRatings">Refresh</button>
          </div>
          <div id="ratingsStatus" class="st"></div>
          <div id="ratingsList"></div>
        </div>
      </div>
    </main>
  </div>
</div>

<script>
const apiBase = location.origin;
let TOKEN = "";

const escHtml = (s) => String(s ?? "").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;").replaceAll("'","&#39;");
const setStatus = (el, msg, ok) => { if (!el) return; el.textContent = msg || ""; el.className = "st " + (ok === true ? "ok" : ok === false ? "bad" : ""); };
const apiFetch = (path, opts = {}) => fetch(apiBase + path, { ...opts, headers: { authorization: "Bearer " + TOKEN, "content-type": "application/json", ...(opts.headers || {}) } });

const loginScreen = document.getElementById("loginScreen");
const adminScreen = document.getElementById("adminScreen");
const tokenInput  = document.getElementById("tokenInput");
const loginBtn    = document.getElementById("loginBtn");
const loginStatus = document.getElementById("loginStatus");
const side        = document.getElementById("side");
const scrim       = document.getElementById("scrim");
const burger      = document.getElementById("burger");

const showAdmin = (token) => {
  TOKEN = token;
  try { localStorage.setItem("sh_admin_token", token); } catch {}
  loginScreen.style.display = "none";
  adminScreen.style.display = "";
  document.getElementById("meLabel").textContent = "admin";
  setTab("submissions");
};

const tryLogin = async () => {
  const t = (tokenInput.value || "").trim();
  if (!t) { setStatus(loginStatus, "Enter your token.", false); return; }
  loginBtn.disabled = true;
  setStatus(loginStatus, "Checking...", null);
  TOKEN = t;
  const res = await apiFetch("/admin/store/submissions?status=pending_review").catch(() => null);
  loginBtn.disabled = false;
  if (!res || res.status === 401 || res.status === 403) {
    TOKEN = "";
    setStatus(loginStatus, "Invalid token.", false);
    return;
  }
  showAdmin(t);
};

loginBtn.onclick = tryLogin;
tokenInput.onkeydown = (e) => { if (e.key === "Enter") tryLogin(); };

document.getElementById("logoutBtn").onclick = () => {
  TOKEN = "";
  try { localStorage.removeItem("sh_admin_token"); } catch {}
  adminScreen.style.display = "none";
  loginScreen.style.display = "";
  tokenInput.value = "";
  setStatus(loginStatus, "", null);
};

burger.onclick  = () => { side.classList.add("open"); scrim.classList.add("open"); };
scrim.onclick   = () => { side.classList.remove("open"); scrim.classList.remove("open"); };

const navSubmissions = document.getElementById("navSubmissions");
const navApps        = document.getElementById("navApps");
const navRatings     = document.getElementById("navRatings");
const secSubmissions = document.getElementById("secSubmissions");
const secApps        = document.getElementById("secApps");
const secRatings     = document.getElementById("secRatings");

const setTab = (tab) => {
  [navSubmissions, navApps, navRatings].forEach((b, i) => b.classList.toggle("active", ["submissions","apps","ratings"][i] === tab));
  [secSubmissions, secApps, secRatings].forEach((s, i) => s.classList.toggle("show", ["submissions","apps","ratings"][i] === tab));
  side.classList.remove("open"); scrim.classList.remove("open");
  if (tab === "submissions") loadSubmissions();
  if (tab === "apps")        loadApps();
  if (tab === "ratings")     loadRatings();
};

navSubmissions.onclick = () => setTab("submissions");
navApps.onclick        = () => setTab("apps");
navRatings.onclick     = () => setTab("ratings");

const loadSubmissions = async () => {
  const st   = document.getElementById("submissionsStatus");
  const list = document.getElementById("submissionsList");
  setStatus(st, "Loading...", null);
  list.innerHTML = "";
  const res  = await apiFetch("/admin/store/submissions?status=pending_review");
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  const submissions = Array.isArray(data.submissions) ? data.submissions : [];
  if (!submissions.length) { setStatus(st, "No submissions pending.", null); return; }
  setStatus(st, "", null);
  list.innerHTML = submissions.map((s) => {
    const id          = escHtml(s.id);
    const packageName = escHtml(s.package_name || "");
    const versionName = escHtml(s.version_name || "");
    const versionCode = escHtml(s.version_code || "");
    const sha         = escHtml(s.apk_sha256 || "");
    const size        = Number(s.apk_size || 0);
    const mb          = size > 0 ? (size / 1024 / 1024).toFixed(2) + " MB" : "Unknown size";
    return \`<div class="mrwrap"><div class="mr">
      <div style="flex:1;min-width:0;">
        <div style="font-size:13px;font-weight:800;">\${packageName}</div>
        <div style="font-size:12px;opacity:.42;margin-top:3px;">v\${versionName} · code \${versionCode}</div>
        <div style="font-size:11px;opacity:.32;margin-top:4px;">\${mb}\${sha ? " · " + sha.slice(0,24) + "..." : ""}</div>
      </div>
      <div style="display:flex;gap:6px;flex-shrink:0;">
        <button class="abtn primary" onclick="approveSubmission('\${id}')">Approve</button>
        <button class="abtn danger"  onclick="rejectSubmission('\${id}')">Reject</button>
      </div>
    </div></div>\`;
  }).join("");
};

const approveSubmission = async (id) => {
  const st = document.getElementById("submissionsStatus");
  setStatus(st, "Approving...", null);
  const res  = await apiFetch("/admin/store/submissions/" + encodeURIComponent(id) + "/approve", { method: "POST" });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "Approved and published.", true);
  await loadSubmissions();
};

const rejectSubmission = async (id) => {
  const reason = prompt("Reject reason?", "Rejected during manual review");
  if (reason === null) return;
  const st   = document.getElementById("submissionsStatus");
  setStatus(st, "Rejecting...", null);
  const res  = await apiFetch("/admin/store/submissions/" + encodeURIComponent(id) + "/reject", { method: "POST", body: JSON.stringify({ reason }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "Rejected.", true);
  await loadSubmissions();
};

document.getElementById("refreshSubmissions").onclick = loadSubmissions;

const CATEGORIES = { security:"Security", productivity:"Productivity", utilities:"Utilities", communication:"Communication", entertainment:"Entertainment", finance:"Finance", health:"Health & Fitness", education:"Education", tools:"Tools", other:"Other" };
const TRUST_LEVELS = { verified_source:"Verified Source", security_reviewed:"Security Reviewed" };
const APP_STATUSES = { active:"Active", suspended:"Suspended", removed:"Removed" };

let appsData = [];

const loadApps = async () => {
  const st   = document.getElementById("appsStatus");
  const list = document.getElementById("appsList");
  setStatus(st, "Loading...", null);
  list.innerHTML = "";
  const res  = await apiFetch("/store/index.json");
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  appsData = Array.isArray(data.apps) ? data.apps : [];
  if (!appsData.length) { setStatus(st, "No apps in the store yet.", null); return; }
  setStatus(st, "", null);
  renderApps();
};

const renderApps = () => {
  const list = document.getElementById("appsList");
  list.innerHTML = appsData.map((app) => {
    const pkg        = escHtml(app.packageName || "");
    const name       = escHtml(app.name || "");
    const category   = escHtml(app.category || "");
    const trustLevel = escHtml(app.trustLevel || "");
    const catOptions = Object.entries(CATEGORIES).map(([k,v]) => \`<option value="\${k}" \${category===k?"selected":""}>\${escHtml(v)}</option>\`).join("");
    const trustOptions = Object.entries(TRUST_LEVELS).map(([k,v]) => \`<option value="\${k}" \${trustLevel===k?"selected":""}>\${escHtml(v)}</option>\`).join("");
    return \`<div class="mrwrap"><div class="mr" style="align-items:flex-start;flex-direction:column;gap:8px;padding:14px 0;">
      <div>
        <div style="font-size:13px;font-weight:800;">\${name}</div>
        <div style="font-size:11px;opacity:.38;margin-top:2px;">\${pkg}</div>
      </div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;width:100%;">
        <div style="flex:1;min-width:140px;">
          <label>Category</label>
          <select id="cat_\${pkg}" onchange="setCategory('\${pkg}', this.value)">
            <option value="" \${!category?"selected":""}>— unset —</option>
            \${catOptions}
          </select>
        </div>
        <div style="flex:1;min-width:160px;">
          <label>Trust Level</label>
          <select id="trust_\${pkg}" onchange="setTrustLevel('\${pkg}', this.value)">\${trustOptions}</select>
        </div>
        <div style="display:flex;align-items:flex-end;gap:6px;">
          <button class="abtn danger" onclick="suspendApp('\${pkg}')">Suspend</button>
          <button class="abtn" style="border-color:rgba(248,113,113,.18);color:#f87171;" onclick="removeApp('\${pkg}')">Remove</button>
        </div>
      </div>
    </div></div>\`;
  }).join("");
};

const resolveAppId = async (packageName) => {
  const res  = await apiFetch("/admin/store/apps");
  const data = await res.json().catch(() => ({}));
  const apps = Array.isArray(data.apps) ? data.apps : [];
  const match = apps.find((a) => (a.package_name || "") === packageName);
  return match ? match.id : null;
};

const setCategory = async (packageName, category) => {
  const st    = document.getElementById("appsStatus");
  const appId = await resolveAppId(packageName);
  if (!appId) { setStatus(st, "Could not resolve app ID.", false); return; }
  const res  = await apiFetch("/admin/store/apps/" + encodeURIComponent(appId) + "/category", { method: "POST", body: JSON.stringify({ category: category || null }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "Category updated.", true);
};

const setTrustLevel = async (packageName, trustLevel) => {
  const st    = document.getElementById("appsStatus");
  const appId = await resolveAppId(packageName);
  if (!appId) { setStatus(st, "Could not resolve app ID.", false); return; }
  const res  = await apiFetch("/admin/store/apps/" + encodeURIComponent(appId) + "/trust-level", { method: "POST", body: JSON.stringify({ trustLevel }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "Trust level updated.", true);
};

const suspendApp = async (packageName) => {
  if (!confirm("Suspend " + packageName + "? It will be removed from the public index.")) return;
  const st    = document.getElementById("appsStatus");
  const appId = await resolveAppId(packageName);
  if (!appId) { setStatus(st, "Could not resolve app ID.", false); return; }
  const res  = await apiFetch("/admin/store/apps/" + encodeURIComponent(appId) + "/status", { method: "POST", body: JSON.stringify({ status: "suspended" }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "App suspended.", true);
  await loadApps();
};

const removeApp = async (packageName) => {
  if (!confirm("Permanently remove " + packageName + "? This cannot be undone.")) return;
  const st    = document.getElementById("appsStatus");
  const appId = await resolveAppId(packageName);
  if (!appId) { setStatus(st, "Could not resolve app ID.", false); return; }
  const res  = await apiFetch("/admin/store/apps/" + encodeURIComponent(appId) + "/status", { method: "POST", body: JSON.stringify({ status: "removed" }) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "App removed.", true);
  await loadApps();
};

document.getElementById("refreshApps").onclick = loadApps;

const loadRatings = async () => {
  const st   = document.getElementById("ratingsStatus");
  const list = document.getElementById("ratingsList");
  setStatus(st, "Loading...", null);
  list.innerHTML = "";
  const res  = await apiFetch("/admin/store/ratings");
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  const ratings = Array.isArray(data.ratings) ? data.ratings : [];
  if (!ratings.length) { setStatus(st, "No ratings yet.", null); return; }
  setStatus(st, "", null);
  list.innerHTML = ratings.map((r) => {
    const pkg   = escHtml(r.package_name || "");
    const count = Number(r.rating_count || 0);
    const avg   = count > 0 ? (Number(r.rating_sum) / count).toFixed(1) : "—";
    return \`<div class="mrwrap"><div class="mr">
      <div style="flex:1;min-width:0;">
        <div style="font-size:13px;font-weight:800;">\${pkg}</div>
        <div style="font-size:12px;opacity:.42;margin-top:3px;">\${avg} ★ · \${count} rating\${count !== 1 ? "s" : ""}</div>
      </div>
      <button class="abtn danger" onclick="resetRating('\${pkg}')">Reset</button>
    </div></div>\`;
  }).join("");
};

const resetRating = async (packageName) => {
  if (!confirm("Reset all ratings for " + packageName + "? This cannot be undone.")) return;
  const st  = document.getElementById("ratingsStatus");
  setStatus(st, "Resetting...", null);
  const res  = await apiFetch("/admin/store/ratings/" + encodeURIComponent(packageName), { method: "DELETE" });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { setStatus(st, data.error || "Failed", false); return; }
  setStatus(st, "Ratings cleared.", true);
  await loadRatings();
};

document.getElementById("refreshRatings").onclick = loadRatings;

try {
  const saved = localStorage.getItem("sh_admin_token");
  if (saved) showAdmin(saved);
} catch {}
</script>
</body>
</html>`;
