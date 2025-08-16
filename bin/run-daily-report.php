<?php
require_once __DIR__.'/../app/controllers/ReportController.php';
$date = $argv[1] ?? date('Y-m-d');
$file = report_write_file($date);
fwrite(STDOUT, "Report for $date -> $file\n");
