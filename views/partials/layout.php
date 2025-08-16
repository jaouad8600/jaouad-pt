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
