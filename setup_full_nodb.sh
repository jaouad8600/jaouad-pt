#!/usr/bin/env bash
set -euo pipefail

# ===== Structuur =====
mkdir -p public app/{core,controllers,services,auth} views/{partials,pages,forms,auth} \
         storage/{json,reports,outbox,users} bin
touch storage/.gitkeep

# ===== app/core/config.php =====
cat > app/core/config.php <<'PHP'
<?php
// === App ===
const APP_NAME    = 'Teylingereind Rapportages (no-DB)';
const APP_BRAND   = 'Teylingereind';
const APP_TIMEZONE= 'Europe/Amsterdam';
const APP_BASEURL = ''; // bv. '' of '/rapport'

// === Security ===
const APP_SESSION_NAME = 'tey_rep_sess';
const CSRF_KEY = 'csrf_token';

// === Opslag ===
define('STORAGE_JSON',    __DIR__.'/../../storage/json');    // /sessions/YYYY-MM-DD.json etc.
define('STORAGE_REPORTS', __DIR__.'/../../storage/reports'); // dagrapporten (HTML)
define('STORAGE_OUTBOX',  __DIR__.'/../../storage/outbox');  // .eml mails
define('STORAGE_USERS',   __DIR__.'/../../storage/users/users.json');
define('STORAGE_AUDIT',   __DIR__.'/../../storage/audit.log');

// === Retentie (dagen) ===
const RETAIN_DAYS = 365;

// === Mail ===
// modes: 'disabled' | 'file' (schrijft .eml) | 'mail' (php mail())
// SMTP later mogelijk als je wilt — nu buiten scope zonder composer.
const MAIL_MODE = 'file';
const MAIL_FROM = 'noreply@example.org';
const MAIL_TO   = 'team@example.org';
date_default_timezone_set(APP_TIMEZONE);
PHP

# ===== app/core/helpers.php =====
cat > app/core/helpers.php <<'PHP'
<?php
require_once __DIR__.'/config.php';

function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
function ensure_dir($p){ if(!is_dir($p)) mkdir($p,0775,true); }
function baseurl($p=''){ return APP_BASEURL.$p; }
function redirect($p){ header('Location: '.$p); exit; }

