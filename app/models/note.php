<?php
require_once __DIR__.'/../db.php';

function note_upsert($data){
  // per datum 1 record met drie velden
  $sql="INSERT INTO notes (for_date, created_at, special_attention, sport_appointments, group_agreements, submitted_by)
        VALUES (:for_date, NOW(), :special_attention, :sport_appointments, :group_agreements, :submitted_by)
        ON DUPLICATE KEY UPDATE
          special_attention=VALUES(special_attention),
          sport_appointments=VALUES(sport_appointments),
          group_agreements=VALUES(group_agreements),
          submitted_by=VALUES(submitted_by)";
  db()->prepare($sql)->execute($data);
}

function note_by_date($d){
  $st=db()->prepare("SELECT * FROM notes WHERE for_date=:d LIMIT 1");
  $st->execute([':d'=>$d]); return $st->fetch() ?: null;
}
