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
