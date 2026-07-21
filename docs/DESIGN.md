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
auto-recruit the monsters you defeat, and battle with a party where **one fighter is active at a
time**. Progression is collection-driven (no XP/levels), runs are disposable (nothing persists
between them), and the whole game is restyled into a bright, translucent **Magna-Tiles** look.

---

## Vision & core loop

Each **run**:

1. You start with the **Hero** (+ one weak starter monster — *default*).
2. You navigate a **branching node-map** — pick a path through a series of nodes; branches fork
   and reconnect; the final node is the **Griffin** boss.
3. Most nodes are **battles**. Battles are one-fighter-vs-one-fighter. Win a wild battle → the
   defeated monster is **auto-recruited** into your party.
4. Other nodes **heal**, grant a **static power-up**, or **teleport** you elsewhere on the map.
5. **HP persists** between battles. A downed party member is **gone for the rest of the run**
   (permadeath). If your **Hero** is defeated, the **run ends**.
6. Reach and defeat the **Griffin** → you win the run. Die → the run is over and a **fresh run**
   begins (nothing carries over).

Power comes from **which monsters you've collected**, **how you spend their HP across a run**, and
the **power-ups** you pick up — never from grinding.

## Battle system

- **One active fighter at a time** on your side — either the Hero *or* one collected monster.
- At the **start of each battle you choose your starting fighter** from your living party.
- When the **active fighter is defeated** (HP 0): it is **permanently lost for the run**, and you
  **switch in** another living member to continue.
- If the defeated fighter is the **Hero → the run ends immediately.** The Hero is both a fighter
  and the run's life-total.
- If **no living member remains** to switch in → the run ends (party wipe).
- **Enemy side stays single** — one enemy per battle; the boss is solo. Multi-enemy battles are out
  of scope for now.
- **HP is per-member and persists** across battles within a run (classic attrition).
- **No fleeing the boss**; fleeing a wild battle returns you to the map without recruiting.

This reuses the existing `Combatant` and its pure, static `compute_damage`. The turn state machine
gains a *choose-starter* step and a *switch-on-death* transition.

## Monsters & collection

- **Auto-recruit on victory:** beating a wild (non-boss) monster adds it to your party. The
  defeated enemy *literally becomes* a party member — the same data type describes both.
- **Collection cap:** 6 (*default, tunable*). When full, prompt to replace a member or skip.
- **Monsters are fixed-stat** — they have their own HP and moves but **do not level up**. You grow
  stronger by collecting better monsters and grabbing power-ups, not by grinding.
- **No XP, no levels for anyone** (the Hero included). Today's `GameState` XP/level system is
  retired.

## Moves (combat depth — a later phase)

- Each fighter has a small set of **moves distinguished by effect, not element** (no type chart).
- Starter taxonomy (*tunable*): a reliable **Strike**, a high-power **Heavy hit**, a **Guard** (the
  old Defend), and a **Drain/Heal**. Unlimited use (no PP) for now.
- Moves are **data** (`MoveData` resources) so the roster and movesets stay editable in `tools/`.
- The battle command menu lists the **active fighter's moves**, replacing the fixed
  Attack / Defend / Flee.

## The node-map (roguelike traversal)

- A run map is a **layered DAG** (Slay-the-Spire / FTL style): rows of nodes, edges to the next
  row, **branches that fork and reconnect**, boss at the top. **Procedurally generated each run.**
- You may only travel to a node **connected by an edge** from your current node.

| Node | Effect |
|---|---|
| **Battle** (wild) | One-vs-one fight; win → auto-recruit. Most common. |
| **Heal** | Restore HP of your living party (no revive — permadeath). |
| **Power-up** (static) | A lasting boost: **+max HP** now; **a new move** once moves ship. |
| **Teleport** | Jump to a different node (skip ahead / cross to another branch). |
| **Treasure / Rest room** | Opens a small **walkable tile room** (hybrid, below) with a pickup. *Flagged.* |
| **Elite** | Tougher fight, better reward. *Flagged.* |
| **Boss** | The Griffin — final node; win = victory. |

**Hybrid rooms:** the node-map is how you travel, but **treasure/rest nodes open a small walkable
tile room** that **reuses the existing grid-movement engine** — so the movement work already built
stays in use and adds texture. Battle/boss nodes go straight to the battle overlay;
heal/power-up/teleport resolve on the map itself.

## Progression & persistence

- **Within a run:** grow only via **collecting monsters** and **power-up nodes** (+max HP, later
  new moves). No XP, no levels.
- **Between runs:** **nothing persists** — pure roguelike. Death → fresh map, fresh starting party.

## Art direction — Magna-Tiles (whole game)

Treatment: **translucent primary-color fills** (red / blue / green / yellow), **defined dark or
same-hue borders**, and a **soft inner glow / gradient** (lighter center → saturated edge) so tiles
read like backlit plastic. Applied consistently across:

- **Room tiles** — each tile type a primary color (floor / wall / special).
- **Map nodes & paths** — colored translucent node shapes; glowing connective paths.
- **Battle backdrop** — translucent color panels.
- **Player & monster sprites** — translucent colored shapes.

Produced by restyling `tools/gen_art.gd` (plus new map/monster art), using the same
headless-generator pattern already in `tools/`.

---

