<?php
// Basisconfig
define('APP_NAME', 'Rapportages (no-DB)');
define('APP_URL', 'http://localhost:8080'); // pas aan indien nodig

// Mail is nu uitgeschakeld (later aan te zetten)
define('MAIL_MODE', 'disabled'); // 'disabled' | 'mail' | 'smtp'
define('SMTP_HOST', 'smtp.office365.com');
define('SMTP_PORT', 587);
define('SMTP_SECURE', 'tls');
define('SMTP_USER', '');
define('SMTP_PASS', '');

// Pad voor opslag
define('STORAGE_JSON', __DIR__ . '/../storage/json');
define('STORAGE_REPORTS', __DIR__ . '/../storage/reports');

// Helpers
function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
