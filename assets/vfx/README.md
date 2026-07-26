# Move visual effects (`vfx/`)

Per-move visual effects, referenced by id. A move (`MoveData.vfx`, edited in the Moves dock or
`tools/gen_moves.gd`) names an effect here; `battle.gd` plays it at the target/caster when the move
is used. Two moves **share** an effect by naming the same id; you **swap** one by pointing the move
at a different id or dropping a new file at the same path.

Effects are **optional**: a blank or missing `vfx` id is a no-op — the move still gets its built-in
flash / shake / floating-number feedback — so the game always runs.

## Spec

| | |
|---|---|
| **Filename** | `<id>.tscn` (or `.scn`) — the id in a move's `vfx` field, lowercase snake_case |
| **Root** | A **`Node2D`** — battle positions it at the anchor's screen center |
| **Particles** | Use **`CPUParticles2D`**, not `GPUParticles2D`: the project renders with **GL Compatibility**, where GPU particles are unreliable |
| **Self-contained** | Embed sub-resources — a scene that references external files by path won't survive being copied/shared. The generated effects are self-contained |
| **Lifetime** | Short (~0.3–0.7 s). Should **self-free** when done (attach `scripts/vfx_oneshot.gd`, which fires a one-shot burst on spawn and frees itself). battle.gd also safety-frees after `VFX_MAX_TIME` (~1.2 s), so a scene that forgets can't leak |
| **Input** | Purely cosmetic — must not capture input (it's added under a `MOUSE_FILTER_IGNORE` holder) |

## Shipped effects (built by `tools/gen_vfx.gd`)

| `id` | Look | Example move(s) |
|---|---|---|
| `slash` | cyan-white radial burst | `strike`, `heavy` (**shared**) |
| `impact` | heavy white burst, falls | `slam`, `shock`, `reckless_swing` |
| `heal_sparkle` | green rising sparkles | `mend` |
| `buff_glow` | gold expanding ring | `focus` |
| `drain_wisp` | purple wisps drifting up | `drain` |

Edit the `EFFECTS` table in `tools/gen_vfx.gd` and re-run it to rebuild these, or author your own
scene by hand following the spec above.

## After adding / editing a file

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import
```

`scripts/data/vfx_library.gd` looks each effect up by id at runtime (memoised, null-safe). To see
them, run the screenshot tool's `vfx` shot (needs a real window — **no** `--headless`):

```bash
"$GODOT" --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/screenshot.gd -- vfx
```

Audio for a move works the same way — set `MoveData.sfx` to a `sfx/<id>` sound (blank falls back to
the per-kind `move_<kind>` sound). See `assets/audio/README.md`.
