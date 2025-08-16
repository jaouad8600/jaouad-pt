<?php
require_once __DIR__.'/../app/core/config.php';
require_once __DIR__.'/../app/core/helpers.php';
require_once __DIR__.'/../app/services/users.php';
require_once __DIR__.'/../app/services/storage.php';
require_once __DIR__.'/../app/services/mailer.php';
require_once __DIR__.'/../app/controllers/ReportController.php';

session_start_safe(); users_init_once();

function old_store($key,$input,$errors){ $_SESSION['_old_input'][$key]=$input; $_SESSION['_old_errors'][$key]=$errors; }

$action = $_GET['p'] ?? 'dashboard';

switch($action){

  // ------ Auth ------
  case 'login': if(user()){ redirect(baseurl('/')); } include __DIR__.'/../views/auth/login.php'; break;
  case 'login.post':
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF ongeldig'); redirect(baseurl('/?p=login')); }
    if(auth_login($_POST['email']??'', $_POST['password']??'')){ flash('ok','Welkom!'); redirect(baseurl('/')); }
    $_SESSION['_old_input']['login']=$_POST; flash('err','Onjuiste inlog'); redirect(baseurl('/?p=login'));
  break;
  case 'logout': auth_logout(); flash('ok','Uitgelogd'); redirect(baseurl('/?p=login')); break;

  // ------ Dashboard ------
  case 'dashboard': require_login(); include __DIR__.'/../views/pages/dashboard.php'; break;

  // ------ Forms ------
  case 'session': require_login(); include __DIR__.'/../views/forms/session.php'; break;
  case 'session.save':
    require_login();
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=session')); }
    $rules=['date'=>'required','group'=>'required','count'=>'int'];
    $err=validate($_POST,$rules);
    if($err){ old_store('session',$_POST,$err); redirect(baseurl('/?p=session')); }
    [$f,$n,$new]=storage_save('sessions',[
      'date'=>$_POST['date'],'time'=>$_POST['time']??'','group'=>$_POST['group']??'',
      'count'=>$_POST['count']??'0','kind'=>$_POST['kind']??'Sport','mood'=>$_POST['mood']??'',
      'interventions'=>$_POST['interventions']??'','flow'=>$_POST['flow']??'','notes'=>$_POST['notes']??'',
      'by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_session',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Sessie opgeslagen.':'Dubbele invoer genegeerd (binnen 5 min).');
    redirect(baseurl('/'));
  break;

  case 'incident': require_login('coordinator'); include __DIR__.'/../views/forms/incident.php'; break;
  case 'incident.save':
    require_login('coordinator');
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=incident')); }
    $rules=['date'=>'required','y_name'=>'required'];
    $err=validate($_POST,$rules);
    if($err){ old_store('incident',$_POST,$err); redirect(baseurl('/?p=incident')); }
    [$f,$n,$new]=storage_save('incidents',[
      'date'=>$_POST['date'],'time'=>$_POST['time']??'','y_name'=>$_POST['y_name']??'',
      'summary'=>$_POST['summary']??'','reported'=>$_POST['reported']??'nee','heard'=>$_POST['heard']??'nee',
      'measure'=>$_POST['measure']??'','by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_incident',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Incident opgeslagen.':'Dubbele invoer genegeerd.');
    redirect(baseurl('/'));
  break;

  case 'nextday': require_login(); include __DIR__.'/../views/forms/nextday.php'; break;
  case 'nextday.save':
    require_login();
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=nextday')); }
    $rules=['date'=>'required','group'=>'required']; $err=validate($_POST,$rules);
    if($err){ old_store('nextday',$_POST,$err); redirect(baseurl('/?p=nextday')); }
    [$f,$n,$new]=storage_save('nextday',[
      'date'=>$_POST['date'],'group'=>$_POST['group']??'',
      'special'=>$_POST['special']??'','sports'=>$_POST['sports']??'','lead'=>$_POST['lead']??'',
      'by'=>user()['email']??'anon'
    ]);
    audit(user()['email']??'-','add_nextday',['file'=>$f,'new'=>$new]);
    flash('ok', $new?'Afspraken opgeslagen.':'Dubbele invoer genegeerd.');
    redirect(baseurl('/'));
  break;

  // ------ Rapport & export ------
  case 'report': require_login(); $d=$_GET['date']??date('Y-m-d'); echo report_build_html($d); break;

  case 'export':
    require_login();
    $type=$_GET['type']??''; $date=$_GET['date']??date('Y-m-d');
    $allowed=['sessions','incidents','nextday']; if(!in_array($type,$allowed,true)){ http_response_code(400); exit('Bad type'); }
    $rows=storage_load_by_date($type,$date);
    $cols = $type==='sessions' ? ['date','time','group','kind','count','mood','interventions','flow','notes','by']
         : ($type==='incidents' ? ['date','time','y_name','summary','reported','heard','measure','by']
         : ['date','group','special','sports','lead','by']);
    $csv=export_csv($rows,$cols);
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="'.$type.'-'.$date.'.csv"');
    echo $csv;
  break;

  // ------ Admin ------
  case 'admin.users': require_login('coordinator'); include __DIR__.'/../views/pages/users.php'; break;
  case 'admin.users.add':
    require_login('coordinator');
    if(!csrf_check($_POST['csrf']??'')){ flash('err','CSRF'); redirect(baseurl('/?p=admin.users')); }
    try{
      users_create(trim($_POST['name']), trim($_POST['email']), trim($_POST['role']), $_POST['password']);
      audit(user()['email'],'user_add',['email'=>$_POST['email']]);
      flash('ok','Gebruiker toegevoegd.'); redirect(baseurl('/?p=admin.users'));
    } catch(Throwable $e){ flash('err','Fout: '.$e->getMessage()); redirect(baseurl('/?p=admin.users')); }
  break;

  // ------ API (read-only) ------
  case 'api.latest':
    require_login();
    header('Content-Type: application/json; charset=utf-8');
    $f=rtrim(STORAGE_JSON,'/').'/latest.json'; if(!file_exists($f)) rebuild_latest_index(); readfile($f);
  break;
  case 'api.date':
    require_login();
    $d=$_GET['date']??date('Y-m-d');
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
      'date'=>$d,
      'sessions'=>storage_load_by_date('sessions',$d),
      'incidents'=>storage_load_by_date('incidents',$d),
      'nextday'=>storage_load_by_date('nextday',$d),
    ], JSON_UNESCAPED_UNICODE|JSON_PRETTY_PRINT);
  break;

  default:
    http_response_code(404); echo '404';
}
