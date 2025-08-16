#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs/assets

# --- docs/index.html ----------------------------------------------------------
cat > docs/index.html <<'HTML'
<!DOCTYPE html>
<html lang="nl" data-theme="auto">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Rapportages — Jaouad PT</title>
  <meta name="description" content="Dagelijkse rapportages van sessies en bijzonderheden." />
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="./assets/styles.css?v=1" />
</head>
<body>
  <header class="appbar">
    <div class="container row between center">
      <div class="brand row center gap-8">
        <span class="logo">🏋️</span>
        <div>
          <div class="title">Rapportages</div>
          <div class="subtitle">Live vanuit <code>docs/data/latest.json</code></div>
        </div>
      </div>
      <nav class="row center gap-8">
        <button id="btn-refresh" class="btn ghost" title="Verversen">↻ Verversen</button>
        <button id="btn-print" class="btn ghost" title="Print dagrapport">🖨 Print</button>
        <button id="btn-theme" class="btn" title="Thema wisselen">🌙/☀️</button>
      </nav>
    </div>
  </header>

  <main class="container space-16">
    <section class="controls card">
      <div class="row wrap gap-12">
        <div class="control">
          <label for="date">Datum</label>
          <input id="date" type="date" />
        </div>
        <div class="control flex-1">
          <label for="search">Zoeken (groep, begeleider, activiteit, tekst)</label>
          <input id="search" type="search" placeholder="Typ om te filteren…" />
        </div>
        <div class="control">
          <label for="group">Filter groep</label>
          <select id="group">
            <option value="">Alle groepen</option>
          </select>
        </div>
        <div class="control">
          <label for="hasIncident">Bijzonderheden</label>
          <select id="hasIncident">
            <option value="">Alles</option>
            <option value="ja">Alleen met bijzonderheden</option>
            <option value="nee">Zonder bijzonderheden</option>
          </select>
        </div>
        <div class="ml-auto row gap-8">
          <a class="btn primary" id="btn-new" target="_blank" rel="noopener">+ Nieuw rapport (GitHub)</a>
          <a class="btn" id="btn-json" target="_blank" rel="noopener">Open JSON</a>
        </div>
      </div>
    </section>

    <section id="kpis" class="grid kpis">
      <!-- KPI cards worden via JS gevuld -->
      <div class="card skeleton"></div>
      <div class="card skeleton"></div>
      <div class="card skeleton"></div>
    </section>

    <section class="card">
      <div class="row between center">
        <h2 class="h2" id="heading">Dagoverzicht</h2>
        <div class="muted" id="meta">—</div>
      </div>
      <div id="list" class="list"></div>
      <div id="empty" class="empty hidden">Geen items voor deze dag.</div>
      <div id="error" class="error hidden"></div>
    </section>
  </main>

  <footer class="container footer">
    <div>© <span id="year"></span> Jaouad PT</div>
    <div class="muted">Thema-toggle onthoudt je keuze. Printvriendelijk dagoverzicht.</div>
  </footer>

  <!-- Modal -->
  <dialog id="modal" class="modal">
    <form method="dialog" class="modal-box">
      <button class="modal-close" aria-label="Sluiten">✕</button>
      <div id="modal-body"></div>
      <div class="row end mt-16">
        <button class="btn" value="cancel">Sluiten</button>
      </div>
    </form>
    <div class="modal-backdrop"></div>
  </dialog>

  <script src="./assets/app.js?v=1" defer></script>
</body>
</html>
HTML

