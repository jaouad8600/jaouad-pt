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
