<?php
function h($v){ return htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8'); }
function post($k,$d=''){ return isset($_POST[$k]) ? trim((string)$_POST[$k]) : $d; }
function redirect($path){
  $base = rtrim(APP_URL,'/').'/public/';
  header('Location: '.$base.ltrim($path,'/')); exit;
}
function today(){ return (new DateTime('today'))->format('Y-m-d'); }
function tomorrow(){ return (new DateTime('tomorrow'))->format('Y-m-d'); }
