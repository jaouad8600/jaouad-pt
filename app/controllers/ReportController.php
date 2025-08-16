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
