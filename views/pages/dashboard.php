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
