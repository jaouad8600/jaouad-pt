#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHPBIN="${PHPBIN:-php}"
( crontab -l 2>/dev/null | grep -v 'bin/run-daily.php' ; \
  echo "0 18 * * * cd \"$ROOT\" && $PHPBIN bin/run-daily.php >> storage/reports/cron.log 2>&1" ) | crontab -
echo "Cron ingesteld voor 18:00."
