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
