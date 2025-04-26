#!/bin/bash

HOST="https://envoy.zt.local:8001"
URI="/items"
CERTS_FOLDERS="$HOME/zero-trust/commons/certs"
CACERT="$CERTS_FOLDERS/ca.crt"
CERT="$CERTS_FOLDERS/anomalous.crt"
KEY="$CERTS_FOLDERS/anomalous.key"
TARGETS_FILE="anomalous_targets.txt"
REPORTS_FILE="anomalous_low_rate.bin"
INTERVAL=1
RATE=1
WORKERS=1
DURATION="2m"

attack() {
  vegeta attack \
    -name="anomalous" \
    -cert=$CERT \
    -key=$KEY \
    -targets=$TARGETS_FILE \
    -root-certs=$CACERT \
    -max-body=0 \
    -rate=$RATE \
    -workers=$WORKERS \
    -duration=$DURATION | tee anomalous_low_rate.bin | vegeta encode --to=json --output=anomalous_low_rate.json
}

stop() {
  echo "[anomalous] stopping anomalous-low-rate..."
  pkill -P $$
  exit 0
}

echo "[anomalous] creating targets file"

if [ ! -f "$TARGETS_FILE" ]; then
  echo "GET $HOST$URI" > $TARGETS_FILE
  echo "[anomalous] targets created with default route"
else
  echo "[anomalous] targets already exists, skipping..."
fi

trap "stop" SIGINT
trap "stop" SIGTERM

echo "[anomalous] starting 'anomalous' with regular behavior for $DURATION at $(date -u)"

attack

echo "[anomalous] 'anomalous' regular behavior finished (for now)"
