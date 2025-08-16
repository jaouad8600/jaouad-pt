<?php
require_once __DIR__ . '/config.php';

function ensure_dir($p){ if(!is_dir($p)) mkdir($p, 0775, true); }

function save_item(string $type, array $payload): array {
  $date = $payload['date'] ?? date('Y-m-d');
  $dir = rtrim(STORAGE_JSON, '/')."/$type";
  ensure_dir($dir);
  $file = "$dir/$date.json";
  $data = file_exists($file) ? json_decode(file_get_contents($file), true) : [];
  $payload['_ts'] = date('c');
  $data[] = $payload;
  file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
  return [$file, count($data)];
}

function load_items_by_date(string $type, string $date): array {
  $file = rtrim(STORAGE_JSON, '/')."/$type/$date.json";
  if(!file_exists($file)) return [];
  return json_decode(file_get_contents($file), true) ?: [];
}

function list_dates(string $type): array {
  $dir = rtrim(STORAGE_JSON, '/')."/$type";
  if(!is_dir($dir)) return [];
  $files = glob($dir.'/*.json'); sort($files);
  return array_map(fn($f)=>basename($f, '.json'), $files);
}

function latest_date(): ?string {
  $dates = array_unique(array_merge(
    list_dates('sessions'),
    list_dates('incidents'),
    list_dates('nextday')
  ));
  sort($dates);
  return $dates ? end($dates) : null;
}
