# Limus Lab — scenes and scripts explained

Godot 4.2+ (tested on 4.3). Open `project.godot`, press F5. The game starts in `scenes/Main.tscn`.

## How the pieces fit

```
Main.tscn  (game.gd)
├── World                ← the current room scene is placed here
│   └── Room_X.tscn      (room.gd)
│       ├── Background / Ground / Platforms / Acid / Decor   TileMapLayers (lab tiles at 2x)
│       ├── Hazards      AcidPool.tscn per acid pit
│       ├── Props, Signs, Spawns, PlayerSpawn, BossSpawn
│       ├── ExitDoor     ExitDoor.tscn
│       └── Actors       Player.tscn (moved in by game.gd), Enemy.tscn, Boss.tscn,
│                        Projectile.tscn, Pickup.tscn, Effect / Ghost / DamageNumber
├── HUD                  HUD.tscn (hud.gd)
├── Fader                black ColorRect used for every fade
└── InventoryScreen.tscn (inventory.gd)   ← only while the Lab Kit is open
```

Room order (26 rooms, listed in `Main.tscn` → `rooms`):

| Floor | Chemical (enemies & pits) | Weak to | Rooms | Boss |
|---|---|---|---|---|
| 1 The Acid Vats | Acid (green acid) | Base | Tutorial + 5 | The Corrosion Core |
| 2 The Fuel Furnace | Fuel (burning orange fuel) | Foam | 5 | The Furnace Ogre |
| 3 The Foam Works | Foam (white caustic foam) | Fuel | 5 | The Froth Colossus |
| 4 The Alkali Depths | Base (violet lye) | Acid | 5 | The Alkaline Tyrant |
| Final: The Prime Reactor | cycles all four | changes | 1 | **The Prime Catalyst** |

Clearing a room unlocks its door; touching the door fades to black, swaps in the next room scene and fades back in. Leaving a floor's boss room shows the **LevelUpScreen** pop-up first.

**Levelling:** after every floor Limus gains a level: +30 max HP, +25% slash & bubble damage, +25 stamina (one more dash) and +2 stamina regen, and is fully healed. Enemies grow too (HP ×1.4 / ×1.8 / ×2.2 and +3 / +6 / +9 damage on floors 2–4), so your levels roughly keep pace, and slotting the floor's weakness chemical (×2 damage) is what tips each floor in your favour. Every room starts calm (waves begin after you walk ~7 tiles in), so you can open the Lab Kit and swap chemicals at the entrance.

---

## Autoload

### `scripts/chem.gd` (autoload name **Chem**)
The game's shared rule book and helper box, available everywhere as `Chem`.
- **Chemistry data:** the four chemicals (Acid, Base, Fuel, Foam), their colours and weaknesses, and `multiplier()`. A weakness gives ×2 damage; the same chemical as the target gives ×0.5.
- **Floors:** `FLOORS` holds each floor's name, chemical, hazard and background tint, three themed enemy skins `[sprite, tint, name]` and the boss `[sprite, tint, name, scale]`. Difficulty comes from `enemy_hp_mult()`, `enemy_dmg_bonus()` and `boss_hp()`; the level-up rewards are `LV_HP`, `LV_DMG`, `LV_STAMINA` and `LV_REGEN`.
- **Item data:** the 7 `CATALYSTS`, the 5 `MATERIALS` (reagent effects), `LOOT_HEAL` (HP healed per pickup), `DROPS` (which enemy drops what) and `ABILITIES`.
- **Input map:** binds every key and mouse button in code (move, jump, dash, slash, throw, inventory, restart).
- **Helpers:**
  - `fx()` spawns `Effect.tscn`.
  - `afterimage()` and `corpse()` spawn `Ghost.tscn`.
  - `damage_number()` spawns `DamageNumber.tscn`.
  - `shake()` asks `game.gd` for camera shake.
  - `hitstop()` briefly slows time on big hits.
  - `hud_msg()` and `hud_toast()` print on the HUD.
  - `room()` returns the current room.
  - `icon()` loads an item icon.

