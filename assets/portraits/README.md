# Monster portraits

Drop portrait art in **this folder**, named after the monster's `id`, and it appears
automatically in the starter-select cards and the battle screen.

Portraits are **optional**: any monster without a file falls back to its flat `tint` colour,
so the game always runs. You can add them one at a time.

## Spec

| | |
|---|---|
| **Filename** | `<monster id>.png` — exactly the ids in the table below, lowercase |
| **Size** | **256 × 256** (square) |
| **Format** | PNG. Transparent background preferred (the battle screen frames it in the monster's tint); a solid background also works |
| **Style** | Classic D&D monster-manual illustration — painted fantasy bestiary look, consistent across the set |
| **Framing** | Head-and-shoulders / bust, subject centred, filling most of the frame |

## After adding files

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import
```

That's it — no generator to re-run and no data to edit. `scripts/data/portraits.gd` looks
each file up by id at runtime.

## The roster (17)

| `id` (filename) | Monster | Role | Art |
|---|---|---|---|
| `chicken.png` | Cluckling | starter (tier 0) | painted |
| `slime.png` | Green Slime | starter (tier 0) | painted |
| `bat.png` | Cave Bat | starter (tier 0) | painted |
| `rat.png` | Sewer Rat | wild (tier 1) | painted |
| `skeleton.png` | Skeleton | wild (tier 1) | painted |
| `kobold.png` | Kobold Scrapper | wild (tier 1) | **placeholder** |
| `myconid.png` | Myconid | wild (tier 1) | **placeholder** |
| `wisp.png` | Marsh Wisp | wild (tier 1) | **placeholder** |
| `imp.png` | Ember Imp | wild (tier 1) | **placeholder** |
| `goblin.png` | Goblin | wild (tier 2) | painted |
| `spider.png` | Giant Spider | wild (tier 2) | painted |
| `cyclops.png` | Cyclops | wild (tier 2) | **placeholder** |
| `golem.png` | Stone Golem | wild (tier 3) | painted |
| `wraith.png` | Wraith | wild (tier 3) | painted |
| `gremlin_knob.png` | Gremlin Knob | **elite** | painted |
| `griffin.png` | The Griffin | **elite** | painted |
| `hydra.png` | The Hydra | **final boss** | painted |

The three starters (`chicken`, `slime`, `bat`) are the highest-value ones to do first — they
are the only portraits shown on the starter-select screen.

**Placeholders:** `kobold` / `myconid` / `wisp` / `imp` / `cyclops` currently use **stylized procedural
placeholders** (a framed creature drawn by `tools/gen_placeholder_monster_art.gd`) — recognizable
but *not* the painted style. Drop a real 256×256 painted PNG over any of them to replace it (then
`--import`); no code or data changes needed.

Each monster's `tint` colour (used for the fallback and for the battle frame) lives in the
`ROSTER` table in `tools/gen_content.gd`.
