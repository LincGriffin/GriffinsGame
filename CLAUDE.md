# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## Project

**GriffinsGame** — a 2D turn-based dungeon crawler in **Godot 4.7 (GDScript)**, targeting Windows.
Player moves tile-by-tile around an overworld; stepping on a monster tile triggers a
Pokémon/Final-Fantasy-style turn-based battle (separate scene/state). Goal: navigate the dungeon,
defeat enemies, reach and defeat a final boss.

Renderer: GL Compatibility. Physics: Jolt.

**Design & roadmap:** the target direction (roguelike monster-collector — branching node-map,
auto-recruited monsters, one-active-fighter battles, Magna-Tiles art) and the phased build order
live in `docs/DESIGN.md`. Consult it before starting a new gameplay feature.

### Layout
- `scenes/{overworld,battle,ui}` — scenes. Overworld movement lives in `scenes/overworld/`.
- `scripts/` — GDScript. `player.gd`, `overworld.gd` implemented.
- `assets/{sprites,tilesets,audio}` — art/audio. Tiles/sprites are the **Magna-Tiles** look —
  **64px stained-glass panels**: dark rim → beveled plastic frame → inner lip → translucent backlit
  glass + specular sheen, with faceted gem markers (`gen_art.gd`). Tiles are **generated, not
  sourced** — no CC0 pack matches this aesthetic (`docs/DESIGN.md` → "Why the art is generated").
  The battle backdrop (`gen_scenes.gd`) carries the same treatment in code.
- **Tile size is 64px** and the player `Camera2D` is at **zoom 1** — together these render the same
  on-screen size the old 32px-at-zoom-2 art did, with 4× the pixel detail. Changing one without the
  other rescales the whole game.
- `autoload/` — singletons: `RunState`, `SoundManager`, `DebugOverlay`.
- `tools/` — reproducible **generator scripts** (see below). Not shipped in gameplay.

## Architecture notes (keep these consistent)

- **Use `TileMapLayer`**, never the deprecated `TileMap` node (deprecated since Godot 4.3).
- **Grid movement is authoritative.** The player is a `CharacterBody2D` but does **not** use
  `move_and_slide`. `grid_cell: Vector2i` snaps instantly; a `Tween` only animates the visual glide;
  an `is_moving` guard enforces exactly one tile per step.
- **Wall collision = pre-move query**, not physics: `_is_walkable(cell)` reads the TileSet custom-data
  layer `walkable`. There is intentionally **no physics collision layer** on tiles — don't add one
  expecting it to block the player.
- **Monster tiles** carry custom-data `monster=true` (atlas coord `(2,0)`, source id `0`). The player's
  `moved` signal → `Overworld._on_player_moved` prints and emits **`battle_triggered(cell)`**. That
  signal is the **seam where the battle scene hooks in later** (pause overworld, load battle, then
  `set_cell(cell, SOURCE_ID, FLOOR)` on victory to clear the monster).
- Rooms are painted in code from an editable ASCII `ROOM` constant in `overworld.gd`
  (`#` wall, `.` floor, `M` monster, `B` boss, `P` start).

### Battle system

- **Battle runs as a full-screen overlay**, not a scene swap: `Overworld` adds `battle.tscn` on a
  `CanvasLayer`, disables the player's `_physics_process`, and `await`s the battle's `finished(result,
  enemy)` signal — so overworld state (position, cleared tiles) survives with no serialization.
- **Party battles, one active monster at a time.** There is **no "Hero"** — every fighter is a monster.
  At run start the player picks one of a few **starter monsters** (`scripts/starter_select.gd`). In
  battle you choose a lead; when it falls you switch in another. A downed monster is **permadead for the
  run**, and you lose only on a **party wipe**. `Battle` (`scripts/battle.gd`) is an explicit turn state
  machine (intro → choose lead → player command → player's active monster acts, then the enemy →
  switch-on-death → win/lose). **The player's active monster ALWAYS acts first** — the `speed` stat
  is intentionally ignored for turn order and hidden from the player-facing UI (it still exists on
  `MonsterData`/`Combatant`, just unused; `compute_damage` never read it anyway).
  The command menu lists the active monster's **moves**, a **Switch** command (shown whenever another
  living monster is available), and Flee — **currently hidden** behind `Battle.FLEE_ENABLED := false`
  (flip it back on to restore it; `_on_flee`/`FLEE_CHANCE`/its sfx hook are all still intact). Move
  **kinds** (data-driven, effect not element): `attack`, `guard` (halve next hit), `evade` (the
  next hit deals 0 damage), `reflect` (the next hit is redirected to its attacker instead), `heal`,
  `drain` (attack that heals the user **3/8** of the damage dealt — half, reduced 25%), `buff` (raise the user's `atk_bonus` for
  the battle; reset on switch-in), `stun` (an attack that also skips the target's next turn), and
  `reckless` (a heavy attack that also damages its own user — `floor(dmg/4)`, min 1). `guard` /
  `evade` / `reflect` are one-shot stances: set on cast, consumed by the very next incoming hit (or
  expire — cleared alongside `defending` whenever the command menu comes back up), and evaded/
  reflected hits skip every secondary effect (no drain-heal, no stun, no recoil) — only the
  0-damage/redirect itself happens. `stunned` is different: inflicted BY an opponent's `stun` move,
  checked and cleared at the start of the stunned side's own next turn (`_begin_player_command`/
  `_enemy_turn`), skipping it entirely — this can land mid-round (if the stunning side is faster)
  or next round (if slower), whichever the natural turn order produces. Enemies pick a random
  offensive move each turn from `attack`/`drain`/`stun`/`reckless` (never the defensive kinds —
  same simplification as guard/heal/buff, which enemies also never use).
