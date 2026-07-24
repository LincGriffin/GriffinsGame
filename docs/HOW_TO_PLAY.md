# How to play GriffinsGame

A short, text-only guide. GriffinsGame is a **roguelike monster-collector**: you walk a branching
dungeon, fight monsters one-on-one, and **recruit the ones you defeat** into your party. Runs are
short and disposable — **nothing carries over between runs**.

---

## The goal

Reach the **boss room at the top of the dungeon and defeat the boss**. You lose only if your **whole
party is knocked out**.

---

## Controls

| Key | Does |
|---|---|
| **W A S D** or **arrow keys** | Walk one tile (hold to keep walking) |
| **Mouse click** | Dismiss the title screen; press buttons in menus and battle |
| **Escape** | Open / close **Settings** (music + sound-effect volume). Works anywhere |
| **R** | Start a fresh run — only after **GAME OVER** or **YOU WIN** |
| **F3** | Toggle the developer overlay (FPS, party HP, current tile) |

Developer cheats, while the F3 overlay is open: **H** toggles hold-to-move, **K** sets the whole
party to 1 HP (for testing).

---

## Starting a run

1. Click the **title screen** to begin.
2. **Pick one of three starter monsters.** Each card shows its portrait and stats (HP / ATK / DEF).
3. That single monster is your whole party — so the first fight is genuinely dangerous. **Getting a
   second monster quickly is your first goal.**

Your chosen starter gets a small one-time stat boost, since it has to fight alone early on.

---

## Exploring the dungeon

The dungeon is a set of **rooms joined by corridors**, laid out in rows from the entrance at the
bottom to the boss at the top.

- Walk into a room to **trigger whatever is in it**. Each room shows a marker in its middle telling
  you what it is.
- The dungeon is **fully open** — you can wander and **backtrack freely**, and you can reach every
  room if you want to. Clearing a room turns its marker off and it becomes a plain walk-through.
- There's no time pressure, but every fight costs HP, and **HP does not refill on its own**.

### What's in the rooms

| Room | What happens |
|---|---|
| **Battle** | A wild monster fight. Win → you **recruit that monster** |
| **Elite** | A much tougher fight. Win → recruit it **and fully heal your party** |
| **Boss** | The final fight. Win → **you win the run** |
| **Heal** | Your whole party is restored to full HP |
| **Power-up** | Choose **1 of 3 upgrades** and give it to a monster (see below) |
| **Treasure** | A chest — **+max HP for every monster** in your party |
| **Teleport** | Warps you a couple of rows further up the dungeon |

---

## Battles

Fights are **one monster against one monster**, turn by turn.

1. If you have more than one living monster, you **choose which one leads**.
2. **Your monster always acts first**, then the enemy answers.
3. Pick a **move** from your monster's list each turn. The fight ends when one side drops.

### Move types

Moves are about **effect**, not elements — there's no type chart.

| Move type | What it does |
|---|---|
| **Attack** | Straightforward damage |
| **Heavy / Slam** | Higher-damage attacks |
| **Guard** | Halves the next hit you take, and your next attack hits harder |
| **Evade** | The next hit against you does **no damage at all**, and your next attack hits harder |
| **Reflect** | You still take the hit, but the attacker takes the **same damage back** |
| **Heal** | Restores some of your own HP |
| **Drain** | An attack that heals you for part of the damage dealt |
| **Buff** | Raises your attack for the rest of the battle |
| **Stun** | An attack that **may** also make the enemy lose its next turn |
| **Reckless** | A heavy hit that also **hurts you** a little |

Guard, Evade and Reflect are **one-shot stances**: they apply to the very next hit and then wear
off. A hit that's evaded or reflected ignores the attacker's extra effects (no drain-heal, no stun,
no recoil).

### Switching and losing monsters

- **Switch** swaps in another living monster. It **costs your turn** — the enemy still attacks.
- If your active monster is knocked out, you **switch in another one** and the fight continues.
- **A knocked-out monster is gone for the rest of the run (permadeath).**
- If you have **no monsters left**, the run ends.

---

## Building your party

### Recruiting

Winning a wild or elite fight **automatically recruits** that monster at full HP. Your party holds
up to **5** monsters.

### Merging (when your party is full)

If you win a fight while already holding 5 monsters, you're offered a **merge**:

- Pick **two** of your monsters to **fuse into one**, freeing a slot — the new monster is then
  recruited.
- The fused monster takes the **better of each stat** from its two parents plus a small bonus, and
  **combines both their movesets**.
- Certain pairs fuse into a **specific, different monster**; every other pair becomes a generic
  "Fused" version of the stronger parent.
- You can also just **Skip** — keep your party as-is and don't recruit.

### Power-ups

A power-up room offers **3 upgrades**; you pick one and **choose which monster gets it**:

- **+Max HP** (and heals that much)
- **+Attack**
- **+Defense**
- **Learn a new move**

---

## Winning and losing

- **Defeat the boss → YOU WIN.**
- **Lose your last monster → GAME OVER.**

Either way, press **R** to start a completely fresh run with a new map and a new starter choice.
Nothing — monsters, upgrades, HP — carries over.

---

## Tips

- **Recruit early.** One monster is fragile; a second one is your safety net.
- **Spend HP, not lives.** A monster at low HP is still useful — switch it out before it dies,
  because losing it is permanent.
- **Detour for heal and treasure rooms.** The map is open, so you can go get them before pushing up.
- **Guard and Evade aren't wasted turns** — they blunt a big hit *and* make your next attack hit
  harder.
- **Save the elites for when you're healthy.** They hit hard, but they fully heal your party on a
  win, so clearing one at the right moment is a big swing.
- **Think before merging.** Fusing frees a slot and makes one stronger monster, but you go from two
  bodies to one — and bodies are what keep a run alive.