## Game flow

### `scripts/game.gd` — `scenes/Main.tscn`
The conductor.
- `rooms` (exported): the play order of all 26 room scenes.
- Leaving a room with `floor_end` runs `_floor_complete()`: fade to black → `player.level_up()` → show `LevelUpScreen.tscn` → wait for Continue → load the next floor. After the final boss the same pop-up becomes the victory card (R to play again).
- Creates Limus **once** from `Player.tscn`, then moves that same node from room to room, so HP, overheal, materials and build carry over.
- `_go_to_room(i)`: fade out → free the old room → instance `ROOMS[i]` → put Limus on its `PlayerSpawn` → set camera limits → fade in → `room.start()`.
- **Lab Kit:** TAB/I opens it only when `room.enemies_alive() == 0`; otherwise the HUD says "sealed while enemies remain".
  - Opening pauses the world, fades to black, adds `InventoryScreen.tscn` and fades in. Closing reverses it.
  - `Main` runs with `PROCESS_MODE_ALWAYS` and `World` is pausable, so fades and the Lab Kit keep running while the world is frozen.
- Owns camera shake (`add_shake`), the death screen and the R-to-restart.

### `scripts/room.gd` — every `scenes/rooms/Room_*.tscn`
One room's rules. Exported settings, visible in the Inspector: `room_title`, `tutorial`, `boss_room`, `waves` (e.g. `[["tank","tank"],["tank","annoying"]]`), `sub_boss`, `size_px`, `floor_y`, `floor_i` (the theme and difficulty), `floor_end` (last room of a floor), `start_x` (waves begin when Limus walks past it).
- `start()` begins the room:
  - **Tutorial:** waits for the training skeletons already placed in `Actors`.
  - **Fight rooms:** spawn each wave at the `Spawns/Ground*` markers, with flyers at `Spawns/Air*`, then the sub-boss on the marker farthest from Limus.
  - **Boss room:** spawns `Boss.tscn` at `BossSpawn`.
- When nothing is left, `_clear()` unlocks the door. Touching the door emits `exit_reached`, which `game.gd` turns into the next room.
- `enemies_alive()` is used for the Lab Kit lock. `spawn_drop()` creates `Pickup.tscn`. `spawn_minion()` is used by the boss.

### `scripts/door.gd` — `scenes/rooms/parts/ExitDoor.tscn`
A lab door (hospital2 tiles).
- **Locked:** red lamp, barred grate in front.
- **`unlock()`:** the grate slides up and fades, the lamp turns green, and a bobbing "EXIT →" appears.
- The first time Limus touches it afterwards, it emits `entered`.

### `scripts/hazard.gd` — `scenes/rooms/parts/AcidPool.tscn`
The hurt zone over an acid pit, with rising bubbles. `size_px` is exported, so every pit sizes itself. Anything overlapping calls `player.acid_contact()`: 10 damage and a bounce out. The visible acid is the room's `Acid` TileMapLayer.

## Characters

### `scripts/player.gd` — `scenes/actors/Player.tscn`
Limus, a light-blue slime with white eyes (your Mini Slime sheets).
- **Nodes:** `Sprite` (AnimatedSprite2D using `frames/limus.tres`), `Shape`, `Bubbles` (hydrogen particles), `Camera`.
- **Movement:** walk, coyote-time jump that peaks at **exactly 2 tiles** (`jump_v` includes a half-step correction), and dash (4 per full stamina bar, 15/s regen).
- **Slash:** 124 px reach, a travelling crescent, hit-stop and shake.
- **Slime bubble:** costs 7 HP; damage 3.5 × build multipliers. It bounces once off the world (+30%) and ricochets up to 3 times between enemies.
- **Health:** 100 HP plus up to 50 overheal. Damage drains overheal first. Loot heals, and any excess becomes overheal.
- **Build:** `apply_build()` recomputes every stat from chemical + catalyst + 3 reagents. `available()`, `collect()` and `heal()` serve the Lab Kit and pickups.
- **Animation:**
  - Idle, run, jump, fall, land, attack, dash, hurt and death.
  - Squash and stretch, dash afterimages, and a faint-red flush when hurt.
  - Death plays your own burst-apart sheet.