- **Voluntary switching** (`_on_switch`, alongside the forced switch-on-faint): choose another
  living monster to lead with **before** the active one dies. Costs the turn — the enemy still
  acts — same as guard/heal/buff. The monster-select prompt (`_prompt_monster`) grew an
  `allow_cancel` param for this: a **Cancel** button that resolves to `null` and returns to the
  command menu with **no turn spent**; the forced (switch-on-faint) and initial (choose-lead)
  prompts don't pass it, since there's nothing to cancel back to there.
- **Content is data-driven.** `MonsterData` (`scripts/data/monster_data.gd`) resources live in
  `assets/data/monsters/` and are generated by `gen_content.gd` — the **same type** describes wild
  enemies and recruited allies. Each monster carries a set of **`MoveData`** moves
  (`assets/data/moves/`, generated by `gen_moves.gd`). `Combatant` (`scripts/battle/combatant.gd`) is the
  runtime participant; its `compute_damage(attacker, target, rng, move_power)` is **static and pure**
  (unit-tested in `test_battle.gd` / `test_moves.gd`). Power-up nodes open an interactive chooser
  (`scripts/powerup_select.gd`) offering **3 upgrades** — a mix of stat buffs (+Max HP / +Attack /
  +Defense) and a learnable move — that the player **assigns to a chosen party monster**
  (`run.gd::_build_upgrade_options` / `_grant_upgrade`). The offered upgrades are **data-driven**:
  `PowerupData` resources in `assets/data/powerups/` (generated by `gen_powerups.gd`, editable via
  the Power-up editor dock) — `_build_upgrade_options` loads them, skips a "move" power-up nobody
  can learn, and offers a move + stat buffs; it falls back to built-in stat buffs if the roster is
  empty. Card art: the power-up's own portrait/sprite (`PowerupArt`) → per-effect placeholder
  (`assets/upgrade_icons/<type>.png` via `scripts/data/upgrade_icons.gd`) → flat tint. The old auto
  teach-a-move-else-+HP path survives as `run.gd::_apply_powerup()` for the headless RunHarness.
- **`RunState` autoload** (`autoload/run_state.gd`) holds the current run's **party** — an array of
  monster `Combatant`s, each with its own HP that persists between fights (permadeath prunes the fallen).
  **No XP/levels; nothing persists between runs.** Scripts reach it via `get_node_or_null("/root/RunState")`
  rather than the global identifier, so scene/resource generators don't depend on autoload registration order.
- Winning a wild battle **auto-recruits** the defeated monster (up to `RunState.PARTY_CAP`, currently 5).
  Defeating the **boss (the Hydra)** wins the run; a party wipe shows GAME OVER (press **R** for a fresh
  run + new starter).
- **Monster merge (Phase 6).** Win a wild/elite fight while the party is **at the cap** and a merge
  overlay (`scripts/merge_select.gd`, `MergeSelect`) appears: pick **two** party members to fuse into
  one — freeing a slot — and the new monster is then recruited; **Skip** declines (no recruit, the
  pre-merge behavior). The fusion is pure/static in `scripts/monster_merge.gd` (`MonsterMerge.fuse`,
  unit-tested): **stats** = per-stat **max** of the two parents + a small bonus (`HP_MULT`/`ATK_BONUS`/
  `DEF_BONUS` — never the additive sum); **moves** = the **union** of both movesets, de-duped, capped
  at `MAX_MOVES`; **identity** = a special parent pair (`scripts/data/fusion_table.gd`, keyed by the
  two ids sorted) becomes that **specific monster** (its portrait/name), every other pair becomes a
  generic **"Fused &lt;stronger parent&gt;"** with a blended tint and no portrait (tint fallback).
  `RunState.merge(a, b)` removes both and appends the fused Combatant (net −1, freeing the slot).
  Headless `RunHarness` just skips the recruit at cap (no interactive merge).
