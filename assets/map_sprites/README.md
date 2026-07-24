# Monster map sprites

Optional overworld art for a monster, by convention: `assets/map_sprites/<id>.png`, looked up at
runtime by `scripts/data/map_sprites.gd` (`MapSprites`). Drawn over a battle/elite/boss room's
marker tile by `dungeon_view.gd`, scaled to the **64px** tile. A monster with no file falls back to
the generic per-type gem marker, so these are optional.

## Spec

| | |
|---|---|
| **Filename** | `<monster id>.png` — the monster's id (its `.tres` name in `assets/data/monsters/`), lowercase |
| **Size** | **≤ 256px on the longest side.** It renders at 64px, so anything bigger is wasted repo weight |
| **Format** | PNG, transparent background preferred |

## Keep them small (masters vs. committed copies)

Rule of thumb for all committed art: **`reference/` holds full-res masters (local, gitignored);
`assets/` holds small, game-ready copies (committed).** Drop the original into
`reference/source_art/monsters/<id>.png`, copy it here, then shrink it:

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/gen_downscale_sprites.gd
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import
```

`gen_downscale_sprites.gd` caps every PNG here at 256px in place (Lanczos, aspect preserved) and
skips ones already small — safe to re-run any time you drop a new full-size sprite in.
