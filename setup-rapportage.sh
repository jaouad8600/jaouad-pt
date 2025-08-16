#!/usr/bin/env bash
set -euo pipefail

# 0) Up-to-date + mappen
git fetch origin || true
git pull --rebase origin main || true
mkdir -p .github/ISSUE_TEMPLATE .github/workflows scripts data docs

# 1) Issue template
cat > .github/ISSUE_TEMPLATE/rapportage.yml <<'YAML'
name: "Rapportage sportmoment"
description: "Vul dit formulier in na een sportmoment."
title: "[Rapportage] Rapportage"
labels: [rapportage]
body:
  - type: input
    id: datum
    attributes: { label: Datum, description: "JJJJ-MM-DD", placeholder: "2025-08-16" }
    validations: { required: true }
  - type: input
    id: tijdvak
    attributes: { label: Tijd, placeholder: "14:00–15:00" }
    validations: { required: true }
  - type: input
    id: groep
    attributes: { label: Groep, placeholder: "Bijv. Groep A / Unit 3" }
    validations: { required: true }
  - type: input
    id: begeleider
    attributes: { label: Begeleider, placeholder: "Voor- en achternaam" }
    validations: { required: true }
  - type: dropdown
    id: activiteit
    attributes:
      label: Activiteit
      options: [Voetbal, Fitness, Basketbal, Boksen, Hardlopen, Anders]
    validations: { required: true }
  - type: textarea
    id: opkomst
    attributes: { label: Opkomst }
  - type: textarea
    id: inhoud
    attributes: { label: Inhoud & verloop }
  - type: textarea
    id: bijzonderheden
    attributes: { label: Bijzonderheden / incidenten }
  - type: textarea
    id: vervolg
    attributes: { label: Vervolgacties }
YAML

# 2) Workflow (auto-label, retitle, build en publish JSON)
cat > .github/workflows/rapportage-build.yml <<'YAML'
name: Build rapportage JSON
on:
  issues:
    types: [opened, edited, labeled, unlabeled]
  workflow_dispatch:

permissions:
  contents: write
  issues: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Ensure 'rapportage' label exists
        uses: actions/github-script@v7
        with:
          script: |
            try {
              await github.rest.issues.getLabel({ owner: context.repo.owner, repo: context.repo.repo, name: "rapportage" });
            } catch {
              await github.rest.issues.createLabel({
                owner: context.repo.owner, repo: context.repo.repo,
                name: "rapportage", color: "FF7A00",
                description: "Ingevulde sport-rapportage"
              });
            }

      - name: Ensure current issue has 'rapportage' label
        if: github.event_name == 'issues'
        uses: actions/github-script@v7
        with:
          script: |
            const n = context.payload.issue.number;
            const { data: labels } = await github.rest.issues.listLabelsOnIssue({
              owner: context.repo.owner, repo: context.repo.repo, issue_number: n
            });
            if (!labels.some(l => (l.name||"").toLowerCase() === "rapportage")) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner, repo: context.repo.repo, issue_number: n,
                labels: ["rapportage"]
              });
            }

      - name: Retitle issue from form fields
        if: github.event_name == 'issues'
        uses: actions/github-script@v7
        with:
          script: |
            const body = context.payload.issue?.body || "";
            function pick(label) {
              const re = new RegExp(String.raw`(?:\\*\\*\\s*${label}\\s*\\*\\*|^###\\s*${label})\\s*[\\r\\n]+([\\s\\S]*?)(?=(?:\\*\\*.+?\\*\\*|^###\\s*.+|$))`, "im");
              const m = re.exec(body);
              return m ? (m[1]||"").trim() : "";
            }
            const groep = pick("Groep") || "—";
            const datum = pick("Datum") || "—";
            const begeleider = pick("Begeleider") || "—";
            const desired = `[Rapportage] ${groep} — ${datum} — ${begeleider}`;
            if ((context.payload.issue.title || "") !== desired) {
              await github.rest.issues.update({
                owner: context.repo.owner, repo: context.repo.repo,
                issue_number: context.payload.issue.number,
                title: desired
              });
            }

      - name: Build JSON (no deps)
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
        run: node scripts/build.mjs

      - name: Publish JSON to docs/data
        run: |
          mkdir -p docs/data
          cp -f data/*.json docs/data/ || true

      - name: Commit & push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add data/*.json docs/data/*.json || true
          git commit -m "chore: update rapportage JSON" || echo "No changes"
          git push || true
YAML

# 3) Builder script
cat > scripts/build.mjs <<'JS'
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
    /\*\*\s*(.+?)\s*\*\*[\r\n]+([\s\S]*?)(?=(\*\*.+?\*\*)|$)/g,
    /^###\s*(.+?)\s*[\r\n]+([\s\S]*?)(?=^###\s*.+?$|^\*\*.+?\*\*|$)/gmi
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
    timeZone: "Europe/Amsterdam", year: "numeric", month: "2-digit", day: "2-digit"
  }).formatToParts(d).reduce((a,p)=>(a[p.type]=p.value,a),{});
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function ensureDir(p){ if(!fs.existsSync(p)) fs.mkdirSync(p,{recursive:true}); }

async function listAllIssues(){
  const out = []; let page = 1;
  for(;;){
    const data = await gh(`/repos/${owner}/${repoName}/issues?state=all&per_page=100&page=${page}`);
    const issuesOnly = data.filter(i => !i.pull_request);
    out.push(...issuesOnly);
    if (data.length < 100) break;
    page++;
  }
  return out;
}

(async function main(){
  const all = await listAllIssues();
  const issues = all.filter(it => (it.labels||[]).some(l => (l.name||"").toLowerCase() === "rapportage"));
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
    const items = (byDate.get(d) || []).sort((a,b)=> (a.groep||'').localeCompare(b.groep||''));
    fs.writeFileSync(`data/${d}.json`, JSON.stringify({ date: d, items }, null, 2));
  }
  fs.writeFileSync("data/latest.json", JSON.stringify({ date: latest, items: byDate.get(latest) }, null, 2));
})().catch(e => { console.error(e); process.exit(1); });
JS

# 4) Dashboard path fix (alleen als hij al bestaat)
if [ -f docs/index.html ]; then
  sed -i 's|\.\./data/latest\.json|\.\/data/latest.json|g' docs/index.html || true
fi

# 5) Commit & push
git add .github/ISSUE_TEMPLATE/rapportage.yml .github/workflows/rapportage-build.yml scripts/build.mjs docs/index.html || true
git commit -m "setup: rapportage workflow + builder + issue form" || echo "No changes"
git push -u origin main

echo "Klaar ✅  -> Maak/bewerk een issue via 'Rapportage sportmoment' en check Actions + docs/data/latest.json + je dashboard."