- **Roster is tiered (Phase 5).** `MonsterData` carries a `tier` (0 = weakest … 3 = late) and an
  `is_elite` flag. Wild encounters **scale with map depth** — `run.gd` groups the wild pool by tier
  and `_pick_wild(row)` draws a depth-appropriate monster (deeper rows → tougher, with a chance to
  drop one tier for variety). The three **tier-0** monsters (Chicken / Slime / Bat) are the fixed
  starters. **Elites** (the Griffin and Gremlin Knob) are tougher fights that, on win, recruit the
  elite **and** full-heal the party. The **Hydra** is the final boss.
- **Difficulty tuning:** all monster HP in `gen_content.gd`'s `ROSTER` runs **+25%** over the
  original balance pass so an average fight lasts longer. The player's **chosen starter** also gets
  a one-time boost over its base stats (`RunState.STARTER_HP_MULT` / `STARTER_ATK_BONUS`, applied in
  `new_run()`) since it fights alone early in the run; monsters recruited later stay at base stats.
- **Monster portraits are optional art**, looked up by convention — `assets/portraits/<monster id>.png`
  (256×256) via `scripts/data/portraits.gd` (`Portraits.for_monster()`, memoised). Shown on the
  **starter-select cards**, as the **battle enemy art** (the monster's `tint` block becomes an 8px
  frame around it), and as **thumbnails on the lead/switch buttons**. Any monster without a file
  **falls back to its flat `tint`**, so the game runs with zero portraits present. Adding art needs
  no generator re-run and no data edit — drop the PNG in and `--import`. See
  `assets/portraits/README.md` for the spec and the id list.
- **Debug overlay** (`DebugOverlay` autoload, `F3`): FPS, the party (each monster's HP), battle state,
  player cell + tile data; cheats `H` (toggle hold-to-move) and `K` (set the whole party to 1 HP). It
  finds live nodes via the `player`/`battle` groups, so it works in any scene.
- **Battle juice (Phase 12).** `_update_hud()` **tweens** each HP bar's `value` instead of
  snapping it (`_animate_hp_bar`, `HP_TWEEN_TIME`), and tints its fill green/yellow/red by
  remaining percentage via a **per-bar** `StyleBoxFlat` override (`_hp_styles`, created once —
  never mutates the shared default theme resource). Damage/heal land as a **floating "±N" label**
  (`_pop_number`) that rises and fades near the target. Taking a hit gets a brighten-flash +
  position-jitter **shake** (`_hit_feedback`/`_shake`) — the enemy sprite for the player's own
  attacks, just the player's HP bar (no flash — there's no player sprite to flash) for the
  enemy's. All of this is cosmetic only; it doesn't touch combat math or turn order.
- **`scripts/button_polish.gd`** (`ButtonPolish.apply(button)`) adds a small hover scale-up
  tween + a `ui_hover` sound to any dynamically-created `Button` — used on starter-select cards,
  battle's command/monster-select buttons, and Settings' Close button.

### Run & walkable dungeon

- A **title screen** (`scripts/title_screen.gd`, built in code like `starter_select.gd` — no
  separate `.tscn`) opens on boot: any click dismisses it and emits `started`, and `run.gd` then
  **fades to black and back** (`_fade_out`/`_fade_in`, `_on_title_started`) around the swap to
  starter select (fresh run) or straight into an in-progress run, instead of a hard cut.
- **Escape opens Settings from anywhere** (title, starter select, dungeon, battle) —
  `run.gd::_open_settings()` adds `scripts/settings_menu.gd` (`SettingsMenu`, built in code), a
  small overlay with an `HSlider` per audio bus (`SoundManager.SFX_BUS`/`MUSIC_BUS`) wired
  straight to `AudioServer.set_bus_volume_db`. It pauses dungeon movement while open and restores
  it on close (unless a battle is separately keeping it paused); closes on Escape, Close, or a
  click outside the panel.
- The **main scene is `scenes/map/run.tscn`** (`scripts/run.gd`). A run: pick a starter → a
  **procedurally-generated branching map** (`scripts/map/map_generator.gd`, a layered DAG that
  forks/reconnects and funnels to the Hydra) rendered as a **walkable rooms-and-corridors dungeon**
  by `scripts/map/dungeon_view.gd` and traversed with the keyboard (reusing `scripts/player.gd`).
