# Audio

Drop sound files in **`sfx/`** or **`music/`**, named after the event/track id, and they play
automatically — no code or data changes, no generator to re-run.

Audio is **optional**: any event without a matching file is a silent no-op (nothing plays), so
the game always runs. You can add sounds one at a time, in any order.

## Spec

| | |
|---|---|
| **Filename** | `<id>.ogg`, `<id>.wav`, or `<id>.mp3` — exactly the ids in the tables below, lowercase |
| **Format** | **`.wav`** for short one-shot SFX (zero decode latency — snappier response). **`.ogg`** (Vorbis) for music (compressed, good for longer loops). `.mp3` also works if that's what you have |
| **Sample rate** | 44.1 kHz |
| **Channels** | Mono for SFX (no positional audio in this game); stereo is fine for music |
| **Length** | SFX: roughly 0.1–2 seconds. Music: loops of 30 seconds or more work well |
| **File size** | SFX: well under 1 MB each (short + mono keeps these tiny). Music: a few MB per track is fine |
| **Loudness** | Normalize peaks to around **−3 to −6 dB** so overlapping SFX don't clip, and keep relative levels consistent across files (one sound shouldn't be twice as loud as the rest) |
| **Looping** | Handled automatically by `SoundManager` (it replays the track when it finishes) — no per-file loop point or import setting needed |

## After adding files

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import
```

That's it. `scripts/data/sfx_library.gd` / `music_library.gd` look each file up by id at runtime.

## Where to get sounds

CC0 / royalty-free sources work well here — no need to match a specific art style the way the
tile art did:
- [Kenney.nl](https://kenney.nl/assets?q=audio) — UI and RPG-flavored SFX packs, all CC0
- [freesound.org](https://freesound.org/) — filter by CC0
- [OpenGameArt.org](https://opengameart.org/) — filter by license

## Sound effects (`sfx/`)

| `id` (filename) | Plays when |
|---|---|
| `step` | The player completes one tile of movement |
| `blocked` | The player bumps into a wall |
| `ui_select` | A menu click (title screen, starter-select card) |
| `ui_hover` | The mouse enters a button (starter cards, battle command/switch buttons, Settings' Close) |
| `encounter` | A wild or elite battle begins |
| `encounter_boss` | The Hydra battle begins |
| `move_attack` | The active monster uses an `attack` move |
| `move_guard` | The active monster uses a `guard` move |
| `move_heal` | The active monster uses a `heal` move |
| `move_drain` | The active monster uses a `drain` move |
| `move_buff` | The active monster uses a `buff` move |
| `enemy_hit` | The enemy lands a hit on the active monster |
| `faint` | A party monster is knocked out |
| `switch` | The player voluntarily swaps in another monster (costs the turn) |
| `flee` | A successful flee from battle (hidden for now — `Battle.FLEE_ENABLED`) |
| `victory` | The enemy is defeated |
| `defeat` | The whole party is wiped (run over) |
| `node_heal` | A heal-fountain node triggers |
| `node_powerup` | A power-up node triggers |
| `node_room` | A treasure-room node triggers |
| `node_teleport` | A teleport node triggers |
| `win` | The run is won (the Hydra is vanquished) |
| `lose` | The run is lost (game-over banner) |

## Music (`music/`, loops)

| `id` (filename) | Plays during |
|---|---|
| `title` | The title screen |
| `dungeon` | Walking the dungeon between fights |
| `battle` | A normal or elite battle |
| `battle_boss` | The Hydra fight |

Adding a new event/track id anywhere in the game is a two-step process: call
`SoundManager.play_sfx("your_id")` (or `play_music`) from the relevant script, then drop a
matching file in here — in either order.
