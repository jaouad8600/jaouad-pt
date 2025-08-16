#!/usr/bin/env bash
set -euo pipefail

# Structuur
mkdir -p public app/{controllers,core,services} views/{partials,pages,forms} storage/{json,reports} bin
touch storage/.gitkeep

# ---------------- app/core/config.php ----------------
cat > app/core/config.php <<'PHP'
<?php
// App
const APP_NAME = 'Teylingereind Rapportages (no-DB)';
const APP_BRAND = 'Teylingereind';
const APP_TIMEZONE = 'Europe/Amsterdam';
const APP_BASEURL = ''; // leeg als je in root draait (http://localhost:8080)

// Mail (nu uit, later DB/SMPP/SMTP kan)
const MAIL_MODE = 'disabled'; // 'disabled'|'mail'|'smtp'
const MAIL_FROM = 'noreply@example.org';
const MAIL_TO   = 'team@example.org';
const SMTP_HOST = 'smtp.office365.com';
const SMTP_PORT = 587;
const SMTP_SEC  = 'tls';
const SMTP_USER = '';
const SMTP_PASS = '';

// Opslag
define('STORAGE_JSON', __DIR__ . '/../../storage/json');
define('STORAGE_REPORTS', __DIR__ . '/../../storage/reports');

// Security
const APP_SESSION_NAME = 'tey_rep_sess';
const CSRF_KEY = 'csrf_token';

date_default_timezone_set(APP_TIMEZONE);
PHP

# ---------------- app/core/helpers.php ----------------
cat > app/core/helpers.php <<'PHP'
<?php
require_once __DIR__.'/config.php';

function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
function redirect(string $path){ header("Location: ".$path); exit; }
function baseurl(string $path=''){ return APP_BASEURL.$path; }

function ensure_dir($p){ if(!is_dir($p)) mkdir($p, 0775, true); }

