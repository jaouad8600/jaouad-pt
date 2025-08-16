<?php
require_once __DIR__.'/../app/services/users.php';
$name=$argv[1]??null; $email=$argv[2]??null; $role=$argv[3]??'begeleider'; $pwd=$argv[4]??null;
if(!$name||!$email||!$pwd){ fwrite(STDERR,"Gebruik: php bin/add-user.php \"Naam\" email@domein rol wachtwoord\n"); exit(1); }
try{ $u=users_create($name,$email,$role,$pwd); echo "Aangemaakt: {$u['email']} ({$u['role']})\n"; }
catch(Throwable $e){ fwrite(STDERR,"Fout: ".$e->getMessage()."\n"); exit(1); }
