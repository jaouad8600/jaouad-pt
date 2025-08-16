<?php
require_once __DIR__.'/../core/helpers.php';

function storage_path($type,$date){ return rtrim(STORAGE_JSON,'/')."/$type/$date.json"; }

function storage_load_by_date($type,$date): array {
  $f=storage_path($type,$date); if(!file_exists($f)) return [];
  $d=json_decode(file_get_contents($f),true); return is_array($d)?$d:[];
}

function storage_list_dates($type): array {
  $dir=rtrim(STORAGE_JSON,'/')."/$type"; if(!is_dir($dir)) return [];
  $files=glob($dir.'/*.json'); sort($files);
  return array_map(fn($f)=>basename($f,'.json'),$files);
}

function latest_date(): ?string {
  $dates=array_unique(array_merge(
    storage_list_dates('sessions'),
    storage_list_dates('incidents'),
    storage_list_dates('nextday')
  ));
  sort($dates); return $dates?end($dates):null;
}

function payload_hash(array $p): string {
  $copy=$p; unset($copy['_id'],$copy['_ts']);
  return hash('xxh128', json_encode($copy,JSON_UNESCAPED_UNICODE));
}

function storage_save($type,array $payload,int $dupeWindow=300): array {
  $date=$payload['date']??date('Y-m-d'); $file=storage_path($type,$date);
  ensure_dir(dirname($file));
  $arr=file_exists($file)?(json_decode(file_get_contents($file),true)?:[]):[];
  $h=payload_hash($payload); $now=time();
  foreach(array_reverse($arr) as $it){
    if(($it['_hash']??'')===$h && (abs($now - strtotime($it['_ts']??$payload['date'].' 00:00'))<=$dupeWindow)){
      return [$file,count($arr),false]; // duplicate binnen venster
    }
  }
  $payload['_id']=$payload['_id']??uuid();
  $payload['_ts']=date('c');
  $payload['_hash']=$h;
  $arr[]=$payload;
  file_put_contents($file, json_encode($arr,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
  rebuild_latest_index();
  return [$file,count($arr),true];
}

function rebuild_latest_index(): void {
  $latest=latest_date();
  $out=['date'=>null,'sessions'=>[],'incidents'=>[],'nextday'=>[]];
  if($latest){
    $out['date']=$latest;
    $out['sessions']=storage_load_by_date('sessions',$latest);
    $out['incidents']=storage_load_by_date('incidents',$latest);
    $out['nextday']=storage_load_by_date('nextday',$latest);
  }
  ensure_dir(STORAGE_JSON);
  file_put_contents(rtrim(STORAGE_JSON,'/').'/latest.json', json_encode($out,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));
}

function export_csv(array $rows,array $cols): string {
  $fh=fopen('php://temp','w+'); fputcsv($fh,$cols,';');
  foreach($rows as $r){ $line=[]; foreach($cols as $c){ $line[]=$r[$c]??''; } fputcsv($fh,$line,';'); }
  rewind($fh); return stream_get_contents($fh);
}

function cleanup_old(int $days){
  $before=strtotime("-{$days} days");
  foreach(['sessions','incidents','nextday'] as $t){
    $dir=rtrim(STORAGE_JSON,'/')."/$t";
    if(!is_dir($dir)) continue;
    foreach(glob("$dir/*.json") as $f){
      $d=basename($f,'.json');
      if(strtotime($d)<$before) @unlink($f);
    }
  }
}
