#!/bin/bash
# Trains Woodcutting on regular trees around Lumbridge until a target level is
# reached (default 15). Drops logs when the inventory fills since they are
# worthless at this stage. Auto-recovers from disconnects via relogin_recovery.sh.
#
# Usage: woodcutting_train_trees.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-15}
START_X=3195
START_Y=3230

for cycle in $(seq 1 4000); do
  if [ $((cycle % 10)) -eq 0 ]; then
    "$DIR/relogin_recovery.sh" 535 "$START_X" "$START_Y" 0
  fi

  lvl=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Woodcutting" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['level'])" 2>/dev/null)
  if [ -n "$lvl" ] && [ "$lvl" -ge "$TARGET" ] 2>/dev/null; then
    echo "TARGET_REACHED woodcutting_level=$lvl"
    exit 0
  fi

  hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
  if [ -n "$hp" ] && [ "$hp" -le 6 ] 2>/dev/null; then
    echo "LOW_HP hp=$hp -- STOPPING for safety"
    exit 1
  fi

  full=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/inventory" | python3 -c "import json,sys; print(json.load(sys.stdin)['full'])" 2>/dev/null)
  if [ "$full" = "True" ]; then
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d '{"name":"Logs","all":true}' "$BASE/inventory/drop" > /dev/null
    for extra in "Bird nest" "Bird nest (empty)" "Oak leaves" "Teak leaves" "Leaves"; do
      curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
        -d "{\"name\":\"$extra\",\"all\":true}" "$BASE/inventory/drop" > /dev/null
    done
    sleep 1
  fi

  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Tree","action":"Chop down"}' "$BASE/objects/interact" > /dev/null

  sleep 2

  if [ $((cycle % 30)) -eq 0 ]; then
    CYCLE=$cycle curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Woodcutting" | CYCLE=$cycle python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: cycle={os.environ['CYCLE']} Woodcutting_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
  fi
done
echo "MAX_CYCLES_REACHED"
