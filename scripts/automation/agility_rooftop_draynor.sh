#!/bin/bash
# Loops the Draynor Village rooftop agility course (no level requirement,
# ~10k xp/hr as a beginner). Start position: (3103,3278,0), just south of
# the rough wall.
#
# Sequence: Rough wall(Climb) -> Tightrope(Cross) x2 -> Narrow wall
#           (Squeeze-through) -> Wall(Climb) -> Gap(Jump) -> Crate(Jump-Into)
#
# Usage: agility_rooftop_draynor.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-20}

do_obstacle() {
  name="$1"; action="$2"
  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d "{\"name\":\"$name\",\"action\":\"$action\"}" "$BASE/objects/interact" > /dev/null
  sleep 0.8
  # wait until movement/animation settles (max ~8s), so we don't fire the next
  # click mid-traversal and miss the obstacle
  for i in $(seq 1 16); do
    moving=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; p=json.load(sys.stdin)['player']; print(p['moving'] or p['animating'])" 2>/dev/null)
    if [ "$moving" != "True" ]; then break; fi
    sleep 0.5
  done
  sleep 0.4
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

  do_obstacle "Rough wall" "Climb"
  do_obstacle "Tightrope" "Cross"
  do_obstacle "Tightrope" "Cross"
  do_obstacle "Narrow wall" "Squeeze-through"
  do_obstacle "Wall" "Climb"
  do_obstacle "Gap" "Jump"
  do_obstacle "Crate" "Jump-Into"

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
