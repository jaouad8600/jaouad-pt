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

function parseIssueBody(body="") {
  const out = {}, map = {
    Datum:"datum", Tijd:"tijdvak", Groep:"groep", Begeleider:"begeleider",
    Activiteit:"activiteit", Opkomst:"opkomst", "Inhoud & verloop":"inhoud",
    "Bijzonderheden / incidenten":"bijzonderheden", Vervolgacties:"vervolg"
  };
  const re=/\*\*(.+?)\*\*[\r\n]+([\s\S]*?)(?=(\*\*.+?\*\*)|$)/g; let m;
  while ((m=re.exec(body))) { const k = map[m[1].trim()]; if (k) out[k]=m[2].trim(); }
  return out;
}
function toDateNL(s){ if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  const d=new Date(s); const p= new Intl.DateTimeFormat("nl-NL",{timeZone:"Europe/Amsterdam",year:"numeric",month:"2-digit",day:"2-digit"}).formatToParts(d)
    .reduce((a,p)=>(a[p.type]=p.value,a),{}); return `${p.year}-${p.month}-${p.day}`; }
function ensureDir(p){ if(!fs.existsSync(p)) fs.mkdirSync(p,{recursive:true}); }

async function listIssues(){
  const per=100; let page=1, all=[];
  while(true){ const d=await gh(`/repos/${owner}/${repoName}/issues?state=all&labels=rapportage&per_page=${per}&page=${page}`);
    all.push(...d); if (d.length<per) break; page++; } return all;
}

(async function(){
  const issues = await listIssues();
  const byDate = new Map();
  for (const issue of issues){
    const payload = parseIssueBody(issue.body);
    if(!payload.datum) continue;
    const d = toDateNL(payload.datum);
    const arr = byDate.get(d)||[];
    arr.push({ id: issue.number, url: issue.html_url, updated_at: issue.updated_at, ...payload });
    byDate.set(d, arr);
  }
  ensureDir("data");
  if (byDate.size===0){ fs.writeFileSync("data/latest.json", JSON.stringify({date:null, items:[]},null,2)); return; }
  const dates=[...byDate.keys()].sort(); const latest=dates.at(-1);
  for (const d of dates){
    const items=(byDate.get(d)||[]).sort((a,b)=> (a.groep||'').localeCompare(b.groep||'')); 
    fs.writeFileSync(`data/${d}.json`, JSON.stringify({date:d, items}, null, 2));
  }
  fs.writeFileSync("data/latest.json", JSON.stringify({date:latest, items:byDate.get(latest)}, null, 2));
})();