function uuid(): string {
  $d = random_bytes(16);
  $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
  $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
  return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

function session_start_safe(){
  if(session_status() !== PHP_SESSION_ACTIVE){
    session_name(APP_SESSION_NAME);
    session_start();
  }
}

function csrf_token(): string {
  session_start_safe();
  if(empty($_SESSION[CSRF_KEY])) $_SESSION[CSRF_KEY] = bin2hex(random_bytes(32));
  return $_SESSION[CSRF_KEY];
}
function csrf_check(string $token): bool {
  session_start_safe();
  return hash_equals($_SESSION[CSRF_KEY] ?? '', $token);
}

function flash(string $key, ?string $msg=null){
  session_start_safe();
  if($msg===null){
    $m = $_SESSION['_flash'][$key] ?? null;
    unset($_SESSION['_flash'][$key]);
    return $m;
  }
  $_SESSION['_flash'][$key] = $msg;
}

function validate(array $data, array $rules): array {
  $errors = [];
  foreach($rules as $field => $rule){
    $val = trim((string)($data[$field] ?? ''));
    foreach(explode('|', $rule) as $r){
      if($r==='required' && $val==='') $errors[$field]='Verplicht veld';
      if(str_starts_with($r,'in:')){
        $ops = explode(',', substr($r,3));
        if($val!=='' && !in_array($val,$ops,true)) $errors[$field]='Ongeldige waarde';
      }
      if($r==='int' && $val!=='' && !preg_match('/^\d+$/',$val)) $errors[$field]='Moet een getal zijn';
    }
  }
  return $errors;
}
PHP

# ---------------- app/services/storage.php ----------------
cat > app/services/storage.php <<'PHP'
<?php
require_once __DIR__.'/../core/helpers.php';

function storage_path(string $type, string $date): string {
  return rtrim(STORAGE_JSON,'/')."/$type/$date.json";
}

function storage_save(string $type, array $payload): array {
  $date = $payload['date'] ?? date('Y-m-d');
  $file = storage_path($type, $date);
  ensure_dir(dirname($file));
  $arr = file_exists($file) ? json_decode(file_get_contents($file), true) : [];
  $payload['_id'] = $payload['_id'] ?? uuid();
  $payload['_ts'] = date('c');
  $arr[] = $payload;
  file_put_contents($file, json_encode($arr,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
  rebuild_latest_index();
  return [$file, count($arr)];
}

function storage_load_by_date(string $type, string $date): array {
  $file = storage_path($type, $date);
  if(!file_exists($file)) return [];
  return json_decode(file_get_contents($file), true) ?: [];
}

function storage_list_dates(string $type): array {
  $dir = rtrim(STORAGE_JSON,'/')."/$type";
  if(!is_dir($dir)) return [];
  $files = glob($dir.'/*.json');
  sort($files);
  return array_map(fn($f)=>basename($f,'.json'), $files);
}

function latest_date(): ?string {
  $dates = array_unique(array_merge(
    storage_list_dates('sessions'),
    storage_list_dates('incidents'),
    storage_list_dates('nextday'),
  ));
  sort($dates);
  return $dates ? end($dates) : null;
}

function rebuild_latest_index(): void {
  $latest = latest_date();
  ensure_dir(STORAGE_JSON);
  $out = ['date'=>null,'sessions'=>[],'incidents'=>[],'nextday'=>[]];
  if($latest){
    $out['date'] = $latest;
    $out['sessions']  = storage_load_by_date('sessions',$latest);
    $out['incidents'] = storage_load_by_date('incidents',$latest);
    $out['nextday']   = storage_load_by_date('nextday',$latest);
  }
  file_put_contents(rtrim(STORAGE_JSON,'/').'/latest.json', json_encode($out, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}
PHP

# ---------------- app/controllers/ReportController.php ----------------
cat > app/controllers/ReportController.php <<'PHP'
<?php
require_once __DIR__.'/../services/storage.php';

function report_build_html(string $date): string {
  $sessions  = storage_load_by_date('sessions',$date);
  $incidents = storage_load_by_date('incidents',$date);
  $nextday   = storage_load_by_date('nextday',$date);

  ob_start(); ?>
<!doctype html>
<html lang="nl">
<head>
  <meta charset="utf-8">
  <title>Dagrapport <?=h($date)?> — <?=h(APP_BRAND)?></title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/@picocss/pico@2/css/pico.min.css">
  <style>
    :root { --pico-font-family: Inter, system-ui, Segoe UI, Roboto, sans-serif; }
    @media print {.no-print{display:none !important}}
    .kpi{display:grid;grid-template-columns:repeat(3,1fr);gap:.8rem}
    .kpi > article {text-align:center}
    .muted{color:#6b7280}
    .mono{font-family: ui-monospace, SFMono-Regular, Menlo, monospace}
  </style>
</head>
<body>
<main class="container">
  <header class="no-print" style="margin-top:1rem">
    <h1>Dagrapport <?=h($date)?></h1>
    <p class="muted">Gegenereerd: <?=date('d-m-Y H:i')?> — <?=h(APP_BRAND)?></p>
    <a role="button" class="secondary" href="<?=h(baseurl('/'))?>">&larr; Terug naar dashboard</a>
    <button class="no-print" onclick="window.print()">Print / PDF</button>
  </header>

  <section class="kpi">
    <article>
      <h2><?=count($sessions)?></h2><small>Sessies</small>
    </article>
    <article>
      <h2><?=count($incidents)?></h2><small>Incidenten</small>
    </article>
    <article>
      <h2><?=count($nextday)?></h2><small>Afspraken morgen</small>
    </article>
  </section>

  <article>
    <h3>Sessies</h3>
    <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
    <?php foreach($sessions as $s): ?>
      <details>
        <summary><strong><?=h($s['date'])?> <?=h($s['time']??'')?> — <?=h($s['group']??'-')?> (<?=h($s['kind']??'-')?>)</strong></summary>
        <div class="grid">
          <div><small>Jongeren</small><br><span class="mono"><?=h($s['count']??'0')?></span></div>
          <div><small>Sfeer</small><br><?=h($s['mood']??'-')?></div>
          <div><small>Interventies</small><br><?=nl2br(h($s['interventions']??''))?></div>
          <div><small>Verloop</small><br><?=nl2br(h($s['flow']??''))?></div>
          <div><small>Opmerkingen</small><br><?=nl2br(h($s['notes']??''))?></div>
        </div>
      </details>
    <?php endforeach; ?>
  </article>

  <article>
    <h3>Incidenten</h3>
    <?php if(!$incidents): ?><p class="muted">Geen incidenten.</p><?php endif; ?>
    <table>
      <thead><tr><th>Tijd</th><th>Jongere</th><th>Omschrijving</th><th>Melding</th><th>Gehoord</th><th>Maatregel</th></tr></thead>
      <tbody>
      <?php foreach($incidents as $i): ?>
        <tr>
          <td><?=h($i['time']??'')?></td>
          <td><?=h($i['y_name']??'')?></td>
          <td><?=h($i['summary']??'')?></td>
          <td><?=h($i['reported']??'nee')?></td>
          <td><?=h($i['heard']??'nee')?></td>
          <td><?=h($i['measure']??'nee')?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </article>

  <article>
    <h3>Afspraken voor morgen</h3>
    <?php if(!$nextday): ?><p class="muted">Geen afspraken.</p><?php endif; ?>
    <?php foreach($nextday as $n): ?>
      <blockquote>
        <strong><?=h($n['group']??'-')?></strong><br>
        <small>Speciale punten</small><br><?=nl2br(h($n['special']??''))?><br>
        <small>Sport</small><br><?=nl2br(h($n['sports']??''))?><br>
        <small>GL</small><br><?=nl2br(h($n['lead']??''))?>
      </blockquote>
    <?php endforeach; ?>
  </article>
</main>
</body>
</html>
<?php
  return ob_get_clean();
}

function report_write_file(string $date): string {
  $html = report_build_html($date);
  ensure_dir(STORAGE_REPORTS);
  $file = rtrim(STORAGE_REPORTS,'/')."/$date.html";
  file_put_contents($file, $html);
  return $file;
}
PHP

# ---------------- views/partials/layout.php ----------------
cat > views/partials/layout.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; ?>
<!doctype html>
<html lang="nl">
<head>
  <meta charset="utf-8">
  <title><?=h(APP_NAME)?></title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/@picocss/pico@2/css/pico.min.css">
  <style>
    :root { --pico-font-family: Inter, system-ui, Segoe UI, Roboto, sans-serif; }
    header.container {padding:1rem 0}
    .flash{padding:.6rem .8rem;border-radius:.5rem;margin:.5rem 0}
    .flash-ok{background:#052e16;color:#86efac;border:1px solid #14532d}
    .flash-err{background:#450a0a;color:#fecaca;border:1px solid #7f1d1d}
    .muted{color:#6b7280}
  </style>
</head>
<body>
<header class="container">
  <nav>
    <ul>
      <li><strong><?=h(APP_BRAND)?></strong></li>
    </ul>
    <ul>
      <li><a href="<?=h(baseurl('/'))?>">Dashboard</a></li>
      <li><a href="<?=h(baseurl('/?p=session'))?>">+ Sessie</a></li>
      <li><a href="<?=h(baseurl('/?p=incident'))?>">+ Incident</a></li>
      <li><a href="<?=h(baseurl('/?p=nextday'))?>">+ Morgen</a></li>
      <li><a href="<?=h(baseurl('/?p=report&date='.date('Y-m-d')))?>">Rapport vandaag</a></li>
    </ul>
  </nav>
</header>
<main class="container">
  <?php if($f=flash('ok')): ?><div class="flash flash-ok"><?=h($f)?></div><?php endif; ?>
  <?php if($f=flash('err')): ?><div class="flash flash-err"><?=h($f)?></div><?php endif; ?>
  <?php /** CONTENT **/ ?>
  <?= $content ?? '' ?>
</main>
<footer class="container">
  <small class="muted">Opslag in <code>storage/json</code>. Mail staat uit (no-DB modus).</small>
</footer>
</body>
</html>
PHP

# ---------------- views/pages/dashboard.php ----------------
cat > views/pages/dashboard.php <<'PHP'
<?php
require_once __DIR__.'/../../app/services/storage.php';
$latest = latest_date() ?? date('Y-m-d');
$sessions  = storage_load_by_date('sessions',$latest);
$incidents = storage_load_by_date('incidents',$latest);
$nextday   = storage_load_by_date('nextday',$latest);

ob_start(); ?>
<h2>Dashboard — <?=h($latest)?></h2>
<div class="grid">
  <article><h3><?=count($sessions)?></h3><small>Sessies</small></article>
  <article><h3><?=count($incidents)?></h3><small>Incidenten</small></article>
  <article><h3><?=count($nextday)?></h3><small>Afspraken morgen</small></article>
</div>

<article>
  <h3>Sessies</h3>
  <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
  <table>
    <thead><tr><th>Datum</th><th>Groep</th><th>Soort</th><th>Jongeren</th><th>Sfeer</th></tr></thead>
    <tbody>
    <?php foreach($sessions as $s): ?>
      <tr>
        <td><?=h($s['date'])?> <?=h($s['time']??'')?></td>
        <td><?=h($s['group']??'-')?></td>
        <td><?=h($s['kind']??'-')?></td>
        <td><?=h($s['count']??'0')?></td>
        <td><?=h($s['mood']??'-')?></td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
</article>

<article>
  <h3>Incidenten</h3>
  <?php if(!$incidents): ?><p class="muted">Geen incidenten.</p><?php endif; ?>
  <ul>
    <?php foreach($incidents as $i): ?>
      <li><strong><?=h($i['time']??'')?></strong> — <?=h($i['y_name']??'')?> — <?=h($i['summary']??'')?></li>
    <?php endforeach; ?>
  </ul>
</article>

<article>
  <h3>Afspraken morgen</h3>
  <?php if(!$nextday): ?><p class="muted">Geen afspraken.</p><?php endif; ?>
  <ul>
    <?php foreach($nextday as $n): ?>
      <li><strong><?=h($n['group']??'-')?></strong> — <?=h($n['special']??'')?></li>
    <?php endforeach; ?>
  </ul>
</article>
<?php
$content = ob_get_clean();
include __DIR__.'/../partials/layout.php';
PHP

# ---------------- views/forms/session.php ----------------
cat > views/forms/session.php <<'PHP'
<?php
require_once __DIR__.'/../../app/core/helpers.php';
session_start_safe();

$errors = $_SESSION['_old_errors']['session'] ?? [];
$old    = $_SESSION['_old_input']['session']  ?? ['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['session'], $_SESSION['_old_input']['session']);

ob_start(); ?>
<h2>Nieuw sport/creatief moment</h2>
<form method="post" action="<?=h(baseurl('/?p=session.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum
      <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required>
      <?php if(isset($errors['date'])): ?><small class="contrast"><?=h($errors['date'])?></small><?php endif; ?>
    </label>
    <label>Tijd
      <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>">
    </label>
  </div>
  <div class="grid">
    <label>Groep
      <input name="group" placeholder="Groep A" value="<?=h($old['group']??'')?>" required>
      <?php if(isset($errors['group'])): ?><small class="contrast"><?=h($errors['group'])?></small><?php endif; ?>
    </label>
    <label>Aantal jongeren
      <input type="number" name="count" min="0" value="<?=h($old['count']??'0')?>">
    </label>
  </div>
  <label>Soort
    <select name="kind">
      <option <?=(($old['kind']??'')==='Sport')?'selected':''?>>Sport</option>
      <option <?=(($old['kind']??'')==='Creatief')?'selected':''?>>Creatief</option>
    </select>
  </label>
  <label>Sfeer op de groep
    <input name="mood" value="<?=h($old['mood']??'')?>">
  </label>
  <label>Interventies
    <textarea name="interventions" rows="2"><?=h($old['interventions']??'')?></textarea>
  </label>
  <label>Verloop van de sessie
    <textarea name="flow" rows="3"><?=h($old['flow']??'')?></textarea>
  </label>
  <label>Opmerkingen
    <textarea name="notes" rows="2"><?=h($old['notes']??'')?></textarea>
  </label>
  <button>Opslaan</button>
  <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php
$content = ob_get_clean();
include __DIR__.'/../partials/layout.php';
PHP

# ---------------- views/forms/incident.php ----------------
cat > views/forms/incident.php <<'PHP'
<?php
require_once __DIR__.'/../../app/core/helpers.php';
session_start_safe();

$errors = $_SESSION['_old_errors']['incident'] ?? [];
$old    = $_SESSION['_old_input']['incident']  ?? ['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['incident'], $_SESSION['_old_input']['incident']);

ob_start(); ?>
<h2>Incident</h2>
<form method="post" action="<?=h(baseurl('/?p=incident.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum
      <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required>
      <?php if(isset($errors['date'])): ?><small class="contrast"><?=h($errors['date'])?></small><?php endif; ?>
    </label>
    <label>Tijdstip
      <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>">
    </label>
  </div>
  <label>Voor- en achternaam jongere
    <input name="y_name" value="<?=h($old['y_name']??'')?>" required>
    <?php if(isset($errors['y_name'])): ?><small class="contrast"><?=h($errors['y_name'])?></small><?php endif; ?>
  </label>
  <label>Korte omschrijving
    <textarea name="summary" rows="3"><?=h($old['summary']??'')?></textarea>
  </label>
  <div class="grid">
    <label>Incidentmelding gedaan?
      <select name="reported"><option>nee</option><option <?=(($old['reported']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
    <label>Jongere gehoord?
      <select name="heard"><option>nee</option><option <?=(($old['heard']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
  </div>
  <label>Ordemaatregel / disciplinaire straf?
    <input name="measure" value="<?=h($old['measure']??'')?>">
  </label>
  <button>Opslaan</button>
  <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php
$content = ob_get_clean();
include __DIR__.'/../partials/layout.php';
PHP

# ---------------- views/forms/nextday.php ----------------
cat > views/forms/nextday.php <<'PHP'
<?php
require_once __DIR__.'/../../app/core/helpers.php';
session_start_safe();

$errors = $_SESSION['_old_errors']['nextday'] ?? [];
$old    = $_SESSION['_old_input']['nextday']  ?? ['date'=>date('Y-m-d')];
unset($_SESSION['_old_errors']['nextday'], $_SESSION['_old_input']['nextday']);

ob_start(); ?>
<h2>Afspraken voor morgen</h2>
<form method="post" action="<?=h(baseurl('/?p=nextday.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>Datum (vandaag)
    <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required>
    <?php if(isset($errors['date'])): ?><small class="contrast"><?=h($errors['date'])?></small><?php endif; ?>
  </label>
  <label>Groep
    <input name="group" value="<?=h($old['group']??'')?>" required>
    <?php if(isset($errors['group'])): ?><small class="contrast"><?=h($errors['group'])?></small><?php endif; ?>
  </label>
  <label>Speciale aandachtspunten
    <textarea name="special" rows="2"><?=h($old['special']??'')?></textarea>
  </label>
  <label>Sportafspraken
    <textarea name="sports" rows="2"><?=h($old['sports']??'')?></textarea>
  </label>
  <label>Afspraken met groepsleiding
    <textarea name="lead" rows="2"><?=h($old['lead']??'')?></textarea>
  </label>
  <button>Opslaan</button>
  <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php
$content = ob_get_clean();
include __DIR__.'/../partials/layout.php';
PHP

# ---------------- public/index.php (router + controllers) ----------------
cat > public/index.php <<'PHP'
<?php
require_once __DIR__.'/../app/core/config.php';
require_once __DIR__.'/../app/core/helpers.php';
require_once __DIR__.'/../app/services/storage.php';
require_once __DIR__.'/../app/controllers/ReportController.php';

session_start_safe();

function old_store(string $key, array $input, array $errors){
  $_SESSION['_old_input'][$key]  = $input;
  $_SESSION['_old_errors'][$key] = $errors;
}

$action = $_GET['p'] ?? 'dashboard';

switch($action){

  case 'dashboard':
    include __DIR__.'/../views/pages/dashboard.php';
  break;

  case 'session':
    include __DIR__.'/../views/forms/session.php';
  break;

  case 'session.save':
    if(!csrf_check($_POST['csrf'] ?? '')) { flash('err','CSRF ongeldig.'); redirect(baseurl('/?p=session')); }
    $rules = ['date'=>'required','group'=>'required','count'=>'int'];
    $errors = validate($_POST, $rules);
    if($errors){ old_store('session', $_POST, $errors); redirect(baseurl('/?p=session')); }
    storage_save('sessions', [
      'date'=>$_POST['date'], 'time'=>$_POST['time']??'',
      'group'=>$_POST['group']??'', 'count'=>$_POST['count']??'0',
      'kind'=>$_POST['kind']??'Sport', 'mood'=>$_POST['mood']??'',
      'interventions'=>$_POST['interventions']??'', 'flow'=>$_POST['flow']??'',
      'notes'=>$_POST['notes']??'',
    ]);
    flash('ok','Sessie opgeslagen.');
    redirect(baseurl('/'));
  break;

  case 'incident':
    include __DIR__.'/../views/forms/incident.php';
  break;

  case 'incident.save':
    if(!csrf_check($_POST['csrf'] ?? '')) { flash('err','CSRF ongeldig.'); redirect(baseurl('/?p=incident')); }
    $rules = ['date'=>'required','y_name'=>'required'];
    $errors = validate($_POST, $rules);
    if($errors){ old_store('incident', $_POST, $errors); redirect(baseurl('/?p=incident')); }
    storage_save('incidents', [
      'date'=>$_POST['date'],'time'=>$_POST['time']??'',
      'y_name'=>$_POST['y_name']??'','summary'=>$_POST['summary']??'',
      'reported'=>$_POST['reported']??'nee','heard'=>$_POST['heard']??'nee',
      'measure'=>$_POST['measure']??'',
    ]);
    flash('ok','Incident opgeslagen.');
    redirect(baseurl('/'));
  break;

  case 'nextday':
    include __DIR__.'/../views/forms/nextday.php';
  break;

  case 'nextday.save':
    if(!csrf_check($_POST['csrf'] ?? '')) { flash('err','CSRF ongeldig.'); redirect(baseurl('/?p=nextday')); }
    $rules = ['date'=>'required','group'=>'required'];
    $errors = validate($_POST, $rules);
    if($errors){ old_store('nextday', $_POST, $errors); redirect(baseurl('/?p=nextday')); }
    storage_save('nextday', [
      'date'=>$_POST['date'],'group'=>$_POST['group']??'',
      'special'=>$_POST['special']??'','sports'=>$_POST['sports']??'','lead'=>$_POST['lead']??'',
    ]);
    flash('ok','Afspraken opgeslagen.');
    redirect(baseurl('/'));
  break;

  case 'report':
    $d = $_GET['date'] ?? date('Y-m-d');
    echo report_build_html($d);
  break;

  // API endpoints
  case 'api.latest':
    header('Content-Type: application/json; charset=utf-8');
    $file = rtrim(STORAGE_JSON,'/').'/latest.json';
    if(!file_exists($file)) rebuild_latest_index();
    readfile($file);
  break;

  default:
    http_response_code(404);
    echo "404 — Page not found";
}
PHP

# ---------------- bin/run-daily-report.php ----------------
cat > bin/run-daily-report.php <<'PHP'
<?php
require_once __DIR__.'/../app/controllers/ReportController.php';
$date = $argv[1] ?? date('Y-m-d');
$file = report_write_file($date);
fwrite(STDOUT, "Report for $date -> $file\n");
PHP

# ---------------- bin/install-cron.sh ----------------
cat > bin/install-cron.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHPBIN="${PHPBIN:-php}"
# Dagelijks 18:00 rapport genereren (alleen HTML in storage/reports)
( crontab -l 2>/dev/null | grep -v run-daily-report.php ; \
  echo "0 18 * * * cd \"$ROOT\" && $PHPBIN bin/run-daily-report.php >> storage/reports/cron.log 2>&1" ) | crontab -
echo "Cron ingesteld om 18:00."
SH
chmod +x bin/install-cron.sh

# ---------------- .gitignore ----------------
cat > .gitignore <<'TXT'
/vendor/
storage/json/*.json
storage/reports/*
!.gitkeep
.DS_Store
TXT

echo "✅ Pro no-DB rapportagesysteem geplaatst.
Start lokaal met:
  php -S 0.0.0.0:8080 -t public

Ga naar:
  /          -> Dashboard
  /?p=session  /?p=incident  /?p=nextday
  /?p=report&date=$(date +%F)

Optioneel:
  bash bin/install-cron.sh   # plan dagelijks rapport 18:00 (HTML)"