- **Each node is a small room; each edge a short corridor.** `dungeon_view.gd` lays the DAG out
  spatially (row 0 at the bottom, boss at the top, a spawn **entrance** below row 0), paints a
  distinct **marker prop** in each room's center (per node type), and follows the player with the
  `Camera2D` from `player.tscn`. The **whole dungeon is open and connected** — you can **backtrack
  and eventually reach every node**. Stepping into an *uncleared* room emits
  `DungeonView.room_entered(id)`; once resolved the room is cleared (marker → floor) and becomes
  walk-through. `run.gd` reuses all its node resolution (`_do_battle` / `_pick_wild(row)` /
  `_pick_elite` / `_heal_party` / `_apply_powerup` / win-lose); it pauses movement
  (`dungeon_view.set_walking(false)`) while a battle overlay is up.
- Node types resolve as: **battle** (wild → auto-recruit) / **elite** (tough fight → recruit + full
  heal) / **boss** / **heal** (full party) / **powerup** (a 3-choice upgrade chooser, assigned to a
  monster — see the Battle system section) / **teleport**
  (`warp_to` — drop the player ~2 rows ahead) / **room** (a treasure chest → party-wide +max HP,
  `ROOM_BONUS_HP`, resolved **in place**). Win the boss → YOU WIN; a party wipe → GAME OVER
  (press **R** → fresh run + new starter). Nothing persists between runs.
- **Elite nodes** are gated to rows ≥ `MapGenerator.ELITE_MIN_ROW` (the run eases in) with a small
  weight; they draw from the elite pool (`ELITE_ENEMIES` in `run.gd`).
- **Marker tiles:** the tileset atlas is floor `(0,0)`, wall `(1,0)`, then walkable node markers
  `(2,0)`..`(8,0)` (battle/boss/heal/powerup/teleport/elite/room) — generated by `gen_art.gd` in the
  `map_view.gd` palette; node identity comes from the map data (cell→id), so markers carry no extra
  custom data.
- **Battle/elite/boss encounters are pre-rolled at map-generation time**, not on room-entry:
  `run.gd::_begin_run()` calls `_assign_encounters()` right after generating the map, which stores
  each such node's `MonsterData` as `node["enemy"]` (via the existing `_pick_wild(row)` /
  `_pick_elite()` / the fixed `BOSS_ENEMY`). `_enter_room` just reads `node["enemy"]` — this exists
  so `DungeonView` can show a **monster-specific map sprite** ahead of time (see below) and so
  fleeing and re-entering a fight shows the same monster rather than a fresh reroll.
- **Optional per-monster map sprite:** `assets/map_sprites/<id>.png`, looked up by
  `scripts/data/map_sprites.gd` (`MapSprites`, same optional-art/memoised-cache contract as
  `Portraits` above). `dungeon_view.gd` draws it over a battle/elite/boss room's marker tile when
  present (scaled to the 64px tile), falling back to the generic per-type gem otherwise.
- **Retired but kept in repo:** `scripts/map/map_view.gd` (the old clickable node-map) and
  `scripts/room.gd` / `scenes/map/room.tscn` (the standalone treasure room — treasure now resolves in
  place). `overworld.gd` / `overworld.tscn` remain the movement test fixture (`test_overworld.gd`).
- **Deferred** (kept for later): real Magna-Tiles floor/wall **art assets** (this dungeon uses the
  generated tiles), a power-up / target chooser, and a rest-vs-treasure split.

### Content tooling: the editor docks

Two Godot **EditorPlugin** docks, both enabled by default via `project.godot`'s `[editor_plugins]`
(written by `gen_project.gd`), both **inside the Godot editor GUI only** — no effect on the shipped
game, not part of the headless build/test pipeline. Each is a thin UI shell (built in code, no
`.tscn`) over a headless-testable repo; **all CRUD/validation lives in the repo**, not the plugin.

- **Monster editor** — `addons/monster_editor/` (dock "Monsters"): add / duplicate / edit / delete
  roster monsters without hand-editing `tools/gen_content.gd`. Backed by
  `scripts/data/monster_repo.gd` (`MonsterRepo` — list/load/create/save/delete + id-format and
  uniqueness validation over `assets/data/monsters/*.tres`, every function takes an optional `dir`
  so tests point at a scratch directory). Uses `MoveRepo`'s listing to offer moves for a monster's
  moveset.
