#!/bin/bash
# Power-mines Iron rocks at the Isle of Souls mine (safe, monster-free,
# members-only): mine, drop ore, repeat. Also drops accumulated gems and
# clue geodes when the inventory fills. Auto-recovers from disconnects via
# relogin_recovery.sh, pinned to a members world since this spot is
# members-only territory.
#
# Usage: mining_powermine_iron.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-70}
MINE_X=2196
MINE_Y=2792

for cycle in $(seq 1 50000); do
  if [ $((cycle % 10)) -eq 0 ]; then
    "$DIR/relogin_recovery.sh" 535 "$MINE_X" "$MINE_Y" 0
  fi

  lvl=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Mining" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['level'])" 2>/dev/null)
  if [ -n "$lvl" ] && [ "$lvl" -ge "$TARGET" ] 2>/dev/null; then
    echo "TARGET_REACHED mining_level=$lvl"
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
      -d '{"name":"Iron ore","all":true}' "$BASE/inventory/drop" > /dev/null
    for gem in "Uncut sapphire" "Uncut emerald" "Uncut ruby" "Uncut diamond" "Clue geode (beginner)" "Clue geode (easy)" "Clue geode (medium)" "Clue geode (hard)" "Clue geode (elite)"; do
      curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
        -d "{\"name\":\"$gem\",\"all\":true}" "$BASE/inventory/drop" > /dev/null
    done
    sleep 1
  fi

  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Iron rocks","action":"Mine"}' "$BASE/objects/interact" > /dev/null

  sleep 1.2

  if [ $((cycle % 400)) -eq 0 ]; then
    danger=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/npcs?maxDistance=10" | python3 -c "
import json,sys
d=json.load(sys.stdin)
names=[n['name'] for n in d['npcs'] if n.get('combatLevel',0) and n['combatLevel']>20]
print(','.join(names))
" 2>/dev/null)
    if [ -n "$danger" ]; then
      echo "DANGER_NEARBY=$danger -- STOPPING for safety check"
      exit 2
    fi
    CYCLE=$cycle curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Mining" | CYCLE=$cycle python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: cycle={os.environ['CYCLE']} Mining_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
  fi
done
echo "MAX_CYCLES_REACHED"