### `scripts/enemy.gd` — `scenes/actors/Enemy.tscn`
`kind`, `subboss` and `floor_i` are exported. `floor_i` picks the skin (sprite, tint, name) and the chemical from `Chem.FLOORS`, and scales HP and damage. The behaviour comes from `kind`, so each floor gets 3 themed variants of the same 3 roles (12 enemy types in total):

| kind | Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|---|
| tank (hops 2 tiles) | Acid Slime | Cinder Slime | Froth Slime | Lye Slime |
| annoying (flies) | Etch Imp | Ember Imp | Bubble Imp | Alkali Imp |
| ranged (lobs) | Vitriol Shaman | Flare Grunt | Lather Skeleton | Lye Necromancer |
 The script loads `frames/<kind>.tres` and resizes the scene-local `Shape`.
- **tank:** the muddy slime. It **hops 2 tiles high** toward Limus and checks the landing spot so it doesn't hop into acid. Its sub-boss telegraphs, then leaps.
- **annoying:** an imp. Flies, dives and retreats. Its sub-boss fires radial bursts.
- **ranged:** an orc shaman. Keeps its distance and telegraphs before lobbing acid (three lobs as a sub-boss).
- **dummy:** a training skeleton (tutorial).
- **All kinds:**
  - **Spawn:** they pop out of the floor.
  - **When hit:** a sound-free hit flash, sparks and knockback, plus a damage number.
  - **On death:** a splat, then the room drops loot.

### `scripts/boss.gd` — `scenes/actors/Boss.tscn`
One script for every boss. The room sets `floor_i`, which picks the sprite, tint, size, HP and name: the Corrosion Core (big demon), the Furnace Ogre (molten ogre), the Froth Colossus (white big zombie), the Alkaline Tyrant (violet ogre, larger) and the Prime Catalyst.

- **Final boss (Prime Catalyst):** ×3 size, 360 HP. `_set_chem()` switches its chemical every 7 s (5 s in phase 2) and announces which chemical it is now weak to; it also fires denser bullet fans.
- Hovers and telegraphs each attack: acid fan, acid rain, summoning imps, or a dive-slam that leaves afterimages and shakes the screen.
- Gets faster below 50% HP.
- Dies in a chain of explosions and drops the Corrosion Heart.
- The room supplies `arena` and `floor_y`.

### `scripts/projectile.gd` — `scenes/actors/Projectile.tscn`
Used for both the player's slime bubbles and enemy acid globs.
- **Moving:** each frame a ray finds walls, floors, ceilings and platforms (giving the surface normal for bounces); the `Area2D` overlap finds enemies or Limus.
- **Bounce:** the first world hit reflects the bubble, adds +30% damage, squashes it and flashes it.
- **Ricochet:** an enemy hit deals damage, then `_ricochet_to()` launches a ballistic arc (0.45 s) toward the nearest enemy not yet hit, up to 3 times. With no target left it explodes with area damage.

### `scripts/pickup.gd` — `scenes/actors/Pickup.tscn`
Loot from a kill.
- It ray-casts for the floor, pops out spinning, bounces, bobs and sparkles.
- It drifts toward Limus when he is close. On touch, `player.collect()` stores the material and heals him, and a HUD toast appears.

