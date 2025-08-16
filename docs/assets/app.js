(function () {
  const $ = (q, r = document) => r.querySelector(q);
  const $$ = (q, r = document) => Array.from(r.querySelectorAll(q));
  const state = {
    raw: null,
    items: [],
    filtered: [],
    groups: [],
    theme: 'auto',
  };

  // ------- Theme ----------
  function applyTheme(t) {
    document.documentElement.setAttribute('data-theme', t);
    state.theme = t;
    localStorage.setItem('theme', t);
  }
  (function initTheme(){
    const saved = localStorage.getItem('theme') || 'auto';
    applyTheme(saved);
  })();

  // ------- UI helpers -----
  const toast = (msg) => {
    const el = $('#toast');
    el.textContent = msg;
    el.classList.add('show');
    setTimeout(() => el.classList.remove('show'), 1600);
  };
  const safe = (s='') => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

  // ------- Rendering -------
  function renderMeta() {
    $('#datePill').textContent = `Datum: ${state.raw?.date ?? '—'}`;
    $('#countPill').textContent = `${state.filtered.length} item(s)`;
    const dt = new Date();
    $('#updatedAt').textContent = dt.toLocaleString('nl-NL', { hour12:false });
  }

  function renderGroupFilter() {
    const select = $('#groupSelect');
    select.innerHTML = '<option value="">Alle groepen</option>' +
      state.groups.map(g => `<option value="${safe(g)}">${safe(g)}</option>`).join('');
  }

  function renderGrid() {
    const grid = $('#grid');
    if (!state.filtered.length) {
      grid.innerHTML = '';
      $('#emptyState').classList.remove('hidden');
      return;
    }
    $('#emptyState').classList.add('hidden');

    const cards = state.filtered.map(it => {
      const lines = [
        `<div class="kv"><div class="k">Begeleider</div><div class="v">${safe(it.begeleider)}</div></div>`,
        `<div class="kv"><div class="k">Tijd</div><div class="v">${safe(it.tijdvak || '—')}</div></div>`,
        `<div class="kv"><div class="k">Activiteit</div><div class="v">${safe(it.activiteit || '—')}</div></div>`,
        `<div class="kv"><div class="k">Opkomst</div><div class="v">${safe(it.opkomst || '—')}</div></div>`,
      ].join('');

      const blocks = [
        it.inhoud ? `<div class="kv"><div class="k">Inhoud</div><div class="v">${safe(it.inhoud)}</div></div>` : '',
        it.bijzonderheden ? `<div class="kv"><div class="k">Bijzonder</div><div class="v">${safe(it.bijzonderheden)}</div></div>` : '',
        it.vervolg ? `<div class="kv"><div class="k">Vervolg</div><div class="v">${safe(it.vervolg)}</div></div>` : '',
      ].join('');

      return `
      <article class="card">
        <div class="head">
          <div class="title-lg">${safe(it.groep || '—')}</div>
          <span class="tag">${safe(state.raw?.date || '—')}</span>
        </div>
        ${lines}
        ${blocks}
        <div class="actions">
          <a class="btn btn-primary" href="${safe(it.url)}" target="_blank" rel="noopener">Open issue #${safe(it.id)}</a>
          <button class="btn btn-outline" data-copy="${safe(it.url)}">Kopieer link</button>
        </div>
      </article>`;
    }).join('');

    grid.innerHTML = cards;

    // bind copy buttons
    $$('.actions [data-copy]').forEach(btn => {
      btn.addEventListener('click', async () => {
        try {
          await navigator.clipboard.writeText(btn.getAttribute('data-copy') || '');
          toast('Link gekopieerd ✔');
        } catch {
          toast('Kopiëren mislukt');
        }
      });
    });
  }

  // ------- Filtering -------
  function applyFilters() {
    const term = ($('#searchInput').value || '').toLowerCase().trim();
    const group = $('#groupSelect').value || '';

    let arr = [...(state.items || [])];
    if (group) arr = arr.filter(x => (x.groep || '').toLowerCase() === group.toLowerCase());
    if (term) {
      arr = arr.filter(x => {
        const bag = [
          x.groep, x.begeleider, x.activiteit, x.opkomst, x.inhoud, x.bijzonderheden, x.vervolg
        ].join(' ').toLowerCase();
        return bag.includes(term);
      });
    }
    state.filtered = arr;
    renderMeta();
    renderGrid();
  }

  // ------- Data fetch -------
  async function loadData() {
    // skeletons visible by default; clear grid on success
    const url = `./data/latest.json?t=${Date.now()}`; // bust cache
    const res = await fetch(url, { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();

    state.raw = json;
    state.items = Array.isArray(json.items) ? json.items : [];
    state.groups = Array.from(new Set(state.items.map(x => (x.groep || '').trim()).filter(Boolean))).sort((a,b)=>a.localeCompare(b,'nl'));

    renderGroupFilter();
    state.filtered = state.items;
    renderMeta();
    renderGrid();
  }

  // ------- Events ----------
  $('#themeBtn')?.addEventListener('click', () => {
    const curr = state.theme || 'auto';
    const next = curr === 'auto' ? 'light' : curr === 'light' ? 'dark' : 'auto';
    applyTheme(next);
    toast(`Thema: ${next}`);
  });
  $('#refreshBtn')?.addEventListener('click', () => {
    loadData().then(()=>toast('Gegevens vernieuwd'));
  });
  $('#searchInput').addEventListener('input', applyFilters);
  $('#groupSelect').addEventListener('change', applyFilters);
  $('#clearFilters').addEventListener('click', () => {
    $('#searchInput').value = ''; $('#groupSelect').value = ''; applyFilters();
  });
  $('#clearNow').addEventListener('click', () => {
    $('#searchInput').value = ''; $('#groupSelect').value = ''; applyFilters();
  });

  // ------- Init ------------
  document.addEventListener('DOMContentLoaded', loadData);
})();
