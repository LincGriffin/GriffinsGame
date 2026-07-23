# GriffinsGame — Design & Roadmap

> A living design document. It captures where the game is headed and the order we'll build it in.
> Gameplay is implemented feature-by-feature through the usual one-PR-at-a-time flow (see
> `CLAUDE.md`); this doc is the north star those PRs aim at. Sections marked *default* or *flagged*
> are open decisions — see [Open questions](#open-questions--decisions-to-lock).

## Where we are today

- A **single tile room** (`scripts/overworld.gd`) painted from an ASCII map; grid-authoritative
  tile-by-tile movement (`scripts/player.gd`).
- A **single "Hero"** who fights **one enemy at a time** in a turn-based overlay
  (`scripts/battle.gd`), with Attack / Defend / Flee.
- Data-driven enemies (`EnemyData` + `tools/gen_content.gd`) and a `GameState` autoload that
  carries HP between fights and levels the Hero via XP.

## Where we're going

A **roguelike monster-collector dungeon crawler**: traverse a branching map of possible paths,
auto-recruit the monsters you defeat, and battle with a **party of monsters** where **one is active
at a time**. You begin each run by **choosing one of three weaker starter monsters**. There is **no
"Hero" unit** — every fighter is a monster. Progression is collection-driven (no XP/levels), runs
are disposable (nothing persists between them), and the whole game is restyled into a bright,
translucent **Magna-Tiles** look.

---

## Vision & core loop

Each **run**:

1. You **choose one of three weaker starter monsters** (drawn from the common wild monsters found
   in a run). That lone monster is your starting party.
2. You navigate a **branching node-map** — pick a path through a series of nodes; branches fork
   and reconnect; the final node is the **Hydra** boss. *(The Griffin — the game's namesake — is now
   a fearsome **elite** guardian rather than the final boss.)*
3. Most nodes are **battles**. Battles are one-monster-vs-one-monster. Win a wild battle → the
   defeated monster is **auto-recruited** into your party.
4. Other nodes **heal**, grant a **static power-up**, or **teleport** you elsewhere on the map.
5. **HP persists** between battles. A downed monster is **gone for the rest of the run**
   (permadeath). **When you have no monsters left to fight, the run ends** — that is the only way
   to lose.
6. Reach and defeat the **Hydra** → you win the run. Lose your last monster → the run is over and
   a **fresh run** begins (nothing carries over).

Power comes from **which monsters you've collected** and **how you spend their HP across a run**,
plus the **power-ups** you pick up — never from grinding. *(Early runs are fragile: a single
starter means losing your first fight ends the run, so collecting a second monster quickly is the
first goal.)*

## Battle system

- **One active monster at a time** on your side.
- At the **start of each battle you choose which of your living monsters leads.**
- When the **active monster is defeated** (HP 0): it is **permanently lost for the run**, and you
  **switch in** another living monster to continue.
- When **no living monster remains** to switch in, the run ends. **This party wipe is the only lose
  condition** — there is no Hero or separate life-total unit.
- **Enemy side stays single** — one enemy per battle; the boss is solo. Multi-enemy battles are out
  of scope for now.
- **HP is per-monster and persists** across battles within a run (classic attrition).
- **No fleeing the boss**; fleeing a wild battle returns you to the map without recruiting.

This reuses the existing `Combatant` and its pure, static `compute_damage`. Every combatant — yours
and the enemy's — is built from the same `MonsterData`, so there is no special-case build path. The
turn state machine gains a *choose-lead* step and a *switch-on-death* transition.

## Monsters & collection

- **Run start:** you pick **one of three** weaker starter monsters, drawn from the common wild pool.
- **Auto-recruit on victory:** beating a wild (non-boss) monster adds it to your party. The
  defeated enemy *literally becomes* a party member — the same data type describes both.
- **Collection cap:** 5 (*default, tunable*). When full, replace a member or skip — and, in a
  later phase, **merge** two monsters into one (see below).
- **Monsters are fixed-stat** — they have their own HP and moves but **do not level up**. You grow
  stronger by collecting better monsters and grabbing power-ups, not by grinding.
- **No XP, no levels.** Today's `GameState` XP/level system is retired.

### Portraits (Phase 9)

Each monster can have a **portrait** — `assets/portraits/<id>.png`, **256×256**, in a **classic
D&D monster-manual** illustration style. Portraits are **author-supplied** (the tile art is
generated, but bestiary illustration isn't something we can synthesise in-repo).

- Shown on the **starter-select cards**, as the **battle enemy art** (the monster's `tint` block
  becomes an 8px frame around the picture), and as **thumbnails on the lead/switch buttons**.
- **Optional by design:** a monster with no file falls back to its flat `tint` colour, so the game
  runs with none, some, or all of them present. Art can be added one monster at a time.
- Looked up **by convention at runtime** (`scripts/data/portraits.gd`), so adding art needs no
  generator re-run and no data edit — drop the PNG in and `--import`.

See `assets/portraits/README.md` for the spec and the id list.

### Monster merging (later phase)

With fixed-stat monsters and no XP, **merging** is the second collection-driven power lever (after
finding better monsters). When your party is **at the cap**, instead of only replace-or-skip you can
**merge two monsters into one** — freeing a slot and producing a monster with a **small bump to its
total stats** and a **new set of moves**. It rewards *filling* the roster rather than hoarding
duplicates, and stays consistent with "power comes from collection."

*Deferred to Phase 6 (`feat/monster-merge`); needs the party/cap system (Phase 1) and moves
(Phase 3).* Sub-questions to lock when built:

- How many combine (default **2 → 1**), and what sets the result's identity / name / appearance?
- Stat bump: flat vs percentage, and **capped** so it stays "small" (not the additive sum of both).
- New moves: **randomly rolled**, **blended** from the parents, or from a **fixed fusion table**?
- Available only at the cap, or anytime (e.g., a dedicated Merge/Rest node)?

## Moves (combat depth — a later phase)

- Each monster has a small set of **moves distinguished by effect, not element** (no type chart).
- Starter taxonomy (*tunable*): a reliable **Strike**, a high-power **Heavy hit**, a **Guard** (the
  old Defend), and a **Drain/Heal**. Unlimited use (no PP) for now.
- Moves are **data** (`MoveData` resources) so the roster and movesets stay editable in `tools/`.
- The battle command menu lists the **active monster's moves**, replacing the fixed
  Attack / Defend / Flee.

## The node-map (roguelike traversal)

- A run map is a **layered DAG** (Slay-the-Spire / FTL style): rows of nodes, edges to the next
  row, **branches that fork and reconnect**, boss at the top. **Procedurally generated each run.**
- **Traversal is a walkable dungeon (Phase 7):** each node is a **room** and each edge a **corridor**;
  you walk the map with the keyboard (`dungeon_view.gd`) instead of clicking nodes. The dungeon is
  fully open and **backtrackable** — you can reach every node if you like — and a node resolves when
  you **step into its room**. Each node type shows a distinct **marker prop**. *(The generator is
  unchanged; only the presentation changed. The old clickable `map_view.gd` is retired.)*

| Node | Effect |
|---|---|
| **Battle** (wild) | One-vs-one fight; win → auto-recruit. Most common. |
| **Heal** | Restore HP of your living party (no revive — permadeath). |
| **Power-up** (static) | A lasting boost: **+max HP** now; **a new move** once moves ship. |
| **Teleport** | Jump to a different node (skip ahead / cross to another branch). |
| **Treasure / Rest room** | Opens a small **walkable tile room** (hybrid, below) with a pickup. *Flagged.* |
| **Elite** | Tougher fight; win recruits the elite **and** full-heals the party. Gated to deeper rows. *(Phase 5.)* |
| **Boss** | The Hydra — final node; win = victory. |

**Hybrid rooms (superseded by Phase 7):** originally treasure/rest nodes opened a *separate* small
walkable room (`room.tscn`). Now that the **whole map is walkable**, the treasure node resolves in
place (a chest marker → party-wide +max HP); the standalone `room.tscn` is retained but unused.
Battle/boss/elite nodes open the battle overlay; heal/power-up/teleport/treasure resolve on the map.

## Progression & persistence

- **Within a run:** grow only via **collecting monsters** and **power-up nodes** (+max HP, later
  new moves). No XP, no levels.
- **Between runs:** **nothing persists** — pure roguelike. Death → fresh map, fresh starter choice.

## Art direction — Magna-Tiles (whole game)

Treatment: **translucent primary-color fills** (red / blue / green / yellow), **defined dark or
same-hue borders**, and a **soft inner glow / gradient** (lighter center → saturated edge) so tiles
read like backlit plastic. Applied consistently across:

- **Room tiles** — each tile type a primary color (floor / wall / special).
- **Map nodes & paths** — colored translucent node shapes; glowing connective paths.
- **Battle backdrop** — translucent color panels.
- **Your map token / room avatar & monster sprites** — translucent colored shapes. With no Hero,
  the walkable-room avatar is your **lead monster** (*default* — see open questions).

Produced by restyling `tools/gen_art.gd` (plus new map/monster art), using the same
headless-generator pattern already in `tools/`.

### Why the art is generated, not sourced (Phase 8)

We searched the usual free/CC0 sources for ready-made Magna-Tiles-style floor/wall tiles and
**found nothing that matches**, so the tiles stay procedural. What's out there:

- **Pixel-art dungeon tilesets** (e.g. [Dungeon Crawl 32x32](https://opengameart.org/content/dungeon-crawl-32x32-tiles),
  [32x32 Dungeon Tileset](https://opengameart.org/content/32x32-dungeon-tileset)) — opaque, grungy stone; the
  opposite of translucent plastic.
- **Kenney's** [Abstract Platformer](https://kenney.nl/assets/abstract-platformer) — bright flat geometry (closest in
  spirit) but **opaque** and built for side-view platformers, not top-down floor/wall.
- **"Glass" tilesets** on itch.io — glass *tubes/pipes* and letter tiles, not glass floor panels.

Useful finding from the research: the Magna-Tiles look is consistently described as **stained
glass** — a translucent, backlit panel inside a **beveled plastic frame**. Phase 8 rebuilt
`gen_art.gd` around exactly that (64px tiles: dark rim → beveled frame → inner lip → backlit glass
+ specular sheen, with faceted gem markers). Generated art also stays **license-clean, in-repo and
tunable**, which sourced assets would not.

*(If real assets are ever adopted, only `gen_art.gd`/`gen_tileset.gd` need to change — the atlas
indices and `walkable` custom data are the contract.)*

---

## Architecture: mapping the design onto existing code

| Existing | Becomes | Notes |
|---|---|---|
| `scripts/overworld.gd` (one room = the game) | **Split**: a reusable **Room** scene (paint + walk + trigger) *plus* a new top-level **Run/Map** controller | Room logic is reused wholesale for hybrid nodes; the walkable avatar becomes your lead monster (the current `player.gd` sprite is repurposed). |
| `scripts/battle.gd` (Hero vs one enemy) | **Party-aware battle**: choose-lead, switch-on-death, permadeath, moves menu; **no Hero build path** (all combatants come from `MonsterData`) | Keeps the state machine and `_say` pacing; adds a party/bench and a switch transition. |
| `scripts/battle/combatant.gd` | `+ moves: Array[MoveData]` | Pure `compute_damage` stays; a move feeds its power in. |
| `scripts/data/enemy_data.gd` (`EnemyData`) | **`MonsterData`** — one type shared by wild enemies *and* recruited allies; `+ moves[]`, `+ is_starter` (starter-pool flag), drop `xp_reward` | Rename touches `gen_content.gd`, `overworld.gd`, `battle.gd`, `test_battle.gd`, and the `.tres` files. |
| `autoload/game_state.gd` (`GameState`, XP/levels) | **`RunState`** — the party (chosen starter + everything recruited), each monster with current HP + moveset; current map + position; run status | `new_game()` → `new_run()` seeds the party from the chosen starter and builds a fresh map. **All Hero / XP / level fields removed.** |
| `tools/gen_content.gd` | Monster roster **+ movesets**, and **mark the starter-eligible (weaker) monsters** so run-start can offer three; new **`tools/gen_moves.gd`** (or folded in) | Same data-driven `ResourceSaver` pattern. |
| `tools/gen_art.gd`, `tools/gen_tileset.gd` | **Magna-Tiles restyle** + map/monster art | Custom-data layers unchanged; the pixels change. |
| — (new) | `scripts/map/map_generator.gd` (layered-DAG), `scenes/map/map_view.tscn` + `.gd`, `scripts/data/move_data.gd` | The roguelike shell. |
| `tools/tests/test_battle.gd` | Extend, and add `test_map.gd` (connectivity/reconnection) plus starter-selection / recruit / permadeath / switch / **party-wipe** tests | Keep the headless suite green each phase. |

## Phased roadmap

Each phase is **one PR into `main`**, sized to stay small and testable. You listed the map first;
engineering-wise the **collection + party-battle model is the foundation** the map's encounters
need, so it comes first. *(If seeing the traversal feel sooner matters more, we can build a map
skeleton with placeholder fights first — flagged.)*

| Phase | Branch | Delivers | Depends on |
|---|---|---|---|
| **0** ✅ | `docs/design-roadmap` | **This doc.** | — |
| **1** ✅ | `feat/monster-collection` | **Starter selection** (pick 1 of 3), `MonsterData` unification, `RunState` party of monsters (persistent per-member HP), **auto-recruit on win**, and the **one-active-monster / switch-on-death / permadeath** battle rewrite (**lose only on party wipe**). Still in the existing single room. | 0 |
| **2** ✅ | `feat/node-map` | The **branching node-map + roguelike run shell**: `map_generator` (layered DAG), `map_view`, node types (battle / heal / power-up[+max HP] / teleport / boss; treasure/rest → hybrid rooms). Run ends on party wipe → fresh run; nothing persists. | 1 |
| **3** ✅ | `feat/moves` | `MoveData` + `gen_moves`, per-monster **movesets**, richer command menu; power-up nodes can now grant **new moves**. | 1 (2 for move-granting nodes) |
| **4** ✅ | `feat/magna-tiles-art` | Unified **Magna-Tiles** restyle across room tiles, map nodes/paths, and battle backdrop; translucent sprites. | 2 |
| **5** ✅ | `feat/content-balance` | **12-monster roster with difficulty tiers** (wild encounters scale with map depth), **new move kinds** (drain lifesteal, focus buff, slam), an **Elite node** type (recruit + heal), the **Hydra** final boss (the Griffin becomes an elite), and the **Chicken** starter. Added tests. | 2, 3 |
| **6** | `feat/monster-merge` | **Monster merging** — at the cap, combine two monsters into one for a small total-stat bump + a new moveset (a third option beside replace/skip). | 1, 3 |
| **7** ✅ | `feat/walkable-dungeon` | **Walkable dungeon traversal** — the branching map is rendered as **rooms + corridors** and walked with the keyboard (`dungeon_view.gd`), replacing the clickable node-map. Fully open & backtrackable (reach every node); node types resolve on room-entry; distinct **marker props** per type. | 2, 4 |
| **8** ✅ | `feat/dungeon-art` | **Stained-glass tile art** — searched for CC0 packs (none matched, see below) and instead rebuilt the generated tiles at **64px** as true Magna-Tiles panels: beveled plastic frame, translucent backlit glass, specular sheen, faceted gem markers. | 4, 7 |
| **9** ✅ | `feat/monster-portraits` | **Monster portraits** — optional per-monster art (`assets/portraits/<id>.png`, 256×256) on the starter-select cards, the battle enemy area, and the lead/switch buttons, with a **flat-tint fallback** so missing art never breaks a screen. Art is author-supplied (classic D&D monster style); the pipeline needs no generator re-run. | 1 |
| **10** ✅ | `feat/title-and-balance` | **Title screen** (click to begin) + a **difficulty pass**: the chosen starter gets a one-time stat boost since it fights alone early on, and all monster HP runs **+25%** so an average fight lasts longer. | 1, 5 |
| **T** ✅ | `feat/monster-editor` | **Content tooling** — an in-editor monster/enemy editor for easy add / delete / modify (see below), plus a portrait/map-sprite linker and monster-specific map markers. Independent of the gameplay phases. | — |
| **11** ✅ | `feat/audio-scaffolding` | **Audio scaffolding** — a `SoundManager` autoload plays SFX/music by convention-based id lookup (see below), wired into movement, battle actions, node events, and menus. Ships with **zero real audio files** — fully wired but silent until sounds are dropped in. | — |

## Content tooling

**`addons/monster_editor/`** is a Godot **EditorPlugin** dock ("Monsters", left panel) for adding,
duplicating, editing, and deleting roster monsters without hand-editing `tools/gen_content.gd`'s
`ROSTER` table. It only runs inside the Godot editor GUI (enabled by default via
`project.godot`'s `[editor_plugins]`, written by `gen_project.gd`) — no effect on the shipped game.

- **Fields:** id, display name, stats (HP/attack/defense/speed/tier), the boss/starter/elite flags,
  tint, and moveset (add/remove from the existing move roster).
- **Art linking:** a Browse/Clear row for each of the two optional per-monster art conventions —
  portrait (`assets/portraits/<id>.png`, shown on starter cards / battle / lead-switch buttons) and
  the new **map sprite** (`assets/map_sprites/<id>.png`, shown on a battle/elite/boss room's marker
  in the walkable dungeon in place of the generic per-type gem — see the Run & walkable dungeon
  section of CLAUDE.md for the pre-roll mechanism that makes this possible). Both fall back
  gracefully when absent, same contract as the original Phase 9 portraits.
- **Architecture:** all CRUD/validation/file-copy logic lives in plain, non-`@tool` helper classes
  (`scripts/data/monster_repo.gd`, `move_repo.gd`, `asset_link.gd`) that are unit-tested headless
  against scratch directories; the dock (`addons/monster_editor/monster_editor_dock.gd`) is a thin
  UI shell over them, built in code (no `.tscn`).
- **Caveat — not synced with `gen_content.gd`:** the dock and `tools/gen_content.gd`'s hardcoded
  `ROSTER` table are two independent ways to write the same `assets/data/monsters/*.tres` files, not
  a synced pair. Editing an *existing* roster monster's stats via the dock and later re-running
  `gen_content.gd` (e.g. to rebalance a different monster) will silently overwrite that dock edit
  back to whatever `ROSTER` says. Once the dock is your primary way of touching content, either stop
  re-running `gen_content.gd` for monsters you've hand-tuned, or mirror the edit back into `ROSTER`.
  New monsters created only via the dock are safe — `gen_content.gd` only writes the ids in its own
  table, it doesn't delete anything else.

## Audio

**`SoundManager`** (autoload) plays SFX and music by **convention-based id lookup** —
`assets/audio/{sfx,music}/<id>.{ogg,wav,mp3}`, via `scripts/data/sfx_library.gd` /
`music_library.gd` — the same optional-art shape as `Portraits`/`MapSprites`: a missing id is a
silent no-op, so the game runs (silently) with zero audio files present. This is the state the
repo ships in as of Phase 11 — every meaningful moment already calls into the sound system, but
no real sound files exist yet. Adding one is purely dropping a file at the right path; no code or
data changes, no generator to re-run. See `assets/audio/README.md` for the full id vocabulary
(movement, battle moves, node events, menus, four music tracks) and the file spec (format, sample
rate, length, size, loudness). `SoundManager.play_sfx()`/`play_music()` are reached via
`get_node_or_null("/root/SoundManager")` from every call site, same reasoning as `RunState` —
generators and headless tests never depend on autoload registration order.

## Verification (per phase)

- **Headless gates every push** (already enforced by the `pre-push` hook): `--import`, then
  `doctor.gd` (exit 0) and `run_tests.gd` (all pass).
- **New tests by phase:** P1 — starter selection (offers 3 from the starter pool; the chosen one
  seeds the party), recruit-on-win, switch-on-death, permadeath, **party-wipe = run over**,
  persistent HP. P2 — map connectivity (every node reachable, branches reconnect, boss terminal),
  node-effect resolution. P3 — move resolution / guard / heal. P5 — balance smoke.
- **Manual per phase:** P1 — pick a starter, beat a wild enemy and see it join, switch monsters when
  one falls, lose your last monster → run ends. P2 — traverse a branching map; take a heal /
  power-up / teleport; enter a hybrid room. P4 — the whole game reads as translucent primary-color
  Magna-Tiles.

## Open questions / decisions to lock

1. **Starter trio:** you pick 1 of 3 weaker starters at run start — are the three a **fixed trio**,
   or **3 randomly drawn** from the common wild pool each run?
2. **On-map avatar:** with no Hero, what represents you in walkable (hybrid) rooms — your **lead
   monster** (*default*), or a neutral party token?
3. **Collection cap** = 5 (*default*); when full, replace / skip / (later phase) merge.
4. **Moves:** unlimited use (no PP) *default*; the Strike / Heavy / Guard / Heal taxonomy is a
   starting point.
5. **Node roster:** include **Elite** and **Treasure/Rest** nodes, or trim to
   battle / heal / power-up / teleport / boss for the first cut?
6. **Map shape:** row count and nodes-per-row (affects run length) — pick during Phase 2.
7. **Phase order:** collection-first vs a map-skeleton-first prototype (see the roadmap note).
