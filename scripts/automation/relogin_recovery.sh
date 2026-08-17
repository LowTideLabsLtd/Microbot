#!/bin/bash
# Checks Agent Server login state; if disconnected, logs back in on a pinned
# world and clicks through the welcome/play screen. Optionally walks back to
# a known position afterward (useful when the training spot is members-only
# territory, since an unpinned login can land on a free world and get
# bounced with "log into a members world").
#
# Usage: relogin_recovery.sh [world] [walk_back_x] [walk_back_y] [walk_back_plane]
#   world            world to log into (default 535, a members world)
#   walk_back_x/y/plane   optional destination to walk back to after login;
#                         omit all three to skip the walk-back step
TOKEN=$(cat ~/.runelite/.agent-token)
BASE="http://127.0.0.1:8081"
WORLD=${1:-535}
WALK_X=$2
WALK_Y=$3
WALK_PLANE=${4:-0}

state=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state")
logged_in=$(echo "$state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('loggedIn', False))" 2>/dev/null)

if [ "$logged_in" = "True" ]; then
  exit 0
fi

echo "DISCONNECTED -- attempting recovery"

curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"world\":$WORLD,\"wait\":true,\"timeout\":60}" "$BASE/login" > /dev/null
sleep 3

# click through welcome/play screen if present (child 72 or 76 = Play, layout varies)
curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
  -d '{"groupId":378,"childId":72}' "$BASE/widgets/click" > /dev/null
sleep 2
curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
  -d '{"groupId":378,"childId":76}' "$BASE/widgets/click" > /dev/null
sleep 3

logged_in2=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; print(json.load(sys.stdin).get('loggedIn', False))" 2>/dev/null)
echo "post-recovery logged_in=$logged_in2"

if [ "$logged_in2" != "True" ] || [ -z "$WALK_X" ]; then
  exit 0
fi

pos=$(curl -s -H "X-Agent-Token: $TOKEN" "$BASE/state" | python3 -c "import json,sys; p=json.load(sys.stdin)['player']['position']; print(p['x'],p['y'])" 2>/dev/null)
x=$(echo $pos | cut -d' ' -f1); y=$(echo $pos | cut -d' ' -f2)
if [ -n "$x" ]; then
  dist2=$(( (x-WALK_X)*(x-WALK_X) + (y-WALK_Y)*(y-WALK_Y) ))
  if [ "$dist2" -gt 400 ]; then
    echo "walking back to ($WALK_X,$WALK_Y,$WALK_PLANE) from ($x,$y)"
    curl -s -X POST -H "X-Agent-Token: $TOKEN" -H "Content-Type: application/json" \
      -d "{\"x\":$WALK_X,\"y\":$WALK_Y,\"plane\":$WALK_PLANE,\"wait\":true,\"timeout\":60}" "$BASE/walk" > /dev/null
  fi
fi

echo "RECOVERY_COMPLETE"
exit 0
