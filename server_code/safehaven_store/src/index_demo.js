import { handleStore, runStoreAutoApprovals, runGitHubBootstrapImport } from "./store/store.js";
import { demoAuth } from "./store/auth_demo.js";
import { renderDashboardHtml } from "./store/web/dashboard.js";

const html = (body, status = 200) =>
  new Response(body, { status, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });

export default {
  async fetch(request, env, ctx) {
    ctx.waitUntil(runStoreAutoApprovals(env));

    const url    = new URL(request.url);
    const path   = url.pathname;
    const method = request.method;

    if (method === "GET" && (path === "/" || path === "/admin")) {
      return html(renderDashboardHtml());
    }

    return handleStore(request, env, demoAuth);
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(runStoreAutoApprovals(env));

    if (event.cron === "0 3 1 * *") {
      ctx.waitUntil(runGitHubBootstrapImport(env));
    }
  },
};