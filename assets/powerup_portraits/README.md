# Power-up portraits & sprites

Optional art for power-ups, looked up by convention via `scripts/data/powerup_art.gd`:

| Slot | Path | Used as |
|---|---|---|
| **Portrait** | `assets/powerup_portraits/<id>.png` | the large card art in the power-up chooser |
| **Sprite** | `assets/powerup_sprites/<id>.png` | a smaller icon (fallback when there's no portrait) |

`<id>` is the power-up's id (its `.tres` filename in `assets/data/powerups/`).

Both are **optional**. The chooser (`scripts/powerup_select.gd`) picks the most specific art it has:
**portrait → sprite → the per-effect placeholder icon (`assets/upgrade_icons/`) → a flat `tint`
swatch**. So the game runs with no power-up art at all.

Add art either by **uploading in the Power-up Editor dock** (Browse buttons — copies the file to
the convention path) or by dropping a PNG in and running `--import`. Recommended size 256×256
(portrait) / 128×128 (sprite), PNG, square.