### `scripts/level_up.gd` — `scenes/ui/LevelUpScreen.tscn`
The pop-up between floors, drawn above the black fade.
- "FLOOR N CLEARED · LEVEL UP! Lv a → Lv b", then each stat row counts up from the old to the new value with the gain beside it (Max HP, slash damage, bubble damage, stamina, regen), then "HP and stamina fully restored".
- A briefing for the next floor: its chemical, what that chemical is weak to, and a reminder to swap the flask in the Lab Kit. Before the final room it explains the cycling Prime Catalyst instead.
- Continue with Space / Enter / the button. In final mode it is the victory card and R restarts.

## Effects

| Script | Scene | What it does |
|---|---|---|
| `scripts/effect.gd` | `scenes/fx/Effect.tscn` | AnimatedSprite2D that plays a `frames/fx_*.tres` once (explosions, slashes, sparks), then frees itself |
| `scripts/ghost.gd` | `scenes/fx/Ghost.tscn` | Frozen copy of a sprite frame: `"fade"` for afterimages, `"splat"` for death splats |
| `scripts/damage_number.gd` | `scenes/fx/DamageNumber.tscn` | Popping, floating damage text. Weakness hits are bigger and yellow |

## UI

### `scripts/hud.gd` — `scenes/ui/HUD.tscn`
- Draws the HP bar (with the gold overheal extension and a white damage trail) and the stamina bar (with dash markers).
- Shows the chemical/catalyst line, the Lab Kit status, the room name, centre messages (they pop in) and pickup toasts.
- Shows the boss bar while the boss is alive.

### `scripts/inventory.gd` — `scenes/ui/InventoryScreen.tscn`
The Lab Kit, shown after a fade.
- **`Scenery`:** Stringstar `background_0`, the small tree (left) and big tree (right) with the ground strip joining them, and vines hanging from the top (they sway). All are regions of the Stringstar `tileset.png`.
- **`Kit`:** the panel in the gap between the trees:
  - ability cards with live stats
  - the build (Chemical, Catalyst, 3 Reagents)
  - the Materials, Catalysts and Base Chemicals lists
  - a stats summary
  - the **Info** pop-up, which describes whatever is being dragged or hovered
- `on_drop()` and `clear_slot()` apply drag-and-drop to `player.build`, then `player.apply_build()`.

### `scripts/slot.gd` — `scenes/ui/Slot.tscn`
One drag-and-drop slot. Exported settings: `role` (bag/build), `accepts` (chem/catalyst/material), `item_key`, `index`, `hint`. It uses Godot's `_get_drag_data`, `_can_drop_data` and `_drop_data`. Right-click empties a build slot, and slots grow on hover.

---

## Tools (run on your computer, not in the game)

| Tool | What it does |
|---|---|
| `tools/build_assets.py <packs folder>` | Copies or crops every image from your packs into `assets/`, and downloads the CC0 0x72 monster frames. Recolours Limus (light blue, white eyes, faint-red hurt). Nothing is drawn |
| `tools/make_rooms.py` | Writes `tools/rooms.json` for all 26 rooms. Floors 2–4 reuse the five fight layouts (mirrored on floors 2 and 4, with themed props, names, and one extra enemy per wave from floor 3), each ends in a boss arena, and the Prime Reactor comes last. Format: every room's tile layout as text (`#` lab metal, `=` slab, `~` acid, `P` spawn, `D` door, `g`/`a` enemy markers, letters for props) plus waves, sub-bosses and tutorial signs |
| `tools/build_scenes.gd` | `godot --headless -s tools/build_scenes.gd` generates `frames/*.tres`, `tiles/lab_tileset.tres` (with collision and one-way slabs) and every `.tscn` above from `rooms.json`. It auto-tiles the lab floors (caps, borders, undersides) and places doors, pits, props and markers |

You can now edit any scene directly in the Godot editor (paint tiles, move markers, change `waves` in the Inspector). Re-running `build_scenes.gd` **overwrites** the generated scenes, so pick one workflow: edit in Godot, or edit `make_rooms.py` and regenerate.
