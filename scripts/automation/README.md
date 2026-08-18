# Agent Server automation scripts

Bash scripts that drive a live game session through the [Agent Server](../../docs/AGENT_SERVER.md)
HTTP API (`http://127.0.0.1:8081`, token at `~/.runelite/.agent-token`). Each
one is a self-contained training/farming loop for a specific skill or spot,
built by manually mapping the target area once (learning obstacle names,
object IDs, and action verbs) and then automating the repeatable sequence.

All scripts poll `GET /skills` for a target level and exit cleanly with
`TARGET_REACHED` once hit. Most also print periodic `progress:` lines so a
caller can watch them via the CLI or `curl`.

## Scripts

- `relogin_recovery.sh` -- shared helper: detects a disconnect, logs back in
  on a pinned world, clicks through the welcome/play screen, and optionally
  walks back to a known position. Called periodically by the other scripts.
- `mining_train_copper.sh` -- Mining 1→N on Copper rocks at the East
  Lumbridge Swamp mine (safe, no monsters).
- `mining_powermine_iron.sh` -- Mining N→70 power-mining Iron at the Isle of
  Souls mine (members-only, safe). Drops ore and gems on a full inventory.
- `woodcutting_train_trees.sh` -- Woodcutting 1→15 on regular trees around
  Lumbridge. Drops logs on a full inventory.
- `woodcutting_train_oaks.sh` -- Woodcutting 15→35 on oak trees around
  Lumbridge. Drops oak logs on a full inventory.
- `woodcutting_train_teaks.sh` -- Woodcutting 35→70 power-chopping teak trees
  on the Isle of Souls (members-only, safe, reached via the Soul Wars
  minigame teleport). Drops teak logs on a full inventory.
- `combat_train_chickens_melee.sh` / `combat_train_chickens_magic.sh` --
  zero-risk combat/Magic training on Lumbridge chickens.
- `agility_rooftop_draynor.sh` / `agility_rooftop_al_kharid.sh` /
  `agility_rooftop_varrock.sh` -- rooftop Agility course loops, in
  progression order (Draynor 1 → Al Kharid 20 → Varrock 30 → ...).
- `dungeon_safe_approach.sh` -- generic "sneak in, grab the thing, get out"
  pattern: non-blocking walk with tight HP/danger polling, eats food on any
  damage, retreats instantly if a named monster comes into range. Built for
  the Asgarnian Ice Dungeon blurite ore run (The Knight's Sword quest)
  after two blind attempts got the character killed.
- `dialogue_advance.sh` -- clicks through NPC dialogue until it ends or
  hits a "select an option" prompt.
- `prayer_chaos_altar_offer.sh` -- offers all Dragon bones in inventory on
  the Wilderness Chaos Altar (level 38 Wilderness, reached via Burning
  amulet -> Lava Maze) for 3.5x Prayer XP with a ~50% bone-preservation
  chance. One inventory-load only; travel/banking/return are handled
  separately (see docs/AGENT_FIELD_NOTES.md for the route).
- `magic_train_firestrike_cows.sh` -- trains Magic (and passively
  Hitpoints via combat XP) by autocasting a combat spell at Lumbridge
  cow-field cows. Assumes autocast and a fire-providing staff are
  already set up so only Air runes are consumed. Zero-threat target.

## Notes

- The rooftop course scripts assume the character is already standing at
  (or can reach) the course's starting rough wall.
- `agility_rooftop_varrock.sh` hardcodes object IDs for the four "Gap"
  obstacles rather than picking nearest-by-name -- see the comment at the
  top of that file for why.
- These were written and iterated on interactively; object IDs, XP values,
  and timings are only as good as this session's observations and may need
  re-verification after a game update.
