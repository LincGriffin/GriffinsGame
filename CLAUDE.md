# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## Project

**GriffinsGame** — a 2D turn-based dungeon crawler in **Godot 4.7 (GDScript)**, targeting Windows.
Player moves tile-by-tile around an overworld; stepping on a monster tile triggers a
Pokémon/Final-Fantasy-style turn-based battle (separate scene/state). Goal: navigate the dungeon,
defeat enemies, reach and defeat a final boss.

Renderer: GL Compatibility. Physics: Jolt.

### Layout
- `scenes/{overworld,battle,ui}` — scenes. Overworld movement lives in `scenes/overworld/`.
- `scripts/` — GDScript. `player.gd`, `overworld.gd` implemented.
- `assets/{sprites,tilesets,audio}` — art/audio. Placeholder art is programmer-art, meant to be replaced.
- `autoload/` — singletons (none yet).
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
  (`#` wall, `.` floor, `M` monster, `P` start).

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
- `gen_art.gd` — placeholder PNGs · `gen_tileset.gd` — TileSet `.tres`
- `gen_scenes.gd` — packs `.tscn` · `gen_project.gd` — input map + main scene via `ProjectSettings`

Quality gates:
- **`run_tests.gd`** — headless test runner. Discovers `tools/tests/test_*.gd` suites (each
  `extends "res://tools/tests/_base.gd"`, with `test_*` methods and optional `before_each`/`after_each`).
  Add a suite when you add a system; add assertions when you add behavior.
- **`doctor.gd`** — project health check: file-named directories, unset/missing `main_scene`, and any
  `.gd`/`.tscn`/`.tres` that fails to load.
- **`hooks/pre-push`** — runs doctor + tests before every push. Install once per clone:
  `git config core.hooksPath tools/hooks`. Bypass with `git push --no-verify`; point at Godot with
  `GODOT=... git push`.

PR helper:
- **`open_pr.sh`** — `tools/open_pr.sh "<title>" <body.md> [base]` opens (or finds) the PR for the
  current branch. Wraps everything in the escaping recipe below. **`escape_json.pl`** is its JSON escaper.

**Always run `run_tests.gd` (and `doctor.gd`) before opening a PR** — the pre-push hook enforces this.

## Git / PR workflow

**Open a new PR for every new feature.** Do not commit feature work directly to `main`.

1. Branch from the remote's real history: `git checkout -b feat/<short-name> origin/main`
   (the local `main` may be an orphan with no commits — always base branches on `origin/main`).
2. Keep PRs **additive**; don't clobber `.gitignore` or delete unrelated files. The repo `.gitignore`
   already ignores `.godot/` — never commit that cache. Commit Godot's `*.import` and `*.uid` sidecars.
3. Commit with a descriptive message. End the message with:
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
4. `git push -u origin feat/<short-name>`
5. Open the PR (see recipe below). End the PR body with:
   `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

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
- The local `main` branch is currently an orphan (no commits, no upstream). After the first PR merges,
  reconnect it: `git checkout main && git branch --set-upstream-to=origin/main main && git pull`.
