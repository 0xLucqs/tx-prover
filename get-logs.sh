#!/usr/bin/env bash
# Reads prover logs from the iOS simulator app container.
set -euo pipefail
CONTAINER=$(xcrun simctl get_app_container booted com.txprover.TxProver data 2>/dev/null)
LOG_FILE="${CONTAINER}/Documents/prover_logs.txt"
if [ -f "$LOG_FILE" ]; then
    cat "$LOG_FILE"
else
    echo "No logs found. Press 'Save Logs' in the app first."
fi
