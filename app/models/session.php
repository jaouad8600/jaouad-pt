<?php
require_once __DIR__.'/../db.php';

function session_create($data){
  $sql="INSERT INTO sessions
    (created_at, date, group_name, youth_count, kind, progress, mood, interventions, remarks, submitted_by)
    VALUES (NOW(), :date, :group_name, :youth_count, :kind, :progress, :mood, :interventions, :remarks, :submitted_by)";
  db()->prepare($sql)->execute($data);
}

function sessions_by_date($date){
  $st=db()->prepare("SELECT * FROM sessions WHERE date=:d ORDER BY group_name");
  $st->execute([':d'=>$date]); return $st->fetchAll();
}