# --- docs/assets/styles.css ---------------------------------------------------
cat > docs/assets/styles.css <<'CSS'
:root{
  --bg:#0b1220; --bg-soft:#0f172a; --card:#111827; --line:rgba(255,255,255,.08);
  --text:#e5e7eb; --muted:#9aa4b2; --primary:#2563eb; --ok:#22c55e; --warn:#f59e0b;
  --shadow:0 20px 40px -20px rgba(0,0,0,.35);
}
html[data-theme="light"]{
  --bg:#f6f8fb; --bg-soft:#ffffff; --card:#ffffff; --line:rgba(10,10,10,.08);
  --text:#0f172a; --muted:#596274; --primary:#2563eb; --ok:#15803d; --warn:#b45309;
  --shadow:0 20px 40px -20px rgba(0,0,0,.15);
}
*{box-sizing:border-box}
html,body{height:100%}
body{
  margin:0; font-family:Inter,system-ui,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
  background:linear-gradient(180deg,var(--bg) 0%,var(--bg-soft) 100%); color:var(--text);
}
.container{max-width:1100px; margin-inline:auto; padding:16px}
.row{display:flex; gap:8px}
.wrap{flex-wrap:wrap}
.between{justify-content:space-between}
.center{align-items:center}
.end{justify-content:flex-end}
.gap-8{gap:8px} .gap-12{gap:12px} .space-16{margin-top:16px}
.ml-auto{margin-left:auto}
.mt-16{margin-top:16px}

.appbar{position:sticky; top:0; z-index:10; backdrop-filter:saturate(180%) blur(8px);
  background:color-mix(in oklab, var(--bg) 70%, transparent);
  border-bottom:1px solid var(--line)}
.brand .logo{font-size:26px}
.title{font-weight:700}
.subtitle{font-size:12px; color:var(--muted)}
.footer{display:flex; justify-content:space-between; padding:24px 16px; color:var(--muted)}

.card{
  background:var(--card); border:1px solid var(--line);
  border-radius:16px; padding:16px; box-shadow:var(--shadow);
}
.kpis{display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:16px}
.kpi .value{font-size:28px; font-weight:700}
.kpi .label{color:var(--muted); font-size:13px; margin-top:2px}

.controls .control{display:flex; flex-direction:column; min-width:220px}
.controls label{font-size:12px; color:var(--muted); margin-bottom:6px}
input,select{
  background:transparent; border:1px solid var(--line); color:var(--text);
  border-radius:12px; padding:10px 12px; outline:none;
}
input::placeholder{color:var(--muted)}
.btn{
  background:var(--card); color:var(--text); border:1px solid var(--line);
  padding:10px 14px; border-radius:14px; cursor:pointer;
}
.btn:hover{transform:translateY(-1px)}
.btn.primary{background:var(--primary); border-color:transparent}
.btn.ghost{background:transparent}

