<?php require_once __DIR__.'/../app/config.php'; ?>
<!doctype html><html lang="nl">
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title><?=h(APP_NAME)?></title>
<link rel="stylesheet" href="assets/style.css">
<div class="wrap">
  <h1><?=h(APP_NAME)?></h1>
  <nav>
    <a class="btn" href="./">Dashboard</a>
    <a class="btn" href="?p=session">Nieuw sport/creatief moment</a>
    <a class="btn" href="?p=incident">Nieuw incident</a>
    <a class="btn" href="?p=notes">Afspraken voor morgen</a>
    <a class="btn" href="?p=report">Rapport voor vandaag</a>
  </nav>
