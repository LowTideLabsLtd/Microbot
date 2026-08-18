#!/bin/bash
# Trains Magic (and passively Hitpoints, via combat XP) by autocasting a
# combat spell at cows in the Lumbridge cow field until a target Magic
# level is reached. Assumes autocast is already set on the desired spell
# (e.g. Fire Strike) and a fire-providing staff is equipped, so only Air
# runes are consumed per cast. Cows are zero-threat, so this is a pure
# unattended grind -- no HP safety stop needed, but one is included anyway
# for consistency with the other training scripts.
#
# Usage: magic_train_firestrike_cows.sh [target_level]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
TARGET=${1:-99}

for cycle in $(seq 1 50000); do
	if [ $((cycle % 15)) -eq 0 ]; then
		"$DIR/relogin_recovery.sh" 535 3253 3269 0
	fi

	lvl=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Magic" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['level'])" 2>/dev/null)
	if [ -n "$lvl" ] && [ "$lvl" -ge "$TARGET" ] 2>/dev/null; then
		echo "TARGET_REACHED magic_level=$lvl"
		exit 0
	fi

	hp=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Hitpoints" | python3 -c "import json,sys; print(json.load(sys.stdin)['skills'][0]['boostedLevel'])" 2>/dev/null)
	if [ -n "$hp" ] && [ "$hp" -le 3 ] 2>/dev/null; then
		echo "LOW_HP hp=$hp -- STOPPING for safety"
		exit 1
	fi

	interacting=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; print(json.load(sys.stdin)['player']['interacting'])" 2>/dev/null)
	if [ "$interacting" != "True" ]; then
		curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
			-d '{"name":"Cow","action":"Attack"}' "$BASE/npcs/interact" >/dev/null
	fi

	sleep 2

	if [ $((cycle % 30)) -eq 0 ]; then
		CYCLE=$cycle curl -s -H "X-Agent-Token: $TOKEN" "$BASE/skills?name=Magic" | CYCLE=$cycle python3 -c "
import json, sys, os
d = json.load(sys.stdin)
s = d['skills'][0]
print(f\"progress: cycle={os.environ['CYCLE']} Magic_level={s['level']} xp={s['xp']}\")
" 2>/dev/null
	fi
done
echo "MAX_CYCLES_REACHED"
