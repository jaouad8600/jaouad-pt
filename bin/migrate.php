<?php
require_once __DIR__.'/../app/db.php';
$sql = file_get_contents(__DIR__.'/../.github/schema.sql');
db()->exec($sql);
echo "Database gemigreerd.\n";
