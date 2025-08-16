<?php
require_once __DIR__.'/../core/helpers.php';

function users_all(): array {
  if(!file_exists(STORAGE_USERS)) return [];
  $j = json_decode(file_get_contents(STORAGE_USERS), true);
  return is_array($j)?$j:[];
}
function users_save_all(array $a): void {
  ensure_dir(dirname(STORAGE_USERS));
  file_put_contents(STORAGE_USERS, json_encode($a, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}
function users_init_once(){
  if(file_exists(STORAGE_USERS)) return;
  $pwd = password_hash('admin123', PASSWORD_DEFAULT);
  users_save_all([[ 'id'=>uuid(),'name'=>'Admin','email'=>'admin@example.org','role'=>'coordinator','pwd'=>$pwd ]]);
}
function users_find_email($email){
  foreach(users_all() as $u){ if(strtolower($u['email'])===strtolower($email)) return $u; }
  return null;
}
function users_create($name,$email,$role,$password): array {
  $all=users_all();
  if(users_find_email($email)) throw new RuntimeException('Email bestaat al');
  $u = ['id'=>uuid(),'name'=>$name,'email'=>$email,'role'=>$role,'pwd'=>password_hash($password,PASSWORD_DEFAULT)];
  $all[]=$u; users_save_all($all); return $u;
}
function auth_login($email,$password): bool {
  session_start_safe(); users_init_once();
  $u=users_find_email($email); if(!$u) return false;
  if(!password_verify($password, $u['pwd'])) return false;
  $_SESSION['user']=['id'=>$u['id'],'name'=>$u['name'],'email'=>$u['email'],'role'=>$u['role']];
  audit($u['email'],'login');
  return true;
}
function auth_logout(){
  if(user()) audit(user()['email'],'logout');
  session_start_safe(); $_SESSION=[]; session_destroy();
}