## Architecture: mapping the design onto existing code

| Existing | Becomes | Notes |
|---|---|---|
| `scripts/overworld.gd` (one room = the game) | **Split**: a reusable **Room** scene (paint + walk + trigger) *plus* a new top-level **Run/Map** controller | Room logic is reused wholesale for hybrid nodes. |
| `scripts/battle.gd` (Hero vs one enemy) | **Party-aware battle**: choose-starter, switch-on-death, permadeath, moves menu | Keeps the state machine and `_say` pacing; adds a party/bench and a switch transition. |
| `scripts/battle/combatant.gd` | `+ moves: Array[MoveData]` | Pure `compute_damage` stays; a move feeds its power in. |
| `scripts/data/enemy_data.gd` (`EnemyData`) | **`MonsterData`** — one type shared by wild enemies *and* recruited allies; `+ moves[]`, drop `xp_reward` | Rename touches `gen_content.gd`, `overworld.gd`, `battle.gd`, `test_battle.gd`, and the `.tres` files. |
| `autoload/game_state.gd` (`GameState`, XP/levels) | **`RunState`** — current party (each with current HP + moveset), current map + position, run status | `new_game()` → `new_run()` builds a fresh map + starting party. XP/level fields removed. |
| `tools/gen_content.gd` | Monster roster **+ movesets**; new **`tools/gen_moves.gd`** (or folded in) | Same data-driven `ResourceSaver` pattern. |
| `tools/gen_art.gd`, `tools/gen_tileset.gd` | **Magna-Tiles restyle** + map/monster art | Custom-data layers unchanged; the pixels change. |
| — (new) | `scripts/map/map_generator.gd` (layered-DAG), `scenes/map/map_view.tscn` + `.gd`, `scripts/data/move_data.gd` | The roguelike shell. |
| `tools/tests/test_battle.gd` | Extend, and add `test_map.gd` (connectivity/reconnection) plus recruit / permadeath / switch tests | Keep the headless suite green each phase. |

## Phased roadmap

Each phase is **one PR into `main`**, sized to stay small and testable. You listed the map first;
engineering-wise the **collection + party-battle model is the foundation** the map's encounters
need, so it comes first. *(If seeing the traversal feel sooner matters more, we can build a map
skeleton with placeholder fights first — flagged.)*

| Phase | Branch | Delivers | Depends on |
|---|---|---|---|
| **0** | `docs/design-roadmap` | **This doc.** | — |
| **1** | `feat/monster-collection` | `MonsterData` unification, `RunState` party (Hero + collected monsters, persistent per-member HP), **auto-recruit on win**, and the **one-active-fighter / switch-on-death / permadeath** battle rewrite. Still in the existing single room. | 0 |
| **2** | `feat/node-map` | The **branching node-map + roguelike run shell**: `map_generator` (layered DAG), `map_view`, node types (battle / heal / power-up[+max HP] / teleport / boss; treasure/rest → hybrid rooms). Run ends on Hero death → fresh run; nothing persists. | 1 |
| **3** | `feat/moves` | `MoveData` + `gen_moves`, per-fighter **movesets**, richer command menu; power-up nodes can now grant **new moves**. | 1 (2 for move-granting nodes) |
| **4** | `feat/magna-tiles-art` | Unified **Magna-Tiles** restyle across room tiles, map nodes/paths, and battle backdrop; translucent sprites. | 2 |
| **5** | `feat/content-balance` | Roster/moveset expansion, node-distribution and power-up-pool tuning, teleport behavior, added tests, balance. | 2, 3 |

## Verification (per phase)

- **Headless gates every push** (already enforced by the `pre-push` hook): `--import`, then
  `doctor.gd` (exit 0) and `run_tests.gd` (all pass).
- **New tests by phase:** P1 — recruit-on-win, switch-on-death, Hero-death-ends-run, permadeath,
  persistent HP. P2 — map connectivity (every node reachable, branches reconnect, boss terminal),
  node-effect resolution. P3 — move resolution / guard / heal. P5 — balance smoke.
- **Manual per phase:** P1 — beat a wild enemy, see it join, switch fighters, lose the Hero → run
  ends. P2 — traverse a branching map; take a heal / power-up / teleport; enter a hybrid room.
  P4 — the whole game reads as translucent primary-color Magna-Tiles.

## Open questions / decisions to lock

1. **Starting party each run:** *default* = Hero **+ one weak starter monster** (so you aren't
   forced to risk the Hero on turn one). Alternative: Hero alone.
2. **"Hero death ends the run"** creates a possible degenerate strategy — benching the Hero forever
   behind monster meat-shields. Is that intended, or do we want a mitigation (Hero must be your
   starter / can't be fully benched / a one-time "last stand")?
3. **Collection cap** = 6 (*default*); when full, prompt replace-or-skip.
4. **Moves:** unlimited use (no PP) *default*; the Strike / Heavy / Guard / Heal taxonomy is a
   starting point.
5. **Node roster:** include **Elite** and **Treasure/Rest** nodes, or trim to
   battle / heal / power-up / teleport / boss for the first cut?
6. **Map shape:** row count and nodes-per-row (affects run length) — pick during Phase 2.
7. **Phase order:** collection-first vs a map-skeleton-first prototype (see the roadmap note).
