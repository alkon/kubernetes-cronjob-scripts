#!/bin/bash

if [ -z "$SHARED_LOG_PATH" ]; then
  LOG_DIR="/shared-logs"  # Default path if SHARED_LOG_PATH is not set
else
  LOG_DIR="$SHARED_LOG_PATH"
fi

mkdir -p "$LOG_DIR"
date >> "$LOG_DIR/date.log"
echo "---" >> "$LOG_DIR/date.log"
cat "$LOG_DIR/date.log"
# sleep 10