<?php
require_once __DIR__.'/../app/services/storage.php';
cleanup_old(RETAIN_DAYS);
echo "Opschonen klaar (ouder dan ".RETAIN_DAYS." dagen verwijderd waar van toepassing).\n";
