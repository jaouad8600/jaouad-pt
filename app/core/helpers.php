<?php
require_once __DIR__.'/config.php';

function h($s){ return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }
function ensure_dir($p){ if(!is_dir($p)) mkdir($p,0775,true); }
function baseurl($p=''){ return APP_BASEURL.$p; }
function redirect($p){ header('Location: '.$p); exit; }

function uuid(): string {
  $d = random_bytes(16);
  $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
  $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
  return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

function session_start_safe(){
  if(session_status()!==PHP_SESSION_ACTIVE){
    session_name(APP_SESSION_NAME);
    session_start();
  }
}

function csrf_token(): string {
  session_start_safe();
  if(empty($_SESSION[CSRF_KEY])) $_SESSION[CSRF_KEY]=bin2hex(random_bytes(32));
  return $_SESSION[CSRF_KEY];
}
function csrf_check($t): bool {
  session_start_safe();
  return hash_equals($_SESSION[CSRF_KEY]??'', (string)$t);
}

function flash($key, $msg=null){
  session_start_safe();
  if($msg===null){ $m=$_SESSION['_flash'][$key]??null; unset($_SESSION['_flash'][$key]); return $m; }
  $_SESSION['_flash'][$key]=$msg;
}

function validate(array $data, array $rules): array {
  $errors=[];
  foreach($rules as $field=>$rule){
    $v=trim((string)($data[$field]??''));
    foreach(explode('|',$rule) as $r){
      if($r==='required' && $v==='') $errors[$field]='Verplicht veld';
      if($r==='int' && $v!=='' && !preg_match('/^\d+$/',$v)) $errors[$field]='Moet een getal zijn';
      if(str_starts_with($r,'in:')){
        $ops=explode(',',substr($r,3)); if($v!=='' && !in_array($v,$ops,true)) $errors[$field]='Ongeldige waarde';
      }
    }
  }
  return $errors;
}

function audit($who, $action, $meta=[]){
  $line = json_encode([
    'ts'=>date('c'),'who'=>$who,'action'=>$action,'meta'=>$meta
  ], JSON_UNESCAPED_UNICODE);
  file_put_contents(STORAGE_AUDIT, $line.PHP_EOL, FILE_APPEND);
}

function user(){ session_start_safe(); return $_SESSION['user']??null; }
function is_role($role){ $u=user(); if(!$u) return false; return $u['role']===$role || $u['role']==='coordinator'; }
function require_login($role=null){
  if(!user()) redirect(baseurl('/?p=login'));
  if($role && !is_role($role)) redirect(baseurl('/'));
}
