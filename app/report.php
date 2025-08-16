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
