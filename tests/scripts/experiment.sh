#!/bin/bash

NORMAL_DURATION=480
ANOMALOUS_LOW_RATE_DURATION=120
ANOMALOUS_DURATION=360
start_normal() {
  echo "[experiment] starting normal bot..."
  bash normal.sh &
  NORMAL_PID=$!
}

start_anomalous_low_rate() {
  echo "[experiment] starting anomalous with normal behavior bot..."
  bash anomalous-low-rate.sh &
  ANOMALOUS_LOW_RATE_PID=$!
}

start_anomalous() {
  echo "[experiment] starting anomalous on attack behavior bot..."
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
start_anomalous_low_rate
SLEEP=$ANOMALOUS_LOW_RATE_DURATION
echo "[experiment] Normal behaviors on requesting for $SLEEP seconds"
sleep $SLEEP

start_anomalous
SLEEP=$ANOMALOUS_DURATION
echo "[experiment] Anomalous behavior for $SLEEP seconds"
sleep $SLEEP

echo "[experiment] done at $(date -u)"