- **Move editor** — `addons/move_editor/` (dock "Moves"): add / duplicate / edit / delete battle
  moves (id, display name, **kind** picked from `MoveRepo.KINDS` so it can't drift from what
  `battle.gd` resolves, power, description) without hand-editing `tools/gen_moves.gd`. Backed by
  `scripts/data/move_repo.gd` (`MoveRepo` — same CRUD/validation shape as `MonsterRepo`, optional
  `dir`; its read-only `list_ids`/`load_all` are still what the monster dock's move picker uses).
- **Power-up editor** — `addons/powerup_editor/` (dock "Power-ups"): add / duplicate / edit /
  delete the **data-driven power-ups** the chooser offers (id, display name, `effect` from
  `PowerupRepo.EFFECTS` = hp/attack/defense/move, amount, a `move_id` picked from the move roster
  for the "move" effect, description, tint) without hand-editing `tools/gen_powerups.gd`. Backed by
  `scripts/data/powerup_repo.gd` (`PowerupRepo`, same CRUD shape). It's the one dock with **art
  upload for two slots** — a **portrait** (`assets/powerup_portraits/<id>.png`) and a **sprite**
  (`assets/powerup_sprites/<id>.png`) via `AssetLink`, looked up at runtime by
  `scripts/data/powerup_art.gd` (`PowerupArt.portrait_for`/`sprite_for`, memoised, null-safe). The
  chooser card prefers portrait → sprite → the per-effect `upgrade_icons` placeholder → flat tint.
- **Portrait / map-sprite linking:** the dock has a Browse/Clear row for each optional art
  convention (`assets/portraits/<id>.png`, `assets/map_sprites/<id>.png`) via
  `scripts/data/asset_link.gd` (`AssetLink.import_image`/`clear_image` — copies a picked file to
  the convention path; also unit-tested headless against scratch dirs). Requires the monster to be
  **saved first** (its id is the filename). Previews load the raw image straight from disk
  (`Image.load_from_file`), not through the resource-import pipeline, so they show up immediately
  without waiting on a filesystem rescan; the dock still triggers
  `EditorInterface.get_resource_filesystem().scan()` afterward so the game's own `load()`-based
  lookups (`Portraits`/`MapSprites`) pick up the new file too.

### Audio

- **`SoundManager`** (autoload) plays SFX and music by **convention-based id lookup** — same
  optional-art shape as `Portraits`/`MapSprites`: `scripts/data/sfx_library.gd` /
  `music_library.gd` look under `assets/audio/{sfx,music}/<id>.{ogg,wav,mp3}` (memoised, tries
  all three extensions), and a missing id is always a **silent no-op**. The repo ships with a full
  set of **CC0 SFX** (all 27 ids — Juhani Junkala's "512 Sound Effects" 8-bit pack, `.wav`) in
  `assets/audio/sfx/`. **Music is present locally but intentionally untracked** (the four Junkala
  "5 Action Chiptunes" tracks → `title`/`dungeon`/`battle`/`battle_boss`): they're ~41 MB of WAV
  and are being held out of git until they can be re-encoded to compressed OGG — so a fresh clone
  plays SFX but is silent on music until those files are dropped in. See `assets/audio/README.md`
  for the id vocabulary and file spec. Adding or swapping a sound is purely "drop a file at the
  right path," no code or data changes.
- **API:** `SoundManager.play_sfx(id)` (round-robins across a small pool of `AudioStreamPlayer`s
  on an `"SFX"` bus so overlapping sounds don't cut each other off) and
  `SoundManager.play_music(id)` (one `AudioStreamPlayer` on a `"Music"` bus; re-requesting the
  current track is a no-op; loops itself via the player's `finished` signal rather than each
  file's own loop metadata, so any dropped-in file loops with zero import fiddling).
  `stop_music()` is also available. Both audio buses are created at runtime in `_ready()`
  (idempotent), not via a generated bus-layout resource.
- **Reached via `get_node_or_null("/root/SoundManager")`**, same reasoning as `RunState` — every
  call site (`player.gd`, `battle.gd`, `run.gd`, `starter_select.gd`, `title_screen.gd`) is
  null-guarded through a private `_sfx(id)`/`_music(id)` wrapper, so headless tests that build
  scenes standalone (no autoloads registered) stay green with the manager absent.
- **Hook points:** `player.gd` → `step` / `blocked` per move attempt. `battle.gd` → battle music
  on `_ready`, `encounter`/`encounter_boss` on intro, `move_<kind>` per move used (1:1 with
  `MoveData.kind`), `enemy_hit`, `faint`, `victory`, `defeat`, `flee`. `run.gd` → `title`/`dungeon`
  music, `node_heal`/`node_powerup`/`node_room`/`node_teleport` per node type, `win`/`lose`.
  `starter_select.gd`/`title_screen.gd` → `ui_select` on a card/dismiss click.

### Testing infrastructure: BattleHarness

`battle.tscn` had **no scene-level test coverage** until Phase 14 — its `_ready()` requires a
live `/root/RunState` and unconditionally kicks off an async intro gated by real wall-clock
timers, so driving it safely from a test needs shared infrastructure rather than each test
reinventing it.

- **`tools/tests/battle_harness.gd`** (`BattleHarness`) drives a REAL `battle.tscn` end-to-end —
  builds a `RunState`-backed party, instantiates the scene, and offers `start(party, enemy)` /
  `use_move(id)` / `switch_to(id)` / `flee()` / `resolve_prompt(id)`, all by `MonsterData`/`MoveData`
  **id**, never by clicking buttons. Construct it with the actual `SceneTree` (`BattleHarness.new(tree)`
  — `runner` in a test, `self` in a `--script extends SceneTree` tool), **not** a `Node`: calling
  `.get_tree()` on a Node near a `--script` SceneTree's own `_init()` returns null before the tree
  is fully wired up, which the existing `_base.gd` test convention already sidesteps by holding
  the SceneTree directly.
- **`battle.gd` gained two purely-additive signals for this**: `command_ready` (emitted at the top
  of `_begin_player_command()`) and `monster_prompt_ready(options)` (emitted in `_prompt_monster`
  right before it awaits a choice). `STEP` (message pacing) became a `var`, not `const`, so the
  harness can zero it before `add_child()` for fast tests. Nothing in normal play observes either
  signal or changes behavior.
- **The tricky part was a signal race, not the scene wiring**: `battle._choice_made.emit(...)` can
  resolve **synchronously all the way through to `command_ready`** whenever there's no real
  `await` in between the choice and the next command prompt (e.g. cancelling a switch, or picking
  the initial lead) — connecting listeners *after* the emit call simply misses that emission and
  hangs forever. The fix (`_arm_beat()` / `_consume_beat()`) always connects listeners for the
  next "beat" **before** triggering whatever might complete it, uniformly for every action, rather
  than reasoning case-by-case about which paths happen to have an intervening await.
- **`tools/tests/test_battle_scene.gd`** — real end-to-end tests using the harness: win/lose flow,
  voluntary switch (changes the active monster, costs the turn, cancel costs nothing), forced
  switch-on-faint (prompts when multiple survivors exist), and that Switch/Flee are shown/hidden
  correctly. Uses deliberately lopsided fixture stats (a 1-HP side, a 50+ HP side) so outcomes are
  guaranteed regardless of the ±1 damage variance, rather than trying to seed `battle._rng`
  (`_ready()` unconditionally calls `_rng.randomize()`, so an externally-set seed wouldn't survive
  anyway). Exact damage math is already covered by `test_battle.gd`'s pure `compute_damage` tests —
  these are about the state machine.
- **`tools/simulate_battle.gd`** — a standalone headless tool (same harness, same
  `--script`-friendly `SceneTree` construction) that plays out many battles between a configured
  party and enemy with a simple always-attack AI and reports win/loss/turn stats. Edit
  `PARTY_IDS`/`ENEMY_ID`/`BATTLES` at the top and run it like any other `tools/` script. For manual
  balance/functionality spot-checks, not a replacement for playing the game.
- **`tools/tests/run_harness.gd`** (`RunHarness`) plays out a **full run** headlessly — starter
  pick through every reachable node to the boss — for when validating one battle in isolation
  isn't enough. It reuses `run.gd`'s own node-resolution methods on a **detached `Run` instance**
  (`_heal_party`/`_apply_powerup`/`_grant_treasure`/`_assign_encounters`/etc. — same approach
  `test_run.gd` already used) so node logic never drifts from what ships, and uses
  `BattleHarness` for every fight. Since the dungeon is fully open/connected, "playing the run"
  means resolving every node in row order (row 0 first, boss last), not modeling a literal walk
  path — a thorough playthrough, not a beeline. `BattleHarness.start()` gained a `reset_party`
  param (default `true`, unchanged for existing single-battle tests) so `RunHarness` can pass
  `false` and fight every battle with the run's **actual evolving party** instead of a fresh one
  reset between fights (which would silently wipe recruits and re-apply the starter boost on
  every single battle).
- **`tools/simulate_run.gd`** — a standalone tool (same `RunHarness`) that plays whole runs and
  prints a play-by-play log plus win/loss. **Its default AI always attacks** — never guards,
  heals, or switches proactively (only when forced by a faint) — so any win rate it reports is a
  maximally-aggressive-play **lower bound**, useful for validating the mechanics work end-to-end
  (recruiting, permadeath, node resolution, HP persisting across fights), not as a literal
  difficulty benchmark. `RunHarness.play()`'s `random_moves` param (surfaced as
  `simulate_run.gd`'s `RANDOM_MOVES` const) switches to a uniformly random pick from the active
  monster's **full** moveset each turn instead — including guard/heal/buff/evade/reflect/stun/
  reckless, not just attack/drain — a *different* non-strategic baseline that actually exercises
  the newer move kinds from the player side. Empirically it does noticeably **worse** than
  always-attack (wasted turns on situational moves add up) — expected, not a bug. Edit
  `STARTER_ID`/`RUNS`/`RANDOM_MOVES` at the top and run it.

### Run tracking

**`scripts/data/run_history.gd`** (`RunHistory`) persists a summary of every finished run — one
JSON record per run, appended to a file in `user://` (`record()`/`load_all()`/`clear()`, all
taking an explicit `path` so tests never touch the real files). Two separate logs share the same
record shape (`starter_id`, `outcome`, `nodes_resolved`, `battles_fought`, `died_to`,
`died_at_row`, `recruited`, `final_party`):
- **`RunHistory.REAL_PATH`** (`user://run_history.json`) — written by `run.gd`'s `_win()`/
  `_game_over()` for every actual playthrough. `run.gd` tracks the needed counters as it goes
  (`_starter_id`, `_nodes_resolved`, `_battles_fought`, `_died_to`/`_died_at_row`, `_recruited`)
  and assembles them via `_build_run_record(outcome)`.
- **`RunHistory.SIMULATED_PATH`** (`user://run_history_simulated.json`) — written by
  `RunHarness.play()` (default on; pass `record_history=false` to opt out) for
  `tools/simulate_run.gd` batches, so Monte Carlo noise never mixes with real player history.
- **`tools/report_run_history.gd`** — reads either log (`SOURCE := "real" | "simulated"`) and
  prints win rate, average battles/nodes, average row reached on a loss, top causes of death,
  starters used, and most-recruited monsters. This is currently **dev-facing** (balance
  reference); the record shape was chosen so the same log could back an in-game "Run History"
  screen later with no format changes.

## Build / validate workflow (this machine)

- **Godot binary:** `C:\Users\Dad\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
  (the `...win64.exe\` segment is a *folder*; use the `_console.exe` variant so stdout prints). No `godot` on PATH.
- **Python is unavailable** — `python`/`python3` are Microsoft Store stubs (exit 49). Do **not** use them.
  Generate PNGs / `.tres` / `.tscn` by writing a small `SceneTree` script and running Godot headless.
  This is why `.tres`/`.tscn` are built via the engine API + `ResourceSaver` (guaranteed-valid format)
  rather than hand-authored.

Common commands (run from anywhere; pass `--path`):
```bash
GODOT="/c/Users/Dad/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import                          # import assets (writes *.png.import + uids)
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/<gen>.gd     # run a generator
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/run_tests.gd # run the test suite (exit 0 = pass)
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/doctor.gd    # project health check (exit 0 = healthy)
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --quit-after 30                   # boot main scene, catch startup errors
```

### Dev tooling in `tools/`

Generators (rebuild content; re-run after changing what they produce):
- `gen_art.gd` — Magna-Tiles PNGs (backlit-plastic tiles + gem markers + player) · `gen_tileset.gd` — TileSet `.tres`
- `gen_scenes.gd` — packs `.tscn` (player, overworld, battle, debug overlay, run)
- `gen_project.gd` — input map + main scene + autoloads via `ProjectSettings`
- `gen_moves.gd` — move roster → `assets/data/moves/*.tres` (run **before** `gen_content`)
- `gen_content.gd` — monster roster → `assets/data/monsters/*.tres` (edit the table there to rebalance)
- `gen_powerups.gd` — power-up roster → `assets/data/powerups/*.tres` (the upgrades the chooser offers)
- `gen_upgrade_icons.gd` — placeholder per-effect upgrade icons → `assets/upgrade_icons/*.png`

Quality gates:
- **`run_tests.gd`** — headless test runner. Discovers `tools/tests/test_*.gd` suites (each
  `extends "res://tools/tests/_base.gd"`, with `test_*` methods and optional `before_each`/`after_each`).
  Add a suite when you add a system; add assertions when you add behavior. `tools/tests/` also
  holds shared test infrastructure that isn't itself a suite — e.g. `battle_harness.gd` (see
  "Testing infrastructure: BattleHarness" above) — safe because discovery only picks up
  `test_*.gd` filenames.
- **`doctor.gd`** — project health check: file-named directories, unset/missing `main_scene`, and any
  `.gd`/`.tscn`/`.tres` that fails to load.
- **`hooks/`** — git hooks. `pre-commit` blocks committing directly on `main`; `pre-push` imports then
  runs doctor + tests. Install once per clone: `git config core.hooksPath tools/hooks`. Bypass with
  `--no-verify`; point at Godot with `GODOT=... git push`.

Manual/simulation tools:
- **`simulate_battle.gd`** — headless Monte Carlo battle simulator via `BattleHarness`; see above.

PR helper:
- **`open_pr.sh`** — `tools/open_pr.sh "<title>" <body.md> [base]` opens (or finds) the PR for the
  current branch. Wraps everything in the escaping recipe below. **`escape_json.pl`** is its JSON escaper.

**Always run `run_tests.gd` (and `doctor.gd`) before opening a PR** — the pre-push hook enforces this.

## Git / PR workflow

Solo-dev flow: **every change goes through a feature branch + PR that targets `main`.**
Do not commit on `main` (a `pre-commit` hook blocks it) — work only ever lands on `main` by merging a PR.

**NEVER stack branches.** Always branch from `origin/main`, and every PR's base is **`main`** — never
base a feature branch on another unmerged feature branch. Stacking silently breaks merges: merging a
stacked PR lands its changes in the *intermediate* branch, not `main` (this bit us once — three PRs all
showed "merged" but only the bottom one reached `main`). If feature B needs feature A that isn't merged
yet, **merge A's PR into `main` first**, then branch B from the updated `origin/main`. `open_pr.sh` warns
when the base isn't `main`.

**One feature at a time:**

1. Sync main, then branch: `git checkout main && git pull` then `git checkout -b feat/<short-name> origin/main`.
2. Keep PRs **additive**; don't clobber `.gitignore` or delete unrelated files. The repo `.gitignore`
   already ignores `.godot/` — never commit that cache. Commit Godot's `*.import` and `*.uid` sidecars.
3. Commit with a descriptive message. End the message with:
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
4. `git push -u origin feat/<short-name>` (the `pre-push` hook runs doctor + tests).
5. Open the PR with `open_pr.sh` (base defaults to `main`). End the PR body with:
   `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
6. **Merge it into `main`, then go back to step 1** for the next feature (sync main first, so the next
   branch includes what you just merged).

### Creating the PR — escaping recipe (IMPORTANT, avoids body mangling)

**Preferred:** just run `tools/open_pr.sh "<title>" <body.md> [base]` — it does all of the below
(push, escape, POST, and prints the PR URL) and refuses to submit an empty body. The manual recipe
here is what that script runs, and the fallback if it's unavailable.

`gh` is **not installed**. Create/patch PRs via the GitHub REST API using the git-cached credential.
Several MSYS/curl hazards bit us before; all are avoided here:

- **Do NOT JSON-escape the body with an inline `perl -e '...'` one-liner.** The shell/MSYS mangle the
  backslashes and the body silently comes out empty. Use a **perl script file** instead.
- **Send the JSON from a file: `curl --data-binary @payload.json`, never inline `-d "$PAYLOAD"`.** When
  native `curl.exe` rebuilds its command line, the JSON's embedded quotes get mangled → HTTP 400
  "Problems parsing JSON". (The payload can be valid JSON on disk yet still be corrupted on the argv.)
- **Read the response from stdout (`-w`), not `-o /tmp/...`.** With `MSYS_NO_PATHCONV=1` set, mingw
  curl can't write to a POSIX temp path. Use a *relative* path for the `@payload.json` it reads.
- **The `ref:path` git syntax** (e.g. `git show origin/main:.gitignore`) and any URL/arg containing a
  colon get mangled by MSYS path conversion. Prefix the command with `MSYS_NO_PATHCONV=1`.

Steps (run from the repo root in the Bash tool):

```bash
# 1. Write the PR body to a file, e.g. pr_body.md (plain Markdown, real newlines).

# 2. Write this JSON-escaper ONCE to a file, e.g. escape_json.pl:
#    undef $/;
#    my $s = <>;
#    $s =~ s/\\/\\\\/g;   # backslashes first
#    $s =~ s/"/\\"/g;     # quotes
#    $s =~ s/\r//g;       # strip CR
#    $s =~ s/\n/\\n/g;    # newlines -> \n
#    $s =~ s/\t/\\t/g;    # tabs -> \t
#    print $s;

# 3. Build the payload (title has no special chars; %s only fills the escaped body):
BODY=$(perl escape_json.pl pr_body.md)
printf '{"title":"<title>","head":"feat/<short-name>","base":"main","body":"%s"}' "$BODY" > payload.json

# 4. Fetch the cached token (used only here; never echo it) and POST:
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null | sed -n 's/^password=//p')
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/LincGriffin/GriffinsGame/pulls \
  -d @payload.json -w "\nHTTP_STATUS:%{http_code}\n"
# 201 = created. The response JSON's "html_url" is the PR link.
# To fix/update a body later: same call but -X PATCH to .../pulls/<number> with {"body":"..."}.
```

Verify afterward: `printf '%s' "$BODY"` should be several KB, and the payload file should start with
`{"title":"..."` and end with `..."}`. If the body looks empty (payload only ~100 bytes), the escape
step failed — check you used the **script file**, not an inline one-liner.

## Housekeeping

- A GDScript file cannot share a path with a folder. If a `scripts/<name>.gd` **directory** exists
  (an accidental `mkdir`), remove the empty dir before creating the real file.
- If the local `main` is still the initial orphan (no upstream), reconnect it once:
  `git checkout main && git branch --set-upstream-to=origin/main main && git pull`. Thereafter just
  `git checkout main && git pull` after each merge before branching the next feature.
