#!/bin/bash
# Offers all Dragon bones in inventory on the Wilderness Chaos Altar (object
# id 411, level 38 Wilderness) for 3.5x Prayer XP with a ~50% chance each
# bone isn't consumed. Loops until the inventory has none left (accounting
# for preserved bones), printing XP progress. Assumes the character is
# already standing next to the altar (reached via Burning amulet -> Lava
# Maze, then a short walk southwest -- see docs/AGENT_FIELD_NOTES.md for the
# route and why the direct walk to the altar tile itself is unreachable).
#
# This does NOT handle travel, banking, or the return trip -- it's just the
# offering loop, meant to be called once per inventory-load of bones.
#
# Usage: prayer_chaos_altar_offer.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
ALTAR_ID=411

for cycle in $(seq 1 200); do
	count=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/inventory" |
		python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(i['quantity'] for i in d['items'] if i['name']=='Dragon bones'))" 2>/dev/null)

	if [ -z "$count" ] || [ "$count" -eq 0 ] 2>/dev/null; then
		echo "BONES_DEPLETED"
		exit 0
	fi

	hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
	if [ -n "$hp" ] && [ "$hp" -le 3 ] 2>/dev/null; then
		echo "LOW_HP hp=$hp -- STOPPING for safety"
		exit 1
	fi

	curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
		-d "{\"item\":\"Dragon bones\",\"objectId\":$ALTAR_ID}" "$BASE/inventory/use-on-object" >/dev/null

	sleep 2

	CYCLE=$cycle BONES=$count curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Prayer" | CYCLE=$cycle BONES=$count python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: cycle={os.environ['CYCLE']} bones_left={os.environ['BONES']} Prayer_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
done
echo "MAX_CYCLES_REACHED"
