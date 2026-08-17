#!/bin/bash
# Loops the Varrock rooftop agility course (requires level 30). Start
# position: (3221,3413,0), at the rough wall east side of the General Store.
#
# Sequence: Rough wall(Climb) -> Clothes line(Cross) -> Gap#1(Jump) ->
#           Wall(Balance) -> Gap#2(Jump) -> Gap#3(Jump) -> Gap#4(Jump) ->
#           Ledge(Jump) -> Edge(Jump)
# Failure-prone obstacles: Clothes line (Cross) and Wall (Balance) can fail
# for a few points of damage; otherwise safe.
#
# There are four separate "Gap" tiles on this course. Picking the nearest
# object by name alone is ambiguous once you're standing near an
# already-used gap (straight-line distance favors it over the next one,
# even though it's no longer a valid path forward) -- so this script uses
# the explicit object IDs for each Gap/Ledge/Edge step, which are stable
# within a game session. If RuneLite ever renumbers these (e.g. after a
# game update), re-derive them once by walking the course manually and
# querying GET /objects?name=Gap from each landing spot.
#
# Usage: agility_rooftop_varrock.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-50}
START_X=3221
START_Y=3413

GAP1_ID=14414   # (3200,3416) - right after Clothes line
GAP2_ID=14833   # (3193,3401) - right after Wall
GAP3_ID=14834   # (3209,3397)
GAP4_ID=14835   # (3233,3402)
LEDGE_ID=14836  # (3236,3409)
EDGE_ID=14841   # (3236,3416) - final, biggest xp obstacle

get_xp() {
  curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Agility" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['xp'])" 2>/dev/null
}

wait_settle() {
  for i in $(seq 1 14); do
    moving=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; p=json.load(sys.stdin)['player']; print(p['moving'] or p['animating'])" 2>/dev/null)
    if [ "$moving" != "True" ]; then break; fi
    sleep 0.5
  done
  sleep 0.3
}

do_obstacle_name() {
  name="$1"; action="$2"
  before=$(get_xp)
  for attempt in 1 2 3; do
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"name\":\"$name\",\"action\":\"$action\"}" "$BASE/objects/interact" > /dev/null
    sleep 1
    wait_settle
    after=$(get_xp)
    if [ -n "$before" ] && [ -n "$after" ] && [ "$after" != "$before" ]; then
      return 0
    fi
  done
}

do_obstacle_id() {
  id="$1"; action="$2"
  before=$(get_xp)
  for attempt in 1 2 3; do
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"id\":$id,\"action\":\"$action\"}" "$BASE/objects/interact" > /dev/null
    sleep 1
    wait_settle
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
    "$DIR/relogin_recovery.sh" 535 "$START_X" "$START_Y" 0
  fi

  hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
  if [ -n "$hp" ] && [ "$hp" -le 4 ] 2>/dev/null; then
    echo "LOW_HP hp=$hp -- STOPPING for safety"
    exit 3
  fi

  do_obstacle_name "Rough wall" "Climb"
  do_obstacle_name "Clothes line" "Cross"
  do_obstacle_id "$GAP1_ID" "Jump"
  do_obstacle_name "Wall" "Balance"
  do_obstacle_id "$GAP2_ID" "Jump"
  do_obstacle_id "$GAP3_ID" "Jump"
  do_obstacle_id "$GAP4_ID" "Jump"
  do_obstacle_id "$LEDGE_ID" "Jump"
  do_obstacle_id "$EDGE_ID" "Jump"

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