function uuid(): string {
  $d = random_bytes(16);
  $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
  $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
  return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

function session_start_safe(){
  if(session_status()!==PHP_SESSION_ACTIVE){
    session_name(APP_SESSION_NAME);
    session_start();
  }
}

function csrf_token(): string {
  session_start_safe();
  if(empty($_SESSION[CSRF_KEY])) $_SESSION[CSRF_KEY]=bin2hex(random_bytes(32));
  return $_SESSION[CSRF_KEY];
}
function csrf_check($t): bool {
  session_start_safe();
  return hash_equals($_SESSION[CSRF_KEY]??'', (string)$t);
}

function flash($key, $msg=null){
  session_start_safe();
  if($msg===null){ $m=$_SESSION['_flash'][$key]??null; unset($_SESSION['_flash'][$key]); return $m; }
  $_SESSION['_flash'][$key]=$msg;
}

function validate(array $data, array $rules): array {
  $errors=[];
  foreach($rules as $field=>$rule){
    $v=trim((string)($data[$field]??''));
    foreach(explode('|',$rule) as $r){
      if($r==='required' && $v==='') $errors[$field]='Verplicht veld';
      if($r==='int' && $v!=='' && !preg_match('/^\d+$/',$v)) $errors[$field]='Moet een getal zijn';
      if(str_starts_with($r,'in:')){
        $ops=explode(',',substr($r,3)); if($v!=='' && !in_array($v,$ops,true)) $errors[$field]='Ongeldige waarde';
      }
    }
  }
  return $errors;
}

function audit($who, $action, $meta=[]){
  $line = json_encode([
    'ts'=>date('c'),'who'=>$who,'action'=>$action,'meta'=>$meta
  ], JSON_UNESCAPED_UNICODE);
  file_put_contents(STORAGE_AUDIT, $line.PHP_EOL, FILE_APPEND);
}

function user(){ session_start_safe(); return $_SESSION['user']??null; }
function is_role($role){ $u=user(); if(!$u) return false; return $u['role']===$role || $u['role']==='coordinator'; }
function require_login($role=null){
  if(!user()) redirect(baseurl('/?p=login'));
  if($role && !is_role($role)) redirect(baseurl('/'));
}
PHP

# ===== app/services/users.php =====
cat > app/services/users.php <<'PHP'
<?php
require_once __DIR__.'/../core/helpers.php';

function users_all(): array {
  if(!file_exists(STORAGE_USERS)) return [];
  $j = json_decode(file_get_contents(STORAGE_USERS), true);
  return is_array($j)?$j:[];
}
function users_save_all(array $a): void {
  ensure_dir(dirname(STORAGE_USERS));
  file_put_contents(STORAGE_USERS, json_encode($a, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}
function users_init_once(){
  if(file_exists(STORAGE_USERS)) return;
  $pwd = password_hash('admin123', PASSWORD_DEFAULT);
  users_save_all([[ 'id'=>uuid(),'name'=>'Admin','email'=>'admin@example.org','role'=>'coordinator','pwd'=>$pwd ]]);
}
function users_find_email($email){
  foreach(users_all() as $u){ if(strtolower($u['email'])===strtolower($email)) return $u; }
  return null;
}
function users_create($name,$email,$role,$password): array {
  $all=users_all();
  if(users_find_email($email)) throw new RuntimeException('Email bestaat al');
  $u = ['id'=>uuid(),'name'=>$name,'email'=>$email,'role'=>$role,'pwd'=>password_hash($password,PASSWORD_DEFAULT)];
  $all[]=$u; users_save_all($all); return $u;
}
function auth_login($email,$password): bool {
  session_start_safe(); users_init_once();
  $u=users_find_email($email); if(!$u) return false;
  if(!password_verify($password, $u['pwd'])) return false;
  $_SESSION['user']=['id'=>$u['id'],'name'=>$u['name'],'email'=>$u['email'],'role'=>$u['role']];
  audit($u['email'],'login');
  return true;
}
function auth_logout(){
  if(user()) audit(user()['email'],'logout');
  session_start_safe(); $_SESSION=[]; session_destroy();
}
PHP

# ===== app/services/storage.php =====
cat > app/services/storage.php <<'PHP'
<?php
require_once __DIR__.'/../core/helpers.php';

function storage_path($type,$date){ return rtrim(STORAGE_JSON,'/')."/$type/$date.json"; }

function storage_load_by_date($type,$date): array {
  $f=storage_path($type,$date); if(!file_exists($f)) return [];
  $d=json_decode(file_get_contents($f),true); return is_array($d)?$d:[];
}

function storage_list_dates($type): array {
  $dir=rtrim(STORAGE_JSON,'/')."/$type"; if(!is_dir($dir)) return [];
  $files=glob($dir.'/*.json'); sort($files);
  return array_map(fn($f)=>basename($f,'.json'),$files);
}

function latest_date(): ?string {
  $dates=array_unique(array_merge(
    storage_list_dates('sessions'),
    storage_list_dates('incidents'),
    storage_list_dates('nextday')
  ));
  sort($dates); return $dates?end($dates):null;
}

function payload_hash(array $p): string {
  $copy=$p; unset($copy['_id'],$copy['_ts']);
  return hash('xxh128', json_encode($copy,JSON_UNESCAPED_UNICODE));
}

function storage_save($type,array $payload,int $dupeWindow=300): array {
  $date=$payload['date']??date('Y-m-d'); $file=storage_path($type,$date);
  ensure_dir(dirname($file));
  $arr=file_exists($file)?(json_decode(file_get_contents($file),true)?:[]):[];
  $h=payload_hash($payload); $now=time();
  foreach(array_reverse($arr) as $it){
    if(($it['_hash']??'')===$h && (abs($now - strtotime($it['_ts']??$payload['date'].' 00:00'))<=$dupeWindow)){
      return [$file,count($arr),false]; // duplicate binnen venster
    }
  }
  $payload['_id']=$payload['_id']??uuid();
  $payload['_ts']=date('c');
  $payload['_hash']=$h;
  $arr[]=$payload;
  file_put_contents($file, json_encode($arr,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
  rebuild_latest_index();
  return [$file,count($arr),true];
}

function rebuild_latest_index(): void {
  $latest=latest_date();
  $out=['date'=>null,'sessions'=>[],'incidents'=>[],'nextday'=>[]];
  if($latest){
    $out['date']=$latest;
    $out['sessions']=storage_load_by_date('sessions',$latest);
    $out['incidents']=storage_load_by_date('incidents',$latest);
    $out['nextday']=storage_load_by_date('nextday',$latest);
  }
  ensure_dir(STORAGE_JSON);
  file_put_contents(rtrim(STORAGE_JSON,'/').'/latest.json', json_encode($out,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}

function export_csv(array $rows,array $cols): string {
  $fh=fopen('php://temp','w+'); fputcsv($fh,$cols,';');
  foreach($rows as $r){ $line=[]; foreach($cols as $c){ $line[]=$r[$c]??''; } fputcsv($fh,$line,';'); }
  rewind($fh); return stream_get_contents($fh);
}

function cleanup_old(int $days){
  $before=strtotime("-{$days} days");
  foreach(['sessions','incidents','nextday'] as $t){
    $dir=rtrim(STORAGE_JSON,'/')."/$t";
    if(!is_dir($dir)) continue;
    foreach(glob("$dir/*.json") as $f){
      $d=basename($f,'.json');
      if(strtotime($d)<$before) @unlink($f);
    }
  }
}
PHP

# ===== app/services/mailer.php =====
cat > app/services/mailer.php <<'PHP'
<?php
require_once __DIR__.'/../core/helpers.php';

function mail_send($subject,$html,$to=MAIL_TO): string {
  $boundary = 'b-'.bin2hex(random_bytes(8));
  $headers = [
    "From: ".MAIL_FROM,
    "MIME-Version: 1.0",
    "Content-Type: multipart/alternative; boundary=\"$boundary\""
  ];
  $body = "--$boundary\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n".
          strip_tags($html)."\r\n".
          "--$boundary\r\nContent-Type: text/html; charset=utf-8\r\n\r\n".
          $html."\r\n--$boundary--\r\n";

  if(MAIL_MODE==='disabled'){
    $file=rtrim(STORAGE_OUTBOX,'/').'/'.date('Ymd-His').'-DISABLED.eml';
    ensure_dir(dirname($file));
    file_put_contents($file, "To: $to\r\nSubject: $subject\r\n".implode("\r\n",$headers)."\r\n\r\n".$body);
    return $file;
  }
  if(MAIL_MODE==='file'){
    $file=rtrim(STORAGE_OUTBOX,'/').'/'.date('Ymd-His').'-out.eml';
    ensure_dir(dirname($file));
    file_put_contents($file, "To: $to\r\nSubject: $subject\r\n".implode("\r\n",$headers)."\r\n\r\n".$body);
    return $file;
  }
  if(MAIL_MODE==='mail'){
    $ok = mail($to, $subject, $body, implode("\r\n",$headers));
    return $ok ? 'mail() sent' : 'mail() failed';
  }
  return 'unsupported mode';
}
PHP

# ===== app/controllers/ReportController.php =====
cat > app/controllers/ReportController.php <<'PHP'
<?php
require_once __DIR__.'/../services/storage.php';

function report_build_html($date): string {
  $sessions = storage_load_by_date('sessions',$date);
  $incidents= storage_load_by_date('incidents',$date);
  $nextday  = storage_load_by_date('nextday',$date);
  ob_start(); ?>
<!doctype html><html lang="nl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dagrapport <?=h($date)?> — <?=h(APP_BRAND)?></title>
<link rel="stylesheet" href="https://unpkg.com/@picocss/pico@2/css/pico.min.css">
<style>
  :root{--pico-font-family:Inter,system-ui,Segoe UI,Roboto,sans-serif}
  @media print{.no-print{display:none!important}}
  .kpi{display:grid;grid-template-columns:repeat(3,1fr);gap:.8rem}
  .muted{color:#6b7280}
  .mono{font-family:ui-monospace,Menlo,monospace}
</style>
</head><body><main class="container">
  <header class="no-print" style="margin:1rem 0">
    <h1>Dagrapport <?=h($date)?></h1>
    <p class="muted">Gegenereerd <?=date('d-m-Y H:i')?> — <?=h(APP_BRAND)?></p>
    <a role="button" class="secondary" href="<?=h(baseurl('/'))?>">&larr; Terug</a>
    <button onclick="window.print()">Print/PDF</button>
  </header>

  <section class="kpi">
    <article><h2><?=count($sessions)?></h2><small>Sessies</small></article>
    <article><h2><?=count($incidents)?></h2><small>Incidenten</small></article>
    <article><h2><?=count($nextday)?></h2><small>Afspraken morgen</small></article>
  </section>

  <article>
    <h3>Sessies</h3>
    <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
    <?php foreach($sessions as $s): ?>
      <details>
        <summary><strong><?=h($s['date'])?> <?=h($s['time']??'')?> — <?=h($s['group']??'-')?> (<?=h($s['kind']??'-')?>)</strong></summary>
        <div class="grid">
          <div><small>Jongeren</small><div class="mono"><?=h($s['count']??'0')?></div></div>
          <div><small>Sfeer</small><div><?=h($s['mood']??'-')?></div></div>
          <div><small>Interventies</small><div><?=nl2br(h($s['interventions']??''))?></div></div>
          <div><small>Verloop</small><div><?=nl2br(h($s['flow']??''))?></div></div>
          <div><small>Opmerkingen</small><div><?=nl2br(h($s['notes']??''))?></div></div>
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
        <b><?=h($n['group']??'-')?></b><br>
        <small>Speciale punten</small><div><?=nl2br(h($n['special']??''))?></div>
        <small>Sport</small><div><?=nl2br(h($n['sports']??''))?></div>
        <small>GL</small><div><?=nl2br(h($n['lead']??''))?></div>
      </blockquote>
    <?php endforeach; ?>
  </article>
</main></body></html>
<?php return ob_get_clean();
}

function report_write_file($date): string {
  $html=report_build_html($date);
  ensure_dir(STORAGE_REPORTS);
  $f=rtrim(STORAGE_REPORTS,'/')."/$date.html";
  file_put_contents($f,$html);
  return $f;
}
PHP

# ===== views/partials/layout.php =====
cat > views/partials/layout.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; $u=user(); ?>
<!doctype html><html lang="nl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title><?=h(APP_NAME)?></title>
<link rel="stylesheet" href="https://unpkg.com/@picocss/pico@2/css/pico.min.css">
<style>
  :root{--pico-font-family:Inter,system-ui,Segoe UI,Roboto,sans-serif}
  header.container{padding:1rem 0}
  .muted{color:#6b7280}
  .flash{padding:.6rem .8rem;border-radius:.5rem;margin:.5rem 0}
  .ok{background:#052e16;color:#86efac;border:1px solid #14532d}
  .err{background:#450a0a;color:#fecaca;border:1px solid #7f1d1d}
</style>
</head><body>
<header class="container">
  <nav>
    <ul><li><strong><?=h(APP_BRAND)?></strong></li></ul>
    <ul>
      <?php if($u): ?>
        <li><a href="<?=h(baseurl('/'))?>">Dashboard</a></li>
        <li><a href="<?=h(baseurl('/?p=session'))?>">+ Sessie</a></li>
        <li><a href="<?=h(baseurl('/?p=incident'))?>">+ Incident</a></li>
        <li><a href="<?=h(baseurl('/?p=nextday'))?>">+ Morgen</a></li>
        <li><a href="<?=h(baseurl('/?p=report&date='.date('Y-m-d')))?>">Rapport vandaag</a></li>
        <?php if(is_role('coordinator')): ?>
          <li><a href="<?=h(baseurl('/?p=admin.users'))?>">Gebruikers</a></li>
        <?php endif; ?>
        <li class="muted">|</li>
        <li class="muted"><?=h($u['name'])?> (<?=h($u['role'])?>)</li>
        <li><a href="<?=h(baseurl('/?p=logout'))?>">Uitloggen</a></li>
      <?php else: ?>
        <li><a href="<?=h(baseurl('/?p=login'))?>">Inloggen</a></li>
      <?php endif; ?>
    </ul>
  </nav>
</header>
<main class="container">
  <?php if($m=flash('ok')): ?><div class="flash ok"><?=h($m)?></div><?php endif; ?>
  <?php if($m=flash('err')): ?><div class="flash err"><?=h($m)?></div><?php endif; ?>
  <?= $content ?? '' ?>
</main>
<footer class="container"><small class="muted">
Opslag: <code>storage/json</code>. Outbox: <code>storage/outbox</code>. Retentie: <?=RETAIN_DAYS?> dagen.
</small></footer>
</body></html>
PHP

# ===== views/pages/dashboard.php =====
cat > views/pages/dashboard.php <<'PHP'
<?php
require_once __DIR__.'/../../app/services/storage.php';
require_login();

$sel = $_GET['date'] ?? (latest_date() ?? date('Y-m-d'));
$dates = array_unique(array_merge(
  storage_list_dates('sessions'),
  storage_list_dates('incidents'),
  storage_list_dates('nextday')
));
sort($dates);

$sessions  = storage_load_by_date('sessions',$sel);
$incidents = storage_load_by_date('incidents',$sel);
$nextday   = storage_load_by_date('nextday',$sel);

ob_start(); ?>
<h2>Dashboard</h2>
<form method="get" class="grid">
  <input type="hidden" name="p" value="dashboard">
  <label>Datum
    <select name="date" onchange="this.form.submit()">
      <?php foreach($dates?:[$sel] as $d): ?>
        <option value="<?=h($d)?>" <?=$d===$sel?'selected':''?>><?=h($d)?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <div>
    <a role="button" class="secondary" href="<?=h(baseurl('/?p=export&type=sessions&date='.$sel))?>">Export sessies (CSV)</a>
    <a role="button" class="secondary" href="<?=h(baseurl('/?p=export&type=incidents&date='.$sel))?>">Export incidenten (CSV)</a>
    <a role="button" class="secondary" href="<?=h(baseurl('/?p=export&type=nextday&date='.$sel))?>">Export morgen (CSV)</a>
    <a role="button" href="<?=h(baseurl('/?p=report&date='.$sel))?>">Open dagrapport</a>
  </div>
</form>

<div class="grid">
  <article><h3><?=count($sessions)?></h3><small>Sessies</small></article>
  <article><h3><?=count($incidents)?></h3><small>Incidenten</small></article>
  <article><h3><?=count($nextday)?></h3><small>Afspraken morgen</small></article>
</div>

<article>
  <h3>Sessies</h3>
  <?php if(!$sessions): ?><p class="muted">Geen sessies.</p><?php endif; ?>
  <table>
    <thead><tr><th>Datum</th><th>Groep</th><th>Soort</th><th># Jong.</th><th>Sfeer</th></tr></thead>
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
$content=ob_get_clean();
include __DIR__.'/../partials/layout.php';
PHP

# ===== views/forms/session.php =====
cat > views/forms/session.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login();
$errors = $_SESSION['_old_errors']['session'] ?? [];
$old    = $_SESSION['_old_input']['session']  ?? ['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['session'], $_SESSION['_old_input']['session']);
ob_start(); ?>
<h2>Nieuw sport/creatief moment</h2>
<form method="post" action="<?=h(baseurl('/?p=session.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
    <label>Tijd  <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>"></label>
  </div>
  <div class="grid">
    <label>Groep <input name="group" value="<?=h($old['group']??'')?>" required></label>
    <label>Aantal jongeren <input type="number" name="count" min="0" value="<?=h($old['count']??'0')?>"></label>
  </div>
  <label>Soort
    <select name="kind"><option>Sport</option><option <?=(($old['kind']??'')==='Creatief')?'selected':''?>>Creatief</option></select>
  </label>
  <label>Sfeer <input name="mood" value="<?=h($old['mood']??'')?>"></label>
  <label>Interventies <textarea name="interventions" rows="2"><?=h($old['interventions']??'')?></textarea></label>
  <label>Verloop <textarea name="flow" rows="3"><?=h($old['flow']??'')?></textarea></label>
  <label>Opmerkingen <textarea name="notes" rows="2"><?=h($old['notes']??'')?></textarea></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
PHP

# ===== views/forms/incident.php =====
cat > views/forms/incident.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login('coordinator');
$errors=$_SESSION['_old_errors']['incident']??[]; $old=$_SESSION['_old_input']['incident']??['date'=>date('Y-m-d'),'time'=>date('H:i')];
unset($_SESSION['_old_errors']['incident'], $_SESSION['_old_input']['incident']);
ob_start(); ?>
<h2>Incident</h2>
<form method="post" action="<?=h(baseurl('/?p=incident.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <div class="grid">
    <label>Datum <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
    <label>Tijdstip <input type="time" name="time" value="<?=h($old['time']??date('H:i'))?>"></label>
  </div>
  <label>Voor- en achternaam jongere <input name="y_name" value="<?=h($old['y_name']??'')?>" required></label>
  <label>Korte omschrijving <textarea name="summary" rows="3"><?=h($old['summary']??'')?></textarea></label>
  <div class="grid">
    <label>Incidentmelding gedaan?
      <select name="reported"><option>nee</option><option <?=(($old['reported']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
    <label>Jongere gehoord?
      <select name="heard"><option>nee</option><option <?=(($old['heard']??'')==='ja')?'selected':''?>>ja</option></select>
    </label>
  </div>
  <label>Ordemaatregel / disciplinaire straf? <input name="measure" value="<?=h($old['measure']??'')?>"></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
PHP

# ===== views/forms/nextday.php =====
cat > views/forms/nextday.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; require_login();
$errors=$_SESSION['_old_errors']['nextday']??[]; $old=$_SESSION['_old_input']['nextday']??['date'=>date('Y-m-d')];
unset($_SESSION['_old_errors']['nextday'], $_SESSION['_old_input']['nextday']);
ob_start(); ?>
<h2>Afspraken voor morgen</h2>
<form method="post" action="<?=h(baseurl('/?p=nextday.save'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>Datum (vandaag) <input type="date" name="date" value="<?=h($old['date']??date('Y-m-d'))?>" required></label>
  <label>Groep <input name="group" value="<?=h($old['group']??'')?>" required></label>
  <label>Speciale aandachtspunten <textarea name="special" rows="2"><?=h($old['special']??'')?></textarea></label>
  <label>Sportafspraken <textarea name="sports" rows="2"><?=h($old['sports']??'')?></textarea></label>
  <label>Afspraken met groepsleiding <textarea name="lead" rows="2"><?=h($old['lead']??'')?></textarea></label>
  <button>Opslaan</button> <a class="secondary" href="<?=h(baseurl('/'))?>">Annuleren</a>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
PHP

# ===== views/auth/login.php =====
cat > views/auth/login.php <<'PHP'
<?php require_once __DIR__.'/../../app/core/helpers.php'; $old=$_SESSION['_old_input']['login']??[]; unset($_SESSION['_old_input']['login']);
ob_start(); ?>
<h2>Inloggen</h2>
<p class="muted">Standaard: admin@example.org / <code>admin123</code> (verander dit direct)</p>
<form method="post" action="<?=h(baseurl('/?p=login.post'))?>">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>E-mail <input type="email" name="email" value="<?=h($old['email']??'')?>" required></label>
  <label>Wachtwoord <input type="password" name="password" required></label>
  <button>Inloggen</button>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
PHP

# ===== views/pages/users.php =====
cat > views/pages/users.php <<'PHP'
<?php require_once __DIR__.'/../../app/services/users.php'; require_login('coordinator');
$all=users_all();
ob_start(); ?>
<h2>Gebruikers</h2>
<table>
  <thead><tr><th>Naam</th><th>Email</th><th>Rol</th></tr></thead>
  <tbody>
    <?php foreach($all as $u): ?>
      <tr><td><?=h($u['name'])?></td><td><?=h($u['email'])?></td><td><?=h($u['role'])?></td></tr>
    <?php endforeach; ?>
  </tbody>
</table>
<form method="post" action="<?=h(baseurl('/?p=admin.users.add'))?>" class="grid">
  <input type="hidden" name="csrf" value="<?=h(csrf_token())?>">
  <label>Naam <input name="name" required></label>
  <label>Email <input type="email" name="email" required></label>
  <label>Rol
    <select name="role"><option>begeleider</option><option>coordinator</option></select>
  </label>
  <label>Wachtwoord <input type="text" name="password" placeholder="min. 8 tekens" required></label>
  <button>+ Voeg gebruiker toe</button>
</form>
<?php $content=ob_get_clean(); include __DIR__.'/../partials/layout.php';
PHP

# ===== public/index.php (router) =====
cat > public/index.php <<'PHP'
<?php
require_once __DIR__.'/../app/core/config.php';
require_once __DIR__.'/../app/core/helpers.php';
require_once __DIR__.'/../app/services/users.php';
require_once __DIR__.'/../app/services/storage.php';
require_once __DIR__.'/../app/services/mailer.php';
require_once __DIR__.'/../app/controllers/ReportController.php';

session_start_safe(); users_init_once();

function old_store($key,$input,$errors){ $_SESSION['_old_input'][$key]=$input; $_SESSION['_old_errors'][$key]=$errors; }

$action = $_GET['p'] ?? 'dashboard';

switch($action){

  // ------ Auth ------
  case 'login': if(user()){ redirect(baseurl('/')); } include __DIR__.'/../views/auth/login.php'; break;
  case 'login.post':
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF ongeldig'); redirect(baseurl('/?p=login')); }
    if(auth_login($_POST['email']??'', $_POST['password']??'')){ flash('ok','Welkom!'); redirect(baseurl('/')); }
    $_SESSION['_old_input']['login']=$_POST; flash('err','Onjuiste inlog'); redirect(baseurl('/?p=login'));
  break;
  case 'logout': auth_logout(); flash('ok','Uitgelogd'); redirect(baseurl('/?p=login')); break;

  // ------ Dashboard ------
  case 'dashboard': require_login(); include __DIR__.'/../views/pages/dashboard.php'; break;

  // ------ Forms ------
  case 'session': require_login(); include __DIR__.'/../views/forms/session.php'; break;
  case 'session.save':
    require_login();
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=session')); }
    $rules=['date'=>'required','group'=>'required','count'=>'int'];
    $err=validate($_POST,$rules);
    if($err){ old_store('session',$_POST,$err); redirect(baseurl('/?p=session')); }
    [$f,$n,$new]=storage_save('sessions',[
      'date'=>$_POST['date'],'time'=>$_POST['time']??'','group'=>$_POST['group']??'',
      'count'=>$_POST['count']??'0','kind'=>$_POST['kind']??'Sport','mood'=>$_POST['mood']??'',
      'interventions'=>$_POST['interventions']??'','flow'=>$_POST['flow']??'','notes'=>$_POST['notes']??'',
      'by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_session',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Sessie opgeslagen.':'Dubbele invoer genegeerd (binnen 5 min).');
    redirect(baseurl('/'));
  break;

  case 'incident': require_login('coordinator'); include __DIR__.'/../views/forms/incident.php'; break;
  case 'incident.save':
    require_login('coordinator');
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=incident')); }
    $rules=['date'=>'required','y_name'=>'required'];
    $err=validate($_POST,$rules);
    if($err){ old_store('incident',$_POST,$err); redirect(baseurl('/?p=incident')); }
    [$f,$n,$new]=storage_save('incidents',[
      'date'=>$_POST['date'],'time'=>$_POST['time']??'','y_name'=>$_POST['y_name']??'',
      'summary'=>$_POST['summary']??'','reported'=>$_POST['reported']??'nee','heard'=>$_POST['heard']??'nee',
      'measure'=>$_POST['measure']??'','by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_incident',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Incident opgeslagen.':'Dubbele invoer genegeerd.');
    redirect(baseurl('/'));
  break;

  case 'nextday': require_login(); include __DIR__.'/../views/forms/nextday.php'; break;
  case 'nextday.save':
    require_login();
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=nextday')); }
    $rules=['date'=>'required','group'=>'required']; $err=validate($_POST,$rules);
    if($err){ old_store('nextday',$_POST,$err); redirect(baseurl('/?p=nextday')); }
    [$f,$n,$new]=storage_save('nextday',[
      'date'=>$_POST['date'],'group'=>$_POST['group']??'',
      'special'=>$_POST['special']??'','sports'=>$_POST['sports']??'','lead'=>$_POST['lead']??'',
      'by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_nextday',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Afspraken opgeslagen.':'Dubbele invoer genegeerd.');
    redirect(baseurl('/'));
  break;

  // ------ Rapport & export ------
  case 'report': require_login(); $d=$_GET['date']??date('Y-m-d'); echo report_build_html($d); break;

  case 'export':
    require_login();
    $type=$_GET['type']??''; $date=$_GET['date']??date('Y-m-d');
    $allowed=['sessions','incidents','nextday']; if(!in_array($type,$allowed,true)){ http_response_code(400); exit('Bad type'); }
    $rows=storage_load_by_date($type,$date);
    $cols = $type==='sessions' ? ['date','time','group','kind','count','mood','interventions','flow','notes','by']
         : ($type==='incidents' ? ['date','time','y_name','summary','reported','heard','measure','by']
         : ['date','group','special','sports','lead','by']);
    $csv=export_csv($rows,$cols);
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="'.$type.'-'.$date.'.csv"');
    echo $csv;
  break;

  // ------ Admin ------
  case 'admin.users': require_login('coordinator'); include __DIR__.'/../views/pages/users.php'; break;
  case 'admin.users.add':
    require_login('coordinator');
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=admin.users')); }
    try{
      users_create(trim($_POST['name']), trim($_POST['email']), trim($_POST['role']), $_POST['password']);
      audit(user()['email'],'user_add',['email'=>$_POST['email']]);
      flash('ok','Gebruiker toegevoegd.'); redirect(baseurl('/?p=admin.users'));
    } catch(Throwable $e){ flash('err','Fout: '.$e->getMessage()); redirect(baseurl('/?p=admin.users')); }
  break;

  // ------ API (read-only) ------
  case 'api.latest':
    require_login();
    header('Content-Type: application/json; charset=utf-8');
    $f=rtrim(STORAGE_JSON,'/').'/latest.json'; if(!file_exists($f)) rebuild_latest_index(); readfile($f);
  break;
  case 'api.date':
    require_login();
    $d=$_GET['date']??date('Y-m-d');
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
      'date'=>$d,
      'sessions'=>storage_load_by_date('sessions',$d),
      'incidents'=>storage_load_by_date('incidents',$d),
      'nextday'=>storage_load_by_date('nextday',$d),
    ], JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
  break;

  default:
    http_response_code(404); echo '404';
}
PHP

# ===== bin/run-daily.php =====
cat > bin/run-daily.php <<'PHP'
<?php
require_once __DIR__.'/../app/controllers/ReportController.php';
require_once __DIR__.'/../app/services/mailer.php';
require_once __DIR__.'/../app/services/storage.php';

$date = $argv[1] ?? date('Y-m-d');
$file = report_write_file($date);

$latest = [
  'sessions'=>storage_load_by_date('sessions',$date),
  'incidents'=>storage_load_by_date('incidents',$date),
  'nextday'=>storage_load_by_date('nextday',$date),
];

$summary = sprintf(
  '<p><b>Dagrapport %s</b></p><ul><li>Sessies: %d</li><li>Incidenten: %d</li><li>Afspraken morgen: %d</li></ul><p>Bijgevoegd/gegenereerd: %s</p>',
  htmlspecialchars($date), count($latest['sessions']), count($latest['incidents']), count($latest['nextday']),
  htmlspecialchars($file)
);
mail_send('Dagrapport '.$date, $summary);
echo "Report $date -> $file\n";
PHP

# ===== bin/install-cron.sh =====
cat > bin/install-cron.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHPBIN="${PHPBIN:-php}"
( crontab -l 2>/dev/null | grep -v 'bin/run-daily.php' ; \
  echo "0 18 * * * cd \"$ROOT\" && $PHPBIN bin/run-daily.php >> storage/reports/cron.log 2>&1" ) | crontab -
echo "Cron ingesteld voor 18:00."
SH
chmod +x bin/install-cron.sh

# ===== bin/cleanup.php =====
cat > bin/cleanup.php <<'PHP'
<?php
require_once __DIR__.'/../app/services/storage.php';
cleanup_old(RETAIN_DAYS);
echo "Opschonen klaar (ouder dan ".RETAIN_DAYS." dagen verwijderd waar van toepassing).\n";
PHP

# ===== bin/add-user.php =====
cat > bin/add-user.php <<'PHP'
<?php
require_once __DIR__.'/../app/services/users.php';
$name=$argv[1]??null; $email=$argv[2]??null; $role=$argv[3]??'begeleider'; $pwd=$argv[4]??null;
if(!$name||!$email||!$pwd){ fwrite(STDERR,"Gebruik: php bin/add-user.php \"Naam\" email@domein rol wachtwoord\n"); exit(1); }
try{ $u=users_create($name,$email,$role,$pwd); echo "Aangemaakt: {$u['email']} ({$u['role']})\n"; }
catch(Throwable $e){ fwrite(STDERR,"Fout: ".$e->getMessage()."\n"); exit(1); }
PHP

# ===== .gitignore =====
cat > .gitignore <<'TXT'
/vendor/
storage/json/*.json
storage/reports/*
storage/outbox/*
storage/users/*.bak
!.gitkeep
.DS_Store
TXT

echo "✅ Klaar. Start lokaal met:
  php -S 0.0.0.0:8080 -t public
Open vervolgens: http://localhost:8080/?p=login
Default login: admin@example.org / admin123  (direct wijzigen via Gebruikers)

Dagelijks rapport plannen:
  bash bin/install-cron.sh

CLI:
  php bin/add-user.php \"Naam\" email@domein begeleider \"Wachtwoord\"
  php bin/run-daily.php 2025-08-16
  php bin/cleanup.php
"
