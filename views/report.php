<?php
$date = $_GET['date'] ?? today();
$file = save_report_html($date);
$html = file_get_contents($file);
echo '<div class="card success"><strong>Rapport gegenereerd:</strong> '.h(basename($file)).'</div>';
echo '<div class="card"><a class="btn" href="../storage/reports/'.h(basename($file)).'" target="_blank">Open rapport</a></div>';
echo '<div class="card">'.$html.'</div>';