.list{display:grid; gap:12px; margin-top:12px}
.item{
  display:grid; grid-template-columns:1fr auto; gap:12px;
  padding:14px; border:1px solid var(--line); border-radius:14px; background:color-mix(in oklab, var(--card) 96%, transparent);
}
.item .title{font-weight:600}
.badges{display:flex; gap:6px; flex-wrap:wrap}
.badge{font-size:12px; padding:4px 8px; border-radius:999px; border:1px solid var(--line); color:var(--muted)}
.badge.ok{background:color-mix(in oklab, var(--ok) 20%, transparent); color:#d1fae5; border-color:transparent}
.badge.warn{background:color-mix(in oklab, var(--warn) 25%, transparent); color:#fff; border-color:transparent}
.meta{color:var(--muted); font-size:12px}

.empty,.error{padding:14px; border-radius:12px; margin-top:12px}
.empty{border:1px dashed var(--line); color:var(--muted)}
.error{border:1px solid #ef4444; background: color-mix(in oklab, #ef4444 14%, transparent)}

.skeleton{min-height:84px; position:relative; overflow:hidden}
.skeleton::after{
  content:""; position:absolute; inset:0;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.07), transparent);
  animation:shimmer 1.5s infinite;
}
@keyframes shimmer{0%{transform:translateX(-100%)}100%{transform:translateX(100%)}}

.modal{border:0; padding:0; background:transparent}
.modal[open] .modal-backdrop{position:fixed; inset:0; background:rgba(0,0,0,.45)}
.modal-box{
  width:min(720px, 96vw); border:1px solid var(--line); border-radius:20px;
  background:var(--card); padding:20px; margin:auto; position:fixed; inset: 10% 0 auto; box-shadow:var(--shadow);
}
.modal-close{position:absolute; top:10px; right:10px; border:0; background:transparent; color:var(--muted); font-size:18px; cursor:pointer}

.h2{font-size:18px; font-weight:700}
.muted{color:var(--muted)}
.hidden{display:none}
@media (max-width:900px){ .kpis{grid-template-columns:1fr} .item{grid-template-columns:1fr} }
CSS

# --- docs/assets/app.js -------------------------------------------------------
cat > docs/assets/app.js <<'JS'
(() => {
  const $ = sel => document.querySelector(sel);
  const $$ = sel => Array.from(document.querySelectorAll(sel));
  const state = {
    date: null,
    data: { date: null, items: [] },
    theme: null,
    filters: { search: "", group: "", hasIncident: "" }
  };

  const els = {
    date: $("#date"),
    search: $("#search"),
    group: $("#group"),
    hasIncident: $("#hasIncident"),
    kpis: $("#kpis"),
    list: $("#list"),
    empty: $("#empty"),
    error: $("#error"),
    meta: $("#meta"),
    heading: $("#heading"),
    btnRefresh: $("#btn-refresh"),
    btnPrint: $("#btn-print"),
    btnTheme: $("#btn-theme"),
    btnJson: $("#btn-json"),
    btnNew: $("#btn-new"),
    modal: $("#modal"),
    modalBody: $("#modal-body"),
    year: $("#year"),
  };

  // ---------- THEME ----------
  function initTheme(){
    const saved = localStorage.getItem("theme");
    if (saved === "light" || saved === "dark") {
      document.documentElement.setAttribute("data-theme", saved);
      state.theme = saved;
    } else {
      // auto: dark by prefers-color-scheme
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      const mode = prefersDark ? "dark" : "light";
      document.documentElement.setAttribute("data-theme", mode);
      state.theme = mode;
    }
    els.btnTheme.addEventListener("click", () => {
      state.theme = state.theme === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", state.theme);
      localStorage.setItem("theme", state.theme);
    });
  }

  // ---------- FETCH ----------
  async function fetchJsonForDate(dateStr){
    // Probeer specifieke datum, anders fallback naar latest
    const base = "./data";
    const tryUrl = dateStr ? `${base}/${dateStr}.json` : `${base}/latest.json`;
    const url = `${tryUrl}?t=${Date.now()}`; // cache buster
    const r = await fetch(url);
    if (!r.ok) {
      if (dateStr) { // fallback
        const rl = await fetch(`${base}/latest.json?t=${Date.now()}`);
        if (!rl.ok) throw new Error(`Kon JSON niet laden (status ${rl.status}).`);
        return rl.json();
      }
      throw new Error(`Kon JSON niet laden (status ${r.status}).`);
    }
    return r.json();
  }

  function normalizeItem(it){
    // JSON keys uit workflow/issue:
    // id, url, updated_at, datum, tijdvak, groep, begeleider, activiteit, opkomst, inhoud, bijzonderheden, vervolg
    const clean = k => (it[k] || "").toString().trim();
    const hasIncident = !!clean("bijzonderheden") && clean("bijzonderheden").toLowerCase() !== "geen";
    return {
      id: it.id,
      url: it.url,
      updated_at: it.updated_at,
      date: clean("datum"),
      time: clean("tijdvak"),
      group: clean("groep"),
      coach: clean("begeleider"),
      activity: clean("activiteit"),
      attendance: clean("opkomst"),
      content: clean("inhoud"),
      incident: clean("bijzonderheden"),
      followup: clean("vervolg"),
      hasIncident
    };
  }

  // ---------- RENDER ----------
  function renderKpis(items){
    const total = items.length;
    const withInc = items.filter(x=>x.hasIncident).length;
    const groups = new Set(items.map(x=>x.group).filter(Boolean));
    els.kpis.innerHTML = `
      <div class="card kpi">
        <div class="value">${total}</div>
        <div class="label">Totaal items</div>
      </div>
      <div class="card kpi">
        <div class="value">${withInc}</div>
        <div class="label">Met bijzonderheden</div>
      </div>
      <div class="card kpi">
        <div class="value">${groups.size}</div>
        <div class="label">Aantal groepen</div>
      </div>
    `;
  }

  function badge(text, cls=""){ return `<span class="badge ${cls}">${text}</span>`; }

  function itemRow(x){
    const tags = [
      x.group ? badge(x.group) : "",
      x.activity ? badge(x.activity) : "",
      x.hasIncident ? badge("bijzonderheden", "warn") : badge("ok", "ok")
    ].join("");
    const meta = [x.time || "—", x.coach || "—"].filter(Boolean).join(" · ");
    return `
      <article class="item" role="button" tabindex="0" data-id="${x.id}">
        <div>
          <div class="title">${x.group || "—"} — ${x.date}</div>
          <div class="meta">${meta}</div>
          <div class="badges mt-16">${tags}</div>
        </div>
        <div class="row center gap-8">
          <a href="${x.url}" target="_blank" rel="noopener" class="btn">Naar issue #${x.id}</a>
          <button class="btn ghost" data-open="${x.id}">Details</button>
        </div>
      </article>
    `;
  }

  function renderList(items){
    if (!items.length){
      els.list.innerHTML = "";
      els.empty.classList.remove("hidden");
      return;
    }
    els.empty.classList.add("hidden");
    els.list.innerHTML = items.map(itemRow).join("");
    // Koppel modal handlers
    $$("#list [data-open]").forEach(btn=>{
      btn.addEventListener("click", (e)=>{
        const id = btn.getAttribute("data-open");
        openModal(items.find(x=>String(x.id)===String(id)));
      });
    });
    // Enter/Space open via article
    $$("#list .item").forEach(el=>{
      el.addEventListener("keydown",(ev)=>{
        if (ev.key==="Enter" || ev.key===" "){
          const id = el.getAttribute("data-id");
          openModal(items.find(x=>String(x.id)===String(id)));
          ev.preventDefault();
        }
      });
      el.addEventListener("click", ()=>{
        const id = el.getAttribute("data-id");
        openModal(items.find(x=>String(x.id)===String(id)));
      });
    });
  }

  function renderMeta(payload){
    const dt = payload.date ? new Date().toLocaleString("nl-NL") : "—";
    const count = payload.items.length;
    els.heading.textContent = `Dagoverzicht — ${payload.date ?? "onbekend"}`;
    els.meta.textContent = `Laatste update: ${new Date().toLocaleString("nl-NL")} • ${count} item(s)`;
  }

  function populateFilters(items){
    // Groepen
    const groups = [...new Set(items.map(x=>x.group).filter(Boolean))].sort((a,b)=>a.localeCompare(b));
    els.group.innerHTML = `<option value="">Alle groepen</option>` + groups.map(g=>`<option value="${escapeHtml(g)}">${escapeHtml(g)}</option>`).join("");
  }

  function escapeHtml(s){ return (s||"").replace(/[&<>"']/g, m=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[m])); }

  // ---------- MODAL ----------
  function openModal(x){
    if (!x) return;
    els.modalBody.innerHTML = `
      <h3 class="h2">${escapeHtml(x.group)} — ${escapeHtml(x.date)}</h3>
      <p class="meta">${escapeHtml(x.time || "—")} · ${escapeHtml(x.coach || "—")} · ${escapeHtml(x.activity || "—")}</p>
      <div class="row gap-8 mt-16 badges">
        ${x.hasIncident ? badge("bijzonderheden","warn") : badge("ok","ok")}
      </div>
      <div class="mt-16"><strong>Opkomst:</strong><br>${escapeHtml(x.attendance || "—")}</div>
      <div class="mt-16"><strong>Inhoud & verloop:</strong><br>${escapeHtml(x.content || "—")}</div>
      <div class="mt-16"><strong>Bijzonderheden / incidenten:</strong><br>${escapeHtml(x.incident || "—")}</div>
      <div class="mt-16"><strong>Vervolgacties:</strong><br>${escapeHtml(x.followup || "—")}</div>
      <div class="row end mt-16">
        <a class="btn" target="_blank" rel="noopener" href="${x.url}">Open issue #${x.id}</a>
      </div>
    `;
    els.modal.showModal();
  }
  $("#modal .modal-close")?.addEventListener("click", ()=> els.modal.close());
  $(".modal-backdrop")?.addEventListener("click", ()=> els.modal.close());

  // ---------- FILTERING ----------
  function applyFilters(items){
    const q = state.filters.search.trim().toLowerCase();
    const group = state.filters.group;
    const inc = state.filters.hasIncident;
    return items.filter(x=>{
      if (group && x.group !== group) return false;
      if (inc === "ja" && !x.hasIncident) return false;
      if (inc === "nee" && x.hasIncident) return false;
      if (q){
        const blob = [x.group,x.coach,x.activity,x.attendance,x.content,x.incident,x.followup].join(" ").toLowerCase();
        if (!blob.includes(q)) return false;
      }
      return true;
    });
  }

  // ---------- LOAD ----------
  async function load(dateStr){
    els.error.classList.add("hidden");
    els.kpis.innerHTML = `<div class="card skeleton"></div><div class="card skeleton"></div><div class="card skeleton"></div>`;
    els.list.innerHTML = "";
    els.empty.classList.add("hidden");

    try{
      const payload = await fetchJsonForDate(dateStr);
      state.data = { date: payload.date ?? null, items: (payload.items||[]).map(normalizeItem) };
      renderMeta(state.data);
      populateFilters(state.data.items);
      const filtered = applyFilters(state.data.items);
      renderKpis(filtered);
      renderList(filtered);
      // Links (JSON & New)
      const base = "./data";
      const jsonUrl = state.date ? `${base}/${state.date}.json` : `${base}/latest.json`;
      els.btnJson.href = jsonUrl + `?t=${Date.now()}`;
      els.btnNew.href = "https://github.com/jaouad8600/jaouad-pt/issues/new?labels=rapportage&template=rapportage.yml&title=%5BRapportage%5D%20Groep%20—%20YYYY-MM-DD%20—%20Begeleider";
    }catch(e){
      els.error.textContent = (e && e.message) ? e.message : "Onbekende fout bij laden.";
      els.error.classList.remove("hidden");
    }
  }

  // ---------- INIT ----------
  function init(){
    els.year.textContent = String(new Date().getFullYear());
    initTheme();
    // default date = vandaag (probeer YYYY-MM-DD), anders laat latest.json
    const today = new Date().toISOString().slice(0,10);
    state.date = today;
    els.date.value = today;

    // Handlers
    els.date.addEventListener("change", () => {
      state.date = els.date.value || null;
      load(state.date);
    });
    els.search.addEventListener("input", () => {
      state.filters.search = els.search.value;
      const filtered = applyFilters(state.data.items);
      renderKpis(filtered); renderList(filtered);
    });
    els.group.addEventListener("change", ()=>{
      state.filters.group = els.group.value;
      const filtered = applyFilters(state.data.items);
      renderKpis(filtered); renderList(filtered);
    });
    els.hasIncident.addEventListener("change", ()=>{
      state.filters.hasIncident = els.hasIncident.value;
      const filtered = applyFilters(state.data.items);
      renderKpis(filtered); renderList(filtered);
    });
    els.btnRefresh.addEventListener("click", ()=> load(state.date));
    els.btnPrint.addEventListener("click", ()=> window.print());

    load(state.date);
  }

  document.addEventListener("DOMContentLoaded", init);
})();
JS

git add docs/index.html docs/assets/styles.css docs/assets/app.js
git commit -m "UI: Pro dashboard (dark/light, filters, modal, search, print, skeletons)"
git push origin main
echo
echo "Klaar ✅  Open je pagina met cache-bust:"
echo "https://jaouad8600.github.io/jaouad-pt/?v=$(date +%s)"
