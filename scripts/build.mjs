import fs from "node:fs";

const repo = process.env.REPO;
const token = process.env.GITHUB_TOKEN;
if (!repo) throw new Error("Missing REPO env");
if (!token) throw new Error("Missing GITHUB_TOKEN env");
const [owner, repoName] = repo.split("/");

async function gh(path) {
  const res = await fetch(`https://api.github.com${path}`, {
    headers: {
      "Authorization": `Bearer ${token}`,
      "Accept": "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "rapportage-builder"
    }
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}: ${await res.text()}`);
  return res.json();
}

function parseIssueBody(body = "") {
  const out = {};
  const map = {
    "Datum": "datum",
    "Tijd": "tijdvak",
    "Groep": "groep",
    "Begeleider": "begeleider",
    "Activiteit": "activiteit",
    "Opkomst": "opkomst",
    "Inhoud & verloop": "inhoud",
    "Bijzonderheden / incidenten": "bijzonderheden",
    "Vervolgacties": "vervolg"
  };
  const patterns = [
    /\*\*\s*(.+?)\s*\*\*[\r\n]+([\s\S]*?)(?=(\*\*.+?\*\*)|$)/g,             // **Label**
    /^###\s*(.+?)\s*[\r\n]+([\s\S]*?)(?=^###\s*.+?$|^\*\*.+?\*\*|$)/gmi     // ### Label
  ];
  for (const re of patterns) {
    let m;
    while ((m = re.exec(body))) {
      const key = map[(m[1] || "").trim()];
      if (key && !out[key]) out[key] = (m[2] || "").trim();
    }
  }
  return out;
}

function toDateNL(s) {
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const d = new Date(s);
  const parts = new Intl.DateTimeFormat("nl-NL", {
    timeZone: "Europe/Amsterdam",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(d).reduce((a, p) => (a[p.type] = p.value, a), {});
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function ensureDir(p) { if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true }); }

async function listAllIssues() {
  const out = [];
  let page = 1;
  while (true) {
    const data = await gh(`/repos/${owner}/${repoName}/issues?state=all&per_page=100&page=${page}`);
    const issuesOnly = data.filter(i => !i.pull_request);
    out.push(...issuesOnly);
    if (data.length < 100) break;
    page++;
  }
  return out;
}

(async function main() {
  const all = await listAllIssues();
  const issues = all.filter(it => (it.labels || []).some(l => (l.name || "").toLowerCase() === "rapportage"));

  const byDate = new Map();
  for (const issue of issues) {
    const payload = parseIssueBody(issue.body || "");
    if (!payload.datum) continue;
    const d = toDateNL(payload.datum);
    const arr = byDate.get(d) || [];
    arr.push({ id: issue.number, url: issue.html_url, updated_at: issue.updated_at, ...payload });
    byDate.set(d, arr);
  }

  ensureDir("data");
  if (byDate.size === 0) {
    fs.writeFileSync("data/latest.json", JSON.stringify({ date: null, items: [] }, null, 2));
    return;
  }

  const dates = [...byDate.keys()].sort();
  const latest = dates[dates.length - 1];

  for (const d of dates) {
    const items = (byDate.get(d) || []).sort((a, b) => (a.groep || "").localeCompare(b.groep || ""));
    fs.writeFileSync(`data/${d}.json`, JSON.stringify({ date: d, items }, null, 2));
  }
  fs.writeFileSync("data/latest.json", JSON.stringify({ date: latest, items: byDate.get(latest) }, null, 2));
})().catch(e => { console.error(e); process.exit(1); });
