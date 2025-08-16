<?php
require_once __DIR__.'/../db.php';

function incident_create($data){
  $sql="INSERT INTO incidents
    (created_at, date, time_at, youth_first, youth_last, summary, reported, heard, measure, submitted_by)
    VALUES (NOW(), :date, :time_at, :youth_first, :youth_last, :summary, :reported, :heard, :measure, :submitted_by)";
  db()->prepare($sql)->execute($data);
}

function incidents_by_date($date){
  $st=db()->prepare("SELECT * FROM incidents WHERE date=:d ORDER BY time_at");
  $st->execute([':d'=>$date]); return $st->fetchAll();
}
