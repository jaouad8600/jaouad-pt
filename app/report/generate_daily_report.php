<?php
require_once __DIR__.'/../config.php';
require_once __DIR__.'/../helpers.php';
require_once __DIR__.'/../models/session.php';
require_once __DIR__.'/../models/incident.php';
require_once __DIR__.'/../models/note.php';

function render_daily_html($date=null){
  $date = $date ?: today();
  $sessions = sessions_by_date($date);
  $incidents = incidents_by_date($date);
  $notes = note_by_date((new DateTime($date))->modify('+1 day')->format('Y-m-d'));

  ob_start(); ?>
<!doctype html>
<html lang="nl"><meta charset="utf-8">
<title><?=h(APP_NAME)?> — Dagrapport <?=h($date)?></title>
<style>
  body{font:14px/1.5 system-ui, -apple-system, Segoe UI, Roboto, Arial; margin:24px; color:#0f172a;}
  h1{font-size:22px;margin:0 0 8px}
  h2{font-size:18px;margin:20px 0 8px;border-bottom:1px solid #e2e8f0;padding-bottom:4px}
  .box{background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px;margin:8px 0}
  .muted{color:#475569;font-size:13px}
  .grid{display:grid; gap:8px}
  .grid2{grid-template-columns:1fr 1fr}
  table{border-collapse:collapse;width:100%}
  td,th{border:1px solid #e5e7eb;padding:6px;text-align:left;vertical-align:top}
  small{color:#64748b}
</style>
<h1>Dagrapport <?=h($date)?></h1>
<div class="muted">Gegenereerd op <?=h((new DateTime())->format('d-m-Y H:i:s'))?></div>

<h2>Sessies (sport/creatief)</h2>
<?php if(!$sessions): ?>
  <div class="box muted">Geen sessies geregistreerd.</div>
<?php else: ?>
<table>
  <tr><th>Groep</th><th>Type</th><th>Jongeren</th><th>Sfeer</th><th>Interventies</th><th>Verloop</th><th>Opmerkingen</th><th>Ingevuld door</th></tr>
  <?php foreach($sessions as $s): ?>
  <tr>
    <td><?=h($s['group_name'])?></td>
    <td><?=h($s['kind'])?></td>
    <td><?=h($s['youth_count'])?></td>
    <td><?=h($s['mood'])?></td>
    <td><?=nl2br(h($s['interventions']))?></td>
    <td><?=nl2br(h($s['progress']))?></td>
    <td><?=nl2br(h($s['remarks']))?></td>
    <td><small><?=h($s['submitted_by'])?></small></td>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<h2>Incidenten (kamer-/opvangplaatsing e.d.)</h2>
<?php if(!$incidents): ?>
  <div class="box muted">Geen incidenten geregistreerd.</div>
<?php else: ?>
<table>
  <tr><th>Tijd</th><th>Jongere</th><th>Omschrijving</th><th>Melding gedaan</th><th>Gehoord</th><th>Maatregel</th><th>Door</th></tr>
  <?php foreach($incidents as $i): ?>
  <tr>
    <td><?=h(substr($i['time_at'],0,5))?></td>
    <td><?=h($i['youth_first'].' '.$i['youth_last'])?></td>
    <td><?=nl2br(h($i['summary']))?></td>
    <td><?= $i['reported']?'Ja':'Nee' ?></td>
    <td><?= $i['heard']?'Ja':'Nee' ?></td>
    <td><?=h($i['measure'])?></td>
    <td><small><?=h($i['submitted_by'])?></small></td>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<h2>Afspraken voor morgen (<?=h((new DateTime($date))->modify('+1 day')->format('Y-m-d'))?>)</h2>
<?php if(!$notes): ?>
  <div class="box muted">Nog geen afspraken genoteerd.</div>
<?php else: ?>
<div class="grid grid2">
  <div class="box"><strong>Speciale aandachtspunten</strong><br><?=nl2br(h($notes['special_attention']))?></div>
  <div class="box"><strong>Sportafspraken</strong><br><?=nl2br(h($notes['sport_appointments']))?></div>
  <div class="box"><strong>Afspraken met groepsleiding</strong><br><?=nl2br(h($notes['group_agreements']))?></div>
</div>
<?php endif; ?>

<hr>
<small>Automatische dagrapportage door <?=h(APP_NAME)?>.</small>
</html>
<?php
  return ob_get_clean();
}

function save_report_html($date=null){
  $date = $date ?: today();
  $html = render_daily_html($date);
  $dir = __DIR__.'/../../storage/reports';
  if(!is_dir($dir)) mkdir($dir, 0777, true);
  $file = $dir.'/report-'.$date.'.html';
  file_put_contents($file, $html);
  return $file;
}
