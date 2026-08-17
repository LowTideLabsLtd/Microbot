#!/bin/bash
# Trains Mining on Copper rocks at the East Lumbridge Swamp mine (safe,
# monster-free) until a target level is reached. Drops ore when the
# inventory fills since copper is worthless at this stage.
#
# Usage: mining_train_copper.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-15}

for cycle in $(seq 1 2000); do
  lvl=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Mining" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['level'])" 2>/dev/null)
  if [ -n "$lvl" ] && [ "$lvl" -ge "$TARGET" ] 2>/dev/null; then
    echo "TARGET_REACHED mining_level=$lvl"
    exit 0
  fi

  full=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/inventory" | python3 -c "import json,sys; print(json.load(sys.stdin)['full'])" 2>/dev/null)
  if [ "$full" = "True" ]; then
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d '{"name":"Copper ore","all":true}' "$BASE/inventory/drop" > /dev/null
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d '{"name":"Tin ore","all":true}' "$BASE/inventory/drop" > /dev/null
    sleep 1
  fi

  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Copper rocks","action":"Mine"}' "$BASE/objects/interact" > /dev/null

  sleep 4

  if [ $((cycle % 40)) -eq 0 ]; then
    CYCLE=$cycle curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Mining" | CYCLE=$cycle python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: cycle={os.environ['CYCLE']} Mining_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
  fi
done
echo "MAX_CYCLES_REACHED"
