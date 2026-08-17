#!/bin/bash
# Kicks off a non-blocking walk to a target inside a dangerous area, then
# tightly polls (every ~1s) for damage and nearby high-level monsters,
# eating food immediately on any HP loss and retreating immediately if a
# named danger NPC comes within range. Written for the Asgarnian Ice
# Dungeon blurite ore run (The Knight's Sword quest) but generalizes to any
# "sneak in, grab the thing, get out" situation.
#
# Two prior blind attempts at this (a single long blocking /walk call with
# no monitoring) resulted in character deaths -- the eat-on-damage +
# instant-retreat pattern here is what got through safely on the third try.
#
# Usage: dungeon_safe_approach.sh <target_x> <target_y> <plane> <retreat_x> <retreat_y> <danger_npc_name> [danger_radius] [food_item_name]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TX=$1; TY=$2; PL=${3:-0}
RX=$4; RY=$5
DANGER_NAME=${6:-}
DANGER_RADIUS=${7:-15}
FOOD=${8:-Lobster}

if [ -z "$TX" ] || [ -z "$RX" ]; then
  echo "Usage: dungeon_safe_approach.sh <target_x> <target_y> <plane> <retreat_x> <retreat_y> <danger_npc_name> [danger_radius] [food_item_name]"
  exit 1
fi

LASTHP=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
echo "starting hp=$LASTHP"

curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"x\":$TX,\"y\":$TY,\"plane\":$PL,\"wait\":false}" "$BASE/walk" > /dev/null

for i in $(seq 1 400); do
  hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
  pos=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; p=json.load(sys.stdin)['player']['position']; print(p['x'],p['y'],p['plane'])" 2>/dev/null)

  if [ -n "$hp" ] && [ -n "$LASTHP" ] && [ "$hp" -lt "$LASTHP" ] 2>/dev/null; then
    echo "[$i] DAMAGE hp=$hp (was $LASTHP) pos=$pos -- EATING"
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"name\":\"$FOOD\",\"action\":\"Eat\"}" "$BASE/inventory/interact" > /dev/null
  fi
  if [ -n "$hp" ]; then LASTHP=$hp; fi

  if [ -n "$hp" ] && [ "$hp" -le 4 ] 2>/dev/null; then
    echo "[$i] CRITICAL hp=$hp pos=$pos -- RETREATING"
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"x\":$RX,\"y\":$RY,\"plane\":$PL,\"wait\":false}" "$BASE/walk" > /dev/null
    echo "RETREAT_TRIGGERED"
    exit 3
  fi

  if [ -n "$DANGER_NAME" ]; then
    danger=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/npcs?maxDistance=$DANGER_RADIUS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
names=[n['name'] for n in d['npcs'] if n.get('name') and '$DANGER_NAME'.lower() in n['name'].lower()]
print(','.join(names))
" 2>/dev/null)
    if [ -n "$danger" ]; then
      echo "[$i] DANGER=$danger pos=$pos hp=$hp -- RETREATING"
      curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
        -d "{\"x\":$RX,\"y\":$RY,\"plane\":$PL,\"wait\":false}" "$BASE/walk" > /dev/null
      echo "RETREAT_TRIGGERED"
      exit 2
    fi
  fi

  x=$(echo $pos | cut -d' ' -f1); y=$(echo $pos | cut -d' ' -f2)
  if [ -n "$x" ]; then
    dist2=$(( (x-TX)*(x-TX) + (y-TY)*(y-TY) ))
    if [ "$dist2" -lt 16 ]; then
      echo "[$i] ARRIVED pos=$pos hp=$hp"
      exit 0
    fi
  fi

  if [ $((i % 10)) -eq 0 ]; then
    echo "[$i] pos=$pos hp=$hp (still traveling)"
  fi

  sleep 1
done
echo "TIMEOUT"
exit 1
