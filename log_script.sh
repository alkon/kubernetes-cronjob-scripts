#!/bin/bash
LOG_DIR=$(SHARED_LOG_PATH)
mkdir -p "$LOG_DIR"
date >> "$LOG_DIR/date.log"
echo "---" >> "$LOG_DIR/date.log"
cat "$LOG_DIR/date.log"
#sleep 10