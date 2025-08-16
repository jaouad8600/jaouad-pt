#!/usr/bin/env bash
set -euo pipefail

# ==== structuur ====
mkdir -p public app views/{forms,partials} storage/{json,reports} bin
touch storage/.gitkeep

# ==== app/config.php ====
cat > app/config.php <<'PHP'
<?php
// Basisconfig
define('APP_NAME', 'Rapportages (no-DB)');
define('APP_URL', 'http://localhost:8080'); // pas aan indien nodig

// Mail is nu uitgeschakeld (later aan te zetten)
define('MAIL_MODE', 'disabled'); // 'disabled' | 'mail' | 'smtp'
define('SMTP_HOST', 'smtp.office365.com');
define('SMTP_PORT', 587);
define('SMTP_SECURE', 'tls');
define('SMTP_USER', '');
define('SMTP_PASS', '');

// Pad voor opslag
define('STORAGE_JSON', __DIR__ . '/../storage/json');
define('STORAGE_REPORTS', __DIR__ . '/../storage/reports');

// Helpers
function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
PHP

# ==== app/storage.php ====
cat > app/storage.php <<'PHP'
<?php
require_once __DIR__ . '/config.php';

function ensure_dir($p){ if(!is_dir($p)) mkdir($p, 0775, true); }

function save_item(string $type, array $payload): array {
  $date = $payload['date'] ?? date('Y-m-d');
  $dir = rtrim(STORAGE_JSON, '/')."/$type";
  ensure_dir($dir);
  $file = "$dir/$date.json";
  $data = file_exists($file) ? json_decode(file_get_contents($file), true) : [];
  $payload['_ts'] = date('c');
  $data[] = $payload;
  file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
  return [$file, count($data)];
}

function load_items_by_date(string $type, string $date): array {
  $file = rtrim(STORAGE_JSON, '/')."/$type/$date.json";
  if(!file_exists($file)) return [];
  return json_decode(file_get_contents($file), true) ?: [];
}

function list_dates(string $type): array {
  $dir = rtrim(STORAGE_JSON, '/')."/$type";
  if(!is_dir($dir)) return [];
  $files = glob($dir.'/*.json'); sort($files);
  return array_map(fn($f)=>basename($f, '.json'), $files);
}

function latest_date(): ?string {
  $dates = array_unique(array_merge(
    list_dates('sessions'),
    list_dates('incidents'),
    list_dates('nextday')
  ));
  sort($dates);
  return $dates ? end($dates) : null;
}
PHP

# ==== app/report.php ====
cat > app/report.php <<'PHP'
<?php
require_once __DIR__ . '/storage.php';

function build_daily_report_html(string $date): string {
  $sessions  = load_items_by_date('sessions',  $date);
  $incidents = load_items_by_date('incidents', $date);
  $nextday   = load_items_by_date('nextday',   $date);

  ob_start(); ?>
<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="utf-8">
<title>Dagrapport <?=h($date)?></title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body{font-family:system-ui, -apple-system, Segoe UI, Roboto, Inter, sans-serif;background:#0b1220;color:#e5e7eb;margin:0;}
  .wrap{max-width:900px;margin:2rem auto;padding:1rem 1.25rem;}
  h1,h2{margin:.2rem 0;}
  .card{background:#111827;border:1px solid #1f2937;border-radius:12px;margin:1rem 0;padding:1rem;}
  .muted{color:#9aa4b2}
  .grid{display:grid;gap:.5rem;grid-template-columns: 1fr 2fr;}
  .item{padding:.25rem 0;border-bottom:1px dashed #1f2937}
  .item:last-child{border:0}
  a{color:#93c5fd}
</style>
</head>
<body>
<div class="wrap">
  <h1>Dagrapport <?=h($date)?></h1>
  <p class="muted">Gegenereerd: <?=date('d-m-Y H:i:s')?></p>

  <div class="card">
    <h2>Sport/Creatieve sessies (<?=count($sessions)?>)</h2>
    <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
    <?php foreach($sessions as $s): ?>
      <div class="item">
        <div class="grid">
          <div>Groep</div><div><?=h($s['group']??'-')?></div>
          <div>Datum</div><div><?=h($s['date']??'-')?> <?=h($s['time']??'')?></div>
          <div>Aantal jongeren</div><div><?=h($s['count']??'-')?></div>
          <div>Soort</div><div><?=h($s['kind']??'-')?></div>
          <div>Sfeer</div><div><?=h($s['mood']??'-')?></div>
          <div>Interventies</div><div><?=nl2br(h($s['interventions']??''))?></div>
          <div>Verloop</div><div><?=nl2br(h($s['flow']??''))?></div>
          <div>Opmerkingen</div><div><?=nl2br(h($s['notes']??''))?></div>
        </div>
      </div>
    <?php endforeach; ?>
  </div>

  <div class="card">
    <h2>Incidenten (<?=count($incidents)?>)</h2>
    <?php if(!$incidents): ?><p class="muted">Geen incidenten.</p><?php endif; ?>
    <?php foreach($incidents as $i): ?>
      <div class="item">
        <div class="grid">
          <div>Tijd</div><div><?=h($i['time']??'-')?></div>
          <div>Jongere</div><div><?=h($i['y_name']??'-')?></div>
          <div>Omschrijving</div><div><?=nl2br(h($i['summary']??''))?></div>
          <div>Melding gedaan</div><div><?=h($i['reported']??'nee')?></div>
          <div>Gehoord</div><div><?=h($i['heard']??'nee')?></div>
          <div>Maatregel/Straf</div><div><?=h($i['measure']??'nee')?></div>
        </div>
      </div>
    <?php endforeach; ?>
  </div>

  <div class="card">
    <h2>Afspraken voor morgen (<?=count($nextday)?>)</h2>
    <?php if(!$nextday): ?><p class="muted">Geen afspraken.</p><?php endif; ?>
    <?php foreach($nextday as $n): ?>
      <div class="item">
        <div class="grid">
          <div>Groep</div><div><?=h($n['group']??'-')?></div>
          <div>Speciaal</div><div><?=nl2br(h($n['special']??''))?></div>
          <div>Sportafspraken</div><div><?=nl2br(h($n['sports']??''))?></div>
          <div>Afspraken met GL</div><div><?=nl2br(h($n['lead']??''))?></div>
        </div>
      </div>
    <?php endforeach; ?>
  </div>
</div>
</body>
</html>
<?php
  return ob_get_clean();
}

function write_report_file(string $date): string {
  $html = build_daily_report_html($date);
  ensure_dir(STORAGE_REPORTS);
  $file = rtrim(STORAGE_REPORTS,'/')."/$date.html";
  file_put_contents($file, $html);
  return $file;
}
PHP

# ==== views/partials/header.php & footer.php ====
cat > views/partials/header.php <<'PHP'
<?php require_once __DIR__.'/../../app/config.php'; ?>
<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title><?=h(APP_NAME)?></title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
<style>
  :root{--bg:#0b1220;--card:#111827;--muted:#9aa4b2;--text:#e5e7eb;--ok:#22c55e;--warn:#f59e0b}
  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--text);font-family:Inter,system-ui,Segoe UI,Roboto,sans-serif}
  .wrap{max-width:980px;margin:2rem auto;padding:0 1rem}
  a{color:#93c5fd;text-decoration:none}
  .nav{display:flex;gap:.75rem;flex-wrap:wrap;margin-bottom:1rem}
  .btn{display:inline-block;background:#0f172a;border:1px solid #1f2937;padding:.6rem .9rem;border-radius:10px}
  .card{background:var(--card);border:1px solid #1f2937;border-radius:12px;padding:1rem;margin:1rem 0}
  input,select,textarea{width:100%;background:#0f172a;border:1px solid #374151;border-radius:10px;color:var(--text);padding:.6rem}
  label{font-weight:600;margin:.5rem 0 .25rem;display:block}
</style>
</head>
<body>
<div class="wrap">
  <h1><?=h(APP_NAME)?></h1>
  <nav class="nav">
    <a class="btn" href="?p=dashboard">Dashboard</a>
    <a class="btn" href="?p=session">+ Sessie</a>
    <a class="btn" href="?p=incident">+ Incident</a>
    <a class="btn" href="?p=nextday">+ Afspraken morgen</a>
    <a class="btn" href="?p=report&date=<?=date('Y-m-d')?>">Rapport vandaag</a>
  </nav>
PHP

cat > views/partials/footer.php <<'PHP'
  <p style="color:var(--muted);margin-top:2rem">Bestanden worden lokaal bewaard in <code>storage/json</code>. Mail is nu uitgeschakeld.</p>
</div>
</body>
</html>
PHP

# ==== views/forms/session.php ====
cat > views/forms/session.php <<'PHP'
<?php require __DIR__.'/../partials/header.php'; ?>
<div class="card">
  <h2>Nieuw sport/creatief moment</h2>
  <form method="post">
    <input type="hidden" name="__type" value="session">
    <label>Datum</label>
    <input type="date" name="date" value="<?=date('Y-m-d')?>" required>
    <label>Tijd</label>
    <input type="time" name="time" value="<?=date('H:i')?>">
    <label>Groep</label>
    <input name="group" placeholder="Bijv. Groep A" required>
    <label>Aantal jongeren</label>
    <input type="number" name="count" min="0" value="0">
    <label>Soort</label>
    <select name="kind">
      <option>Sport</option>
      <option>Creatief</option>
    </select>
    <label>Sfeer op de groep</label>
    <input name="mood" placeholder="Bijv. rustig/druk/positief">
    <label>Interventies</label>
    <textarea name="interventions" rows="2"></textarea>
    <label>Verloop van de sessie</label>
    <textarea name="flow" rows="3"></textarea>
    <label>Opmerkingen</label>
    <textarea name="notes" rows="2"></textarea>
    <div style="margin-top:.75rem"><button class="btn">Opslaan</button></div>
  </form>
</div>
<?php require __DIR__.'/../partials/footer.php'; ?>
PHP

# ==== views/forms/incident.php ====
cat > views/forms/incident.php <<'PHP'
<?php require __DIR__.'/../partials/header.php'; ?>
<div class="card">
  <h2>Incident</h2>
  <form method="post">
    <input type="hidden" name="__type" value="incident">
    <label>Datum</label>
    <input type="date" name="date" value="<?=date('Y-m-d')?>" required>
    <label>Tijdstip</label>
    <input type="time" name="time" value="<?=date('H:i')?>">
    <label>Voor- en achternaam jongere</label>
    <input name="y_name" required>
    <label>Korte omschrijving</label>
    <textarea name="summary" rows="3"></textarea>
    <label>Incidentmelding gedaan?</label>
    <select name="reported"><option>nee</option><option>ja</option></select>
    <label>Jongere gehoord?</label>
    <select name="heard"><option>nee</option><option>ja</option></select>
    <label>Ordemaatregel / disciplinaire straf?</label>
    <input name="measure" placeholder="bijv. kamerplaatsing / straf">
    <div style="margin-top:.75rem"><button class="btn">Opslaan</button></div>
  </form>
</div>
<?php require __DIR__.'/../partials/footer.php'; ?>
PHP

# ==== views/forms/nextday.php ====
cat > views/forms/nextday.php <<'PHP'
<?php require __DIR__.'/../partials/header.php'; ?>
<div class="card">
  <h2>Afspraken voor morgen</h2>
  <form method="post">
    <input type="hidden" name="__type" value="nextday">
    <label>Datum (van vandaag)</label>
    <input type="date" name="date" value="<?=date('Y-m-d')?>" required>
    <label>Groep</label>
    <input name="group" placeholder="Bijv. Groep A" required>
    <label>Speciale aandachtspunten</label>
    <textarea name="special" rows="2"></textarea>
    <label>Sportafspraken</label>
    <textarea name="sports" rows="2"></textarea>
    <label>Afspraken met groepsleiding</label>
    <textarea name="lead" rows="2"></textarea>
    <div style="margin-top:.75rem"><button class="btn">Opslaan</button></div>
  </form>
</div>
<?php require __DIR__.'/../partials/footer.php'; ?>
PHP

# ==== views/dashboard.php ====
cat > views/dashboard.php <<'PHP'
<?php
require __DIR__.'/partials/header.php';
require_once __DIR__.'/../app/storage.php';

$today = date('Y-m-d');
$latest = latest_date() ?? $today;
$sessions  = load_items_by_date('sessions',  $latest);
$incidents = load_items_by_date('incidents', $latest);
$nextday   = load_items_by_date('nextday',   $latest);
?>
<div class="card">
  <h2>Live (<?=h($latest)?>)</h2>
  <p>Sessies: <?=count($sessions)?> • Incidenten: <?=count($incidents)?> • Afspraken morgen: <?=count($nextday)?></p>
  <p><a class="btn" href="?p=report&date=<?=h($latest)?>">Toon dagrapport</a></p>
</div>
<div class="card">
  <h3>Sessies (<?=count($sessions)?>)</h3>
  <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
  <ul><?php foreach($sessions as $s): ?>
     <li><?=h($s['date'])?> <?=h($s['time']??'')?> — <?=h($s['group']??'-')?> (<?=h($s['kind']??'-')?>)</li>
  <?php endforeach; ?></ul>
</div>
<div class="card">
  <h3>Incidenten (<?=count($incidents)?>)</h3>
  <?php if(!$incidents): ?><p class="muted">Geen incidenten.</p><?php endif; ?>
  <ul><?php foreach($incidents as $i): ?>
     <li><?=h($i['time']??'')?> — <?=h($i['y_name']??'-')?> — <?=h($i['summary']??'')?></li>
  <?php endforeach; ?></ul>
</div>
<div class="card">
  <h3>Afspraken voor morgen (<?=count($nextday)?>)</h3>
  <?php if(!$nextday): ?><p class="muted">Geen afspraken.</p><?php endif; ?>
  <ul><?php foreach($nextday as $n): ?>
     <li><?=h($n['group']??'-')?> — <?=h($n['special']??'')?></li>
  <?php endforeach; ?></ul>
</div>
<?php require __DIR__.'/partials/footer.php'; ?>
PHP

# ==== public/index.php (router) ====
cat > public/index.php <<'PHP'
<?php
require_once __DIR__.'/../app/config.php';
require_once __DIR__.'/../app/storage.php';
require_once __DIR__.'/../app/report.php';

$view = $_GET['p'] ?? 'dashboard';

if($_SERVER['REQUEST_METHOD']==='POST'){
  $type = $_POST['__type'] ?? '';
  if($type==='session'){
    save_item('sessions', [
      'date'=>$_POST['date']??date('Y-m-d'),
      'time'=>$_POST['time']??'',
      'group'=>$_POST['group']??'',
      'count'=>$_POST['count']??'0',
      'kind'=>$_POST['kind']??'Sport',
      'mood'=>$_POST['mood']??'',
      'interventions'=>$_POST['interventions']??'',
      'flow'=>$_POST['flow']??'',
      'notes'=>$_POST['notes']??'',
    ]);
    header('Location: ?p=dashboard'); exit;
  }
  if($type==='incident'){
    save_item('incidents', [
      'date'=>$_POST['date']??date('Y-m-d'),
      'time'=>$_POST['time']??'',
      'y_name'=>$_POST['y_name']??'',
      'summary'=>$_POST['summary']??'',
      'reported'=>$_POST['reported']??'nee',
      'heard'=>$_POST['heard']??'nee',
      'measure'=>$_POST['measure']??'nee',
    ]);
    header('Location: ?p=dashboard'); exit;
  }
  if($type==='nextday'){
    save_item('nextday', [
      'date'=>$_POST['date']??date('Y-m-d'),
      'group'=>$_POST['group']??'',
      'special'=>$_POST['special']??'',
      'sports'=>$_POST['sports']??'',
      'lead'=>$_POST['lead']??'',
    ]);
    header('Location: ?p=dashboard'); exit;
  }
}

if($view==='session'){ require __DIR__.'/../views/forms/session.php'; exit; }
if($view==='incident'){ require __DIR__.'/../views/forms/incident.php'; exit; }
if($view==='nextday'){ require __DIR__.'/../views/forms/nextday.php'; exit; }
if($view==='dashboard'){ require __DIR__.'/../views/dashboard.php'; exit; }
if($view==='report'){
  $d = $_GET['date'] ?? date('Y-m-d');
  echo build_daily_report_html($d);
  exit;
}

http_response_code(404);
echo "404 - Not found";
PHP

# ==== bin/run-daily-report.php ====
cat > bin/run-daily-report.php <<'PHP'
<?php
require_once __DIR__.'/../app/report.php';
$date = $argv[1] ?? date('Y-m-d');
$file = write_report_file($date);
fwrite(STDOUT, "Report written: $file\n");
PHP

# ==== bin/install-cron.sh ====
cat > bin/install-cron.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PHPBIN="${PHPBIN:-php}"
# elke dag 18:00
( crontab -l 2>/dev/null | grep -v run-daily-report.php ; echo "0 18 * * * cd \"$(dirname "$HERE")\" && $PHPBIN bin/run-daily-report.php >> storage/reports/cron.log 2>&1" ) | crontab -
echo "Cron ingesteld voor 18:00."
