#!/bin/bash
# Repeatedly casts Wind Strike (spellbook group 218, childId 11) on nearby
# chickens for safe combat/magic training. Requires Air runes (or a Staff of
# Air equipped) and Mind runes in inventory, and being near a chicken pen.
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"

kills=0
for cycle in $(seq 1 500); do
  count=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/npcs?name=Chicken&maxDistance=20" | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])" 2>/dev/null)
  if [ "$count" = "0" ] || [ -z "$count" ]; then
    echo "no chickens nearby, waiting"
    sleep 3
    continue
  fi

  # select Wind Strike
  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{"groupId":218,"childId":11}' "$BASE/widgets/click" > /dev/null
  sleep 0.6

  # cast on nearest chicken
  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Chicken","action":"Cast"}' "$BASE/npcs/interact" > /dev/null

  for t in $(seq 1 15); do
    sleep 1.5
    hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
    interacting=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; print(json.load(sys.stdin)['player']['interacting'])" 2>/dev/null)
    if [ -n "$hp" ] && [ "$hp" -le 6 ] 2>/dev/null; then
      echo "UNEXPECTED_DAMAGE hp=$hp -- ABORTING GRIND"
      exit 1
    fi
    if [ "$interacting" = "False" ]; then
      break
    fi
  done

  kills=$((kills+1))
  if [ $((kills % 5)) -eq 0 ]; then
    curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills" > /tmp/chicken_train_skills.json
    KILLS=$kills python3 -c "
import json, os
d = json.load(open('/tmp/chicken_train_skills.json'))
m = {s['name']: s['level'] for s in d['skills']}
print(f\"kills={os.environ['KILLS']} Att={m['Attack']} Str={m['Strength']} Def={m['Defence']} HP={m['Hitpoints']} Mag={m['Magic']}\")
"
  fi
  sleep 0.8
done
echo "GRIND_COMPLETE kills=$kills"
