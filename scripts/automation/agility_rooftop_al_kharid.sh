#!/bin/bash
# Loops the Al Kharid rooftop agility course (requires level 20). Start
# position: (3273,3196,0), at the rough wall north side of Ellis the
# Tanner's building.
#
# Sequence: Rough wall(Climb) -> Tightrope(Cross) -> Cable(Zip-line) ->
#           Zip line(Grab) -> Tropical tree(Climb) -> Roof top beams
#           (Balance) -> Tightrope(Balance) -> Gap(Jump)
# Failure-prone obstacles: Tightrope (Cross) and Zip line (Grab) can fail
# for 1-5 damage; otherwise safe.
#
# Usage: agility_rooftop_al_kharid.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-30}

get_xp() {
  curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Agility" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['xp'])" 2>/dev/null
}

do_obstacle() {
  name="$1"; action="$2"
  before=$(get_xp)
  for attempt in 1 2 3; do
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"name\":\"$name\",\"action\":\"$action\"}" "$BASE/objects/interact" > /dev/null
    sleep 1
    for i in $(seq 1 14); do
      moving=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; p=json.load(sys.stdin)['player']; print(p['moving'] or p['animating'])" 2>/dev/null)
      if [ "$moving" != "True" ]; then break; fi
      sleep 0.5
    done
    sleep 0.4
    after=$(get_xp)
    if [ -n "$before" ] && [ -n "$after" ] && [ "$after" != "$before" ]; then
      return 0
    fi
  done
}

laps=0
for cycle in $(seq 1 3000); do
  lvl=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Agility" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['level'])" 2>/dev/null)
  if [ -n "$lvl" ] && [ "$lvl" -ge "$TARGET" ] 2>/dev/null; then
    echo "TARGET_REACHED agility_level=$lvl"
    exit 0
  fi

  if [ $((cycle % 5)) -eq 0 ]; then
    "$DIR/relogin_recovery.sh"
  fi

  hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
  if [ -n "$hp" ] && [ "$hp" -le 4 ] 2>/dev/null; then
    echo "LOW_HP hp=$hp -- STOPPING for safety"
    exit 3
  fi

  do_obstacle "Rough wall" "Climb"
  do_obstacle "Tightrope" "Cross"
  do_obstacle "Cable" "Zip-line"
  do_obstacle "Zip line" "Grab"
  do_obstacle "Tropical tree" "Climb"
  do_obstacle "Roof top beams" "Balance"
  do_obstacle "Tightrope" "Balance"
  do_obstacle "Gap" "Jump"

  laps=$((laps+1))
  if [ $((laps % 3)) -eq 0 ]; then
    LAPS=$laps curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Agility" | LAPS=$laps python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: laps={os.environ['LAPS']} Agility_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
  fi
done
echo "MAX_CYCLES_REACHED"
