#!/bin/bash
# Advances an open NPC dialogue by clicking "continue" until it ends or
# hits a "select an option" prompt (at which point it stops and prints the
# options for a human/caller to pick from).
#
# Usage: dialogue_advance.sh [max_steps]
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
max=${1:-25}

for i in $(seq 1 "$max"); do
  d=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/dialogue")
  inD=$(echo "$d" | python3 -c "import json,sys; print(json.load(sys.stdin).get('inDialogue', False))" 2>/dev/null)
  if [ "$inD" != "True" ]; then
    echo "$d"
    exit 0
  fi
  hasOpt=$(echo "$d" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hasOptions', False))" 2>/dev/null)
  if [ "$hasOpt" = "True" ]; then
    echo "$d"
    exit 0
  fi
  curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
    -d '{}' "$BASE/dialogue/continue" > /dev/null
  sleep 1.3
done
echo "$d"
