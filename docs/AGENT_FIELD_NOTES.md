# Agent Field Notes

Practical gotchas learned from actually running long, unattended sessions
against the Agent Server (quests, training grinds, GE trading). This is
**not** a replacement for [AGENT_SERVER.md](AGENT_SERVER.md) (HTTP API
reference) or [AGENT_SCRIPT_TOOLS.md](AGENT_SCRIPT_TOOLS.md) (dev-tool
index) — read those first. This doc is the stuff that isn't obvious from
the API surface itself and will otherwise cost you an hour of confused
debugging.

## `success: true` does not mean the action happened

`POST /objects/interact` (and object clicks in general) call into
`Rs2TileObjectModel.click()`, which returns `true` unless an exception is
thrown — it does **not** confirm the client-side menu action actually
fired or that the game accepted it. A `"success": true` response only
means "we queued a click," not "the chop/mine/dialogue happened."

**Always verify via a state delta**, not the response body:
- Skill training: poll `/skills` and confirm XP increased.
- Movement/object use: poll `/state` position or `/inventory` for the
  expected item.
- If XP/inventory is flat for several cycles despite `success: true`,
  the object probably wasn't actually reachable/clickable — check
  `/objects?name=...` for `"reachable": true` and re-verify position.

## Nearest-by-name object selection can pick the wrong instance

When several objects share a name (e.g., four "Gap" tiles on a rooftop
Agility course, or a GE buy/sell icon that's really two overlapping
clickable icons), nearest-by-straight-line-distance is not the same as
"the correct next one." A used/already-passed obstacle can be
geometrically closer than the actual next tile in a course, causing a
loop (agent walks back and forth forever).

**Fix:** once you've identified the ambiguity, pin to explicit object
IDs (`{"id": N, "action": "..."}`) instead of `{"name": "..."}`. Object
IDs are stable for the life of a game session (not necessarily across
game updates). See `scripts/automation/agility_rooftop_varrock.sh` for
a worked example, including a comment explaining why.

## Ambiguous multi-action widgets (e.g. GE buy/sell icons)

Some widgets pack multiple actions onto a single clickable tile (the
Grand Exchange offer slots are the classic case: one icon area handles
both "Buy" and "Collect", disambiguated only by sub-widget or menu
index). `POST /widgets/click` fires the default action; when you need a
*specific* one, use `POST /widgets/invoke` with `param0` (targets a
sub-widget/child index) and/or `identifier` (targets a specific menu
action by index) instead. `widgets describe <groupId> <childId> --depth N`
is the fastest way to find the right group/child/param0 before you
script anything.

## Grand Exchange automation flow

Buying via the API is: open GE → click empty buy slot widget → search
(sets a text-input widget then confirms) → click the matching item
result → adjust price/quantity via the offer widget → confirm → wait →
collect. There's no single "buy item" endpoint — expect ~6 widget
interactions per purchase. Verify the purchase landed by checking
`/inventory` afterward, not just the confirm click's response (see
first section above).

## Death recovery (gravestone / Death's Office)

If the character dies, items are reclaimed via the "Death's Domain"
scenery object → dialogue with Death. The dialogue must be **fully
exhausted** — every topic selected at least once — before Death allows
you to leave with your items for free. `GET /dialogue` returns option
text as HTML; already-visited topics show up wrapped in `<str>`
(strikethrough) tags. Keep selecting non-strikethrough options until
none remain, then take the "leave" option.

## The 6-hour logout timer + members-world pinning

Long-running sessions get force-logged-out roughly every 6 hours.
`scripts/automation/relogin_recovery.sh` is the shared pattern: poll
`/state` for `loggedIn`, and if false, log back in **pinned to a
members world** (`{"world": N, ...}` on `POST /login`), not just "any
world." If you let the client pick a default world while your character
is standing in members-only territory, you can get bounced with a
"you need to log into a members world" prompt and end up stuck. After
login, click through the welcome/play screen (`groupId 378`, childId
`72` then `76` — layout varies, click both defensively) and, if the
character logged back in far from where it needs to be, walk back.

## Power-training pattern (no banking)

For repetitive resource-gathering grinds (power-mining, power-chopping),
don't bank — drop the primary resource plus incidental byproducts
(gems, clue scroll geodes, bird nests, tree leaves) on a full inventory
and keep going. Check `/inventory` for `"full": true`, then
`POST /inventory/drop` with `{"name": "...", "all": true}` per item
type before resuming the gather action. This is dramatically faster
than round-tripping to a bank for low-value early-game resources.

## Safe navigation through dangerous areas

