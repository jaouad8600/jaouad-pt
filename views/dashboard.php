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
