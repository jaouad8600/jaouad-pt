<?php
require_once __DIR__.'/../core/helpers.php';

function mail_send($subject,$html,$to=MAIL_TO): string {
  $boundary = 'b-'.bin2hex(random_bytes(8));
  $headers = [
    "From: ".MAIL_FROM,
    "MIME-Version: 1.0",
    "Content-Type: multipart/alternative; boundary=\"$boundary\""
  ];
  $body = "--$boundary\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n".
          strip_tags($html)."\r\n".
          "--$boundary\r\nContent-Type: text/html; charset=utf-8\r\n\r\n".
          $html."\r\n--$boundary--\r\n";

  if(MAIL_MODE==='disabled'){
    $file=rtrim(STORAGE_OUTBOX,'/').'/'.date('Ymd-His').'-DISABLED.eml';
    ensure_dir(dirname($file));
    file_put_contents($file, "To: $to\r\nSubject: $subject\r\n".implode("\r\n",$headers)."\r\n\r\n".$body);
    return $file;
  }
  if(MAIL_MODE==='file'){
    $file=rtrim(STORAGE_OUTBOX,'/').'/'.date('Ymd-His').'-out.eml';
    ensure_dir(dirname($file));
    file_put_contents($file, "To: $to\r\nSubject: $subject\r\n".implode("\r\n",$headers)."\r\n\r\n".$body);
    return $file;
  }
  if(MAIL_MODE==='mail'){
    $ok = mail($to, $subject, $body, implode("\r\n",$headers));
    return $ok ? 'mail() sent' : 'mail() failed';
  }
  return 'unsupported mode';
}
