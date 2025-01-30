#!/bin/bash

NORMAL_DURATION=120
ANOMALOUS_DURATION=600
start_normal() {
  echo "[experiment] starting normal bot..."
  bash normal.sh &
  NORMAL_PID=$!
}

start_anomalous() {
  echo "[experiment] starting anomalous bot..."
  bash anomalous.sh &
  ANOMALOUS_PID=$!
}

stop_bots() {
  echo "[experiment] stoping bots..."
  pkill -P $$
  # kill -s SIGINT $NORMAL_PID $IRREGULAR_PID $ANOMALOUS_PID 2>/dev/null
}

trap "echo '[experiment] interrupted!'; stop_bots; exit 1" SIGINT

echo "[experiment] starting at $(date -u)"

start_normal
SLEEP=$NORMAL_DURATION
echo "[experiment] Normal user requesting for $SLEEP seconds"
sleep $SLEEP

start_anomalous
SLEEP=$ANOMALOUS_DURATION
echo "[experiment] Anomalous behavior for $SLEEP seconds"
sleep $SLEEP

echo "[experiment] done at $(date -u)"

