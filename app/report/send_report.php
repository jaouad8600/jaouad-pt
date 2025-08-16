<?php
require_once __DIR__.'/../config.php';

function send_report_email($subject, $html){
  if (MAIL_MODE==='disabled') return false;

  if (MAIL_MODE==='mail') {
    $headers = [];
    $headers[] = 'MIME-Version: 1.0';
    $headers[] = 'Content-type: text/html; charset=utf-8';
    $headers[] = 'From: '.MAIL_FROM_NAME.' <'.MAIL_FROM.'>';
    return @mail(MAIL_TO, $subject, $html, implode("\r\n",$headers));
  }

  if (MAIL_MODE==='smtp') {
    // Eenvoudige SMTP via fsockopen (geen externe libs), voldoet voor basis.
    $to = MAIL_TO;
    $from = MAIL_FROM;
    $name = MAIL_FROM_NAME;

    $boundary = 'bnd_'.bin2hex(random_bytes(6));
    $subjectEnc = '=?UTF-8?B?'.base64_encode($subject).'?=';
    $data = "From: $name <$from>\r\n".
            "To: <$to>\r\n".
            "Subject: $subjectEnc\r\n".
            "MIME-Version: 1.0\r\n".
            "Content-Type: text/html; charset=UTF-8\r\n\r\n".
            $html;

    $host = SMTP_HOST; $port = SMTP_PORT;
    $fp = fsockopen(($port==465?'ssl://':'').$host, $port, $errno, $errstr, 30);
    if(!$fp) return false;
    $read = function() use($fp){ return fgets($fp, 515); };
    $cmd = function($c) use($fp){ fputs($fp, $c."\r\n"); };

    $read();
    $cmd('EHLO localhost'); $read(); $read(); $read(); $read();
    if (SMTP_SECURE==='tls') { $cmd('STARTTLS'); $read(); stream_socket_enable_crypto($fp, true, STREAM_CRYPTO_METHOD_TLS_CLIENT); $cmd('EHLO localhost'); $read(); $read(); $read(); $read(); }
    $cmd('AUTH LOGIN'); $read();
    $cmd(base64_encode(SMTP_USER)); $read();
    $cmd(base64_encode(SMTP_PASS)); $read();
    $cmd("MAIL FROM:<$from>"); $read();
    $cmd("RCPT TO:<$to>"); $read();
    $cmd("DATA"); $read();
    fputs($fp, $data."\r\n.\r\n"); $read();
    $cmd("QUIT"); fclose($fp);
    return true;
  }
  return false;
}