For any walk through monster territory (quest dungeons, wilderness-
adjacent areas), don't blind-walk and hope. Use a non-blocking walk plus
a tight polling loop (~1s) that:
- eats food the instant HP drops at all (not at a threshold — any drop),
- retreats immediately if HP falls at/below a hard floor, **or** a
  named danger NPC comes within some radius (`GET /npcs?name-contains=X`),
  whichever fires first.

See `scripts/automation/dungeon_safe_approach.sh`. This was built after
two blind-walk attempts got the character killed; it worked cleanly on
the first retry. Two deaths were fully recoverable for free via the
Death's Office flow above, but don't rely on that — HP/gear loss timing
during a fight is not something worth testing repeatedly.

## Non-obvious widget/menu locations

- The in-game World Map opens via `widgets click 160 55`. The visually
  similar-looking `548 55` opens the Grouping/clan-chat panel instead —
  easy to confuse if you're guessing from a screenshot.
- Minigame teleports (Magic spellbook) are at `groupId 218, childId 7`.
  These are useful as an F2P-excluded fast route onto certain
  members-only islands (e.g. Soul Wars → Isle of Souls) without a boat
  or long walk.
- Spell-casting on an NPC is two calls: select the spell widget first
  (`groupId 218, childId 11` for the spellbook), then
  `POST /npcs/interact` with `{"name": "...", "action": "Cast"}`.

## Pathfinding: long single-hop walks can silently fail or truncate

`POST /walk` to a coordinate that's genuinely reachable can still return
`UNREACHABLE`, or "succeed" but stop partway, if the true path requires
a long detour (e.g. around a coastline/peninsula) that the walker's
search doesn't find in one hop. If a direct walk to a known-good
destination fails, don't assume the destination is wrong — break the
route into 2–4 intermediate waypoints in the general direction and walk
each leg with `--wait`. This resolved an "unreachable" teak tree grove
that was in fact only ~100 tiles away in a straight line but required
routing around the west side of an island.

Relatedly: `GET /objects?name=X&maxDistance=N` only returns objects in
the client's **currently loaded scene**, regardless of how large `N`
is. A large `maxDistance` does not mean the object will show up if the
region containing it hasn't been loaded yet by walking close enough —
"0 results even at maxDistance=150" can just mean "not loaded here,"
not "not present anywhere within 150 tiles."

## Finding exact object/resource coordinates

The OSRS Wiki's rendered pages (and `WebFetch`'s HTML→markdown
conversion) strip out the coordinate data actually backing their maps.
Instead, fetch the **raw wikitext**:

```
https://oldschool.runescape.wiki/index.php?title=<Page_Title>&action=raw
```

and look for `{{ObjectLocLine|...}}` / `{{Mapclick|...}}` templates —
these carry literal `x,y` (and `plane`, `mapID`) game coordinates, e.g.
`|2185,2988|2185,2990|2187,2992`. This is far more reliable than prose
like "near the north coast."

## Shell/awk portability

This box's `awk` is `mawk`, which does **not** support gawk's 3-argument
`match(str, regex, arr)` capture-group form. If you're writing a
`Monitor` filter or any awk snippet, stick to 2-arg `match(str, regex)`
+ `RSTART`/`RLENGTH` + `substr()`, or use `grep -oE` / `python3 -c`
instead. A gawk-only script will fail with a bare `syntax error at or
near ,` and no other hint.

## Script conventions in this repo

- Long-running training/farming loops live in `scripts/automation/`,
  one self-contained bash script per skill/spot, named for what they
  do (`mining_powermine_iron.sh`, not `script3.sh`).
- Every training script polls `/skills` for a target level and exits
  with `TARGET_REACHED` on success; most print periodic `progress:`
  lines. Keep this convention — it's what makes a script pollable by a
  `Monitor` filter without spamming (see the note below).
- Shared helpers (`relogin_recovery.sh`, `dialogue_advance.sh`,
  `dungeon_safe_approach.sh`) take their target position/NPC/etc. as
  arguments rather than being hardcoded, so they're reusable across
  spots.
- **Commit and push new/changed scripts as you go**, not just at the
  end of a session — these are meant to accumulate as a reusable
  library for future runs, and a crash/rate-limit mid-session
  shouldn't lose work that already proved out.
- If you wrap a long grind in a `Monitor`, filter to level-ups and
  terminal/error states only (`TARGET_REACHED|LOW_HP|DISCONNECTED|
  MAX_CYCLES_REACHED`), not every `progress:` line — a grind from
  level 35 to 70 can run for tens of thousands of cycles, and a
  notification every ~90 seconds for hours defeats the point of
  backgrounding it.
