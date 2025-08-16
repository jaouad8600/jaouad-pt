<?php
// === App ===
const APP_NAME    = 'Teylingereind Rapportages (no-DB)';
const APP_BRAND   = 'Teylingereind';
const APP_TIMEZONE= 'Europe/Amsterdam';
const APP_BASEURL = ''; // bv. '' of '/rapport'

// === Security ===
const APP_SESSION_NAME = 'tey_rep_sess';
const CSRF_KEY = 'csrf_token';

// === Opslag ===
define('STORAGE_JSON',    __DIR__.'/../../storage/json');    // /sessions/YYYY-MM-DD.json etc.
define('STORAGE_REPORTS', __DIR__.'/../../storage/reports'); // dagrapporten (HTML)
define('STORAGE_OUTBOX',  __DIR__.'/../../storage/outbox');  // .eml mails
define('STORAGE_USERS',   __DIR__.'/../../storage/users/users.json');
define('STORAGE_AUDIT',   __DIR__.'/../../storage/audit.log');

// === Retentie (dagen) ===
const RETAIN_DAYS = 365;

// === Mail ===
// modes: 'disabled' | 'file' (schrijft .eml) | 'mail' (php mail())
// SMTP later mogelijk als je wilt — nu buiten scope zonder composer.
const MAIL_MODE = 'file';
const MAIL_FROM = 'noreply@example.org';
const MAIL_TO   = 'team@example.org';
date_default_timezone_set(APP_TIMEZONE);
