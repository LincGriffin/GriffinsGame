# Map node sprites

Overworld art drawn on a map node's **marker tile**, by convention: `assets/node_sprites/<node
type>.png`, looked up at runtime by `scripts/data/node_sprites.gd` (`NodeSprites.for_type`).

| `<type>` (filename) | Node | Shipped art |
|---|---|---|
| `heal.png` | heal fountain | a "+" icon |
| `powerup.png` | power-up | a gold treasure chest |
| `room.png` | treasure room | a wooden chest |
| `teleport.png` | teleport pad | a generated violet rune pad |
| `battle` / `elite` / `boss` | encounters | *(none — these use the monster's own map sprite)* |

## How the art is chosen

`dungeon_view.gd::_paint_node_overlay` draws the **most specific** art a room has:

**monster map sprite** (`assets/map_sprites/<monster id>.png`, battle/elite/boss only)
→ **node sprite** (this folder)
→ the generated gem **marker tile** (always present, so nothing is ever blank).

## Swapping any of these — a one-file drop

Drop a PNG named after the node type in here and re-import. No code, no data, no generator:

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --import
```

Recommended ≤ 96px on the longest side (they render on a 64px tile); PNG with transparency.
Deleting a file simply falls back to the gem marker.

## Regenerating the shipped set

`tools/gen_node_sprites.gd` rebuilds them: it copies + downscales from the local third-party pack
in `assets/thirdparty/` and procedurally draws anything the pack lacks (the teleport pad). Edit its
`SOURCES` table to point at different pack files, then:

```bash
"$GODOT" --headless --path "C:\\Users\\Dad\\GriffinsGame" --script res://tools/gen_node_sprites.gd
```

> `assets/thirdparty/` is **gitignored** — the Spirit Claw license permits using and modifying the
> art in a game but not redistributing/repackaging the pack, so only these few derived sprites are
> committed. The generator needs the pack present locally; the game does not.
