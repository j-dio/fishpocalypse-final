# Fishpocalypse — Phase Tracker

_Living document. Update after every implementation session._
_Status values: `TODO` · `IN PROGRESS` · `DONE`_

---

## Phase 0 — Foundation `DONE`

**Goal:** Runnable empty project with correct settings, folder structure, input wiring, placeholder island, and lerp-follow camera.

### Checklist
- [ ] Project settings: renderer = Forward+ (via features array), window size 1280×720
- [ ] Low-res viewport pipeline: `stretch/mode="viewport"`, `scale_mode="integer"`, render at 640×360 scaled to 1280×720 (2×)
- [ ] Input map: `move_left` (A), `move_right` (D), `move_forward` (W), `move_back` (S), `fire` (LMB), `dodge` (Space), `swap_main` (Q), `swap_secondary` (E), `interact` (F), `open_inventory` (I)
- [ ] Folder structure: `autoloads/`, `scenes/`, `scripts/`, `resources/`, `assets/_placeholder/`, `ui/`
- [ ] `GameState` autoload skeleton — signals `day_started`, `night_started`, `wave_cleared`, `buff_day_reached`; Phase enum; `day_count` var
- [ ] `AudioManager` autoload skeleton — stub interface for `play_music`, `stop_music`, `play_sfx`, `crossfade_to`
- [ ] `Main.tscn` — root Node3D with Island, CameraRig, WorldEnvironment (default env), DirectionalLight3D
- [ ] `Island.tscn` — StaticBody3D ground (40×0.2×40) + CollisionShape3D + 3 crate props with collision
- [ ] `CameraRig.tscn` + `scripts/camera_rig.gd` — Camera3D at local (0,9,9) looks at rig center; lerp-follows target XZ; `set_target()` for Phase 2
- [ ] `project.godot` sets `config/run/main_scene="res://scenes/main.tscn"`

### Reminders
- Keep `assets/_placeholder/` clearly named; Phase 8 swaps them out
- **Camera angle updated**: isometric 45° diagonal, ~52° elevation, 60° FOV (Hades/Gungeon genre standard). `camera_offset` is `@export` on CameraRig — tweak live in the Inspector. Default `(7,13,7)`. Position is set by script in `_ready`, not the .tscn.
- Viewport is 640×360 (2× to 1280×720). Final PSX resolution lock (320×180 or 480×270) happens Phase 8

### Bugs
_None yet_

### Warnings
- `WorldEnvironment` in `main.tscn` uses a default `Environment` resource (no sky, no custom ambient). The editor may show a warning about missing sky — this is expected and resolved in Phase 1 when day/night stubs are wired.

---

## Phase 1 — Day/Night Core Loop `DONE`

**Goal:** `GameState` drives the cycle. DAY and NIGHT states are visually distinguishable (even with stubs). The buff-day trigger fires correctly.

### Checklist
- [ ] `GameState` state machine: `DAY`, `NIGHT`, `TRANSITION` states
- [ ] Day counter increments each full cycle
- [ ] `day_started` signal emitted on DAY entry
- [ ] `night_started` signal emitted on NIGHT entry
- [ ] `wave_cleared` signal triggers transition back to DAY (stub: manual trigger for now)
- [ ] `buff_day_reached` emitted on every 10th night (nights 10, 20, 30…)
- [ ] Environment-swap stub: DAY = warm ambient WorldEnvironment; NIGHT = dark/red WorldEnvironment (placeholders; final in Phase 8)
- [ ] Timed DAY duration (configurable, e.g. 60 s) before auto-transitioning to NIGHT
- [ ] Debug label in scene showing current state + day count

### Reminders
- Art hooks wired here intentionally — even stub colors reinforce the day/night contrast design decision
- Environment swap is a stub; the red sea shader and full palette land in Phase 8
- Debug keys: F1 = skip to night immediately, F2 = manually clear wave (back to day)

### Bugs
_None yet_

### Warnings
- `day_duration` and `transition_duration` on GameState are `@export` vars but the autoload is a plain script (no scene), so tune them directly in `game_state.gd` — not in the Inspector.

---

## Phase 2 — Player Foundation `TODO` _(CJ)_

**Goal:** Player moves, aims, and has HP/CP/SP stats that follow the regen rules. Camera follows them.

### Checklist
- [ ] `Player.tscn`: CharacterBody3D + placeholder Sprite3D (billboard, nearest filter)
- [ ] WASD/analog movement in the camera's local XZ plane
- [ ] Mouse or right-stick aim (player character faces aim direction)
- [ ] `Health` component (reusable node: current/max value, `take_damage()`, `heal()`, `died` signal)
- [ ] HP on Player via Health component; no passive regen
- [ ] CP stat: starts full; depletes on fire (Phase 3); recharges at rate over time
- [ ] SP stat: starts full; depletes on dodge (Phase 3); regenerates over time
- [ ] `CameraRig` now tracks Player's XZ position (lerp speed configurable)
- [ ] Player visible in scene, moves correctly relative to the fixed camera angle
- [ ] Player does not fall through Island

### Reminders
- `Health` component will be reused verbatim on enemies in Phase 4
- CP recharge rate and SP regen rate are `@export` — tune in Phase 9

### Bugs
_None yet_

### Warnings
_None yet_

---

## Phase 3 — Ranged Combat `TODO` _(CJ)_

**Goal:** Player fires fish weapons. CP/recharge/post-shot-delay are enforced. Dodge consumes SP. Weapon hot-swap works between main and secondary slots.

### Checklist
- [ ] `RarityTier` Resource class: `name`, `color`, `weapon_multiplier`, `shot_delay_multiplier`, `lure_multiplier`, `cost_multiplier`, `heal_multiplier`
- [ ] `RarityConfig` Resource class: `tiers[]` array of `RarityTier` (common → "???")
- [ ] `ProjectileData` Resource class: `owner_type` (PLAYER/ENEMY), `speed`, `damage`, `lifetime`, `sprite`
- [ ] `FishWeaponData` Resource class: `spawn_day`, `base_damage_per_shot`, `base_shot_delay`, `base_projectiles_per_shot`, `base_recharge_cost`, `rarity` (RarityTier), `projectile` (ProjectileData), `sprite_frames`, `sfx`
- [ ] At least 2 placeholder `FishWeaponData` `.tres` files (one common, one rare) for testing
- [ ] `CombatSystem` script on Player:
  - [ ] `fire()`: check CP ≥ `base_recharge_cost` → spawn Projectile(s) → deduct CP → start recharge timer + `base_shot_delay` timer
  - [ ] `dodge()`: check SP ≥ cost → apply dodge impulse → deduct SP
  - [ ] `swap_weapon()`: toggle active slot between main and secondary
- [ ] `Projectile.tscn`: Area3D, moves forward at `ProjectileData.speed`, applies `damage`, despawns on hit or `lifetime` timeout
- [ ] Placeholder test-dummy target in scene (static node with Health component); projectile deals damage + dummy emits `died`
- [ ] CP bar depletes and recharges visibly (debug label ok for now; HUD in Phase 7)

### Reminders
- `base_projectiles_per_shot` > 1 means spawning multiple Projectile instances at slightly fanned angles
- Recharge timer and `base_shot_delay` are separate: recharge = time until CP starts recovering; `base_shot_delay` = minimum time between shots regardless of CP

### Bugs
_None yet_

### Warnings
_None yet_

---

## Phase 4 — Enemy Pool & Spawn System `TODO` _(SEN)_

**Goal:** Three fish enemy types spawn at night, navigate to player, attack. Population scales over nights. Overkill drops fire.

### Checklist
- [ ] `EnemyData` Resource class: `hierarchy_tier`, `spawn_weight`, `base_hp`, `base_damage`, `base_speed`, `base_attack_delay`, `projectiles_per_shot`, `can_shoot`, `projectile` (ProjectileData), `sprite_frames`, `sfx`
- [ ] `.tres` files for NormalFish, TankyFish, ShootingFish (placeholder stats)
- [ ] `Enemy.tscn` base: CharacterBody3D + Health + billboard Sprite3D + NavigationAgent3D + state machine (`IDLE` → `CHASE` → `ATTACK` → `DEAD`)
- [ ] `NormalFish.tscn`, `TankyFish.tscn`, `ShootingFish.tscn` inherit/compose Enemy with their EnemyData
- [ ] ShootingFish fires `Projectile` toward player (uses `EnemyData.projectile`)
- [ ] Enemy deals damage to Player on melee contact
- [ ] `SpawnEnemySystem` node/autoload:
  - [ ] `SpawnContext` inner class: `hp_multiplier`, `damage_multiplier`, `speed_multiplier`, `spawn_rate_multiplier` — rebuilt once per wave from active buffs (O(B)), applied per enemy in O(1)
  - [ ] `BuildSpawnContext()`: iterate `ActiveBuffs`, accumulate `enemy_effects` + `spawn_effects` multipliers into `SpawnContext`
  - [ ] `GetPopulationTarget()`: `BasePopulation * (1 + current_night * 0.25) * cached_context.spawn_rate_multiplier`
  - [ ] `SpawnEnemy()`: weighted-random select from pool by `spawn_weight`, instantiate, apply `SpawnContext` multipliers
  - [ ] Enemies spawn at perimeter spawn points around island
- [ ] On enemy death:
  - [ ] Check overkill threshold → emit `overkilled` signal
  - [ ] `SpawnItemSystem.scatter_drop(position, loot_table)` called on death
  - [ ] Overkill: larger drop + visual explosion (placeholder particle)
- [ ] Navigation mesh baked on Island; agents path correctly to player
- [ ] `wave_cleared` fires when all enemies in the current wave are dead

### Reminders
- Enemy pooling (reusing instances vs free/new) is a Phase 9 optimization; use `queue_free()` for now
- NavigationRegion3D must be re-baked if the Island mesh changes in Phase 8

### Bugs
_None yet_

### Warnings
- Navigation bake may need re-running after any Island geometry change

---

## Phase 5 — Item & Inventory System `TODO` _(CJ)_

**Goal:** Items drop and scatter, player picks them up, inventory slots are populated, healing items restore HP, buffs apply on buff-days.

### Checklist
- [ ] `HealingItemData` Resource: `item_class` (I–IV), `base_heal_amount`, `use_delay`, `stack_limit`, `rarity` (RarityTier), `sprite`
- [ ] `FishingPoleData` Resource: `base_bar_size`, `base_lure_speed`, `base_lure_chance`, `rarity` (RarityTier), `sprite_frames` _(data class only — DIO populates `.tres` files in Phase 6)_
- [ ] `BuffData` Resource: `stackable`, `is_permanent`, `player_effects` (PlayerEffects), `weapon_effects` (WeaponEffects), `enemy_effects` (EnemyEffects), `spawn_effects` (SpawnEffects), `sprite`
- [ ] Buff effect classes (GDScript inner classes): `PlayerEffects` (`move_speed_multiplier`, `damage_taken_multiplier`), `WeaponEffects` (`damage_multiplier`, `shot_delay_multiplier`, `projectile_speed_multiplier`, `cost_multiplier`), `EnemyEffects` (`hp_multiplier`, `damage_multiplier`, `speed_multiplier`, `attack_delay_multiplier`), `SpawnEffects` (`fish_spawn_multiplier`, `enemy_spawn_multiplier`, `loot_spawn_multiplier`)
- [ ] `ItemsDB` Resource: `fish_weapons[]`, `healing_items[]`, `fishing_poles[]` — single source of truth for the loot pool
- [ ] `.tres` files: at least 2 HealingItems, 2 Buffs (placeholders); FishWeapon + FishingPole `.tres` files deferred to DIO (Phase 6)
- [ ] `ItemPickup.tscn`: RigidBody3D, holds an item Resource ref, collision pickup trigger
- [ ] `SpawnItemSystem`: `scatter_drop(origin, items[])` spawns ItemPickup nodes with random linear velocity + downward gravity
- [ ] `InventorySystem` script on Player:
  - [ ] Slots: `pole_slot`, `main_slot`, `secondary_slot`, `item_slot_1`, `item_slot_2`
  - [ ] Store arrays: `fish_weapons[]`, `healing_items[]`, `fishing_poles[]` (mirrors `ItemsDB` structure)
  - [ ] `pickup(item_resource)` routes to correct store/slot
  - [ ] `use_item(slot)` → HealingItem calls `player.health.heal(base_heal_amount * rarity.heal_multiplier)`; FishWeapon equips to active slot
- [ ] `BuffSystem` script on Player:
  - [ ] `apply_buff(buff_data)` accumulates multipliers from `player_effects` and `weapon_effects`
  - [ ] Active buffs tracked in `active_buffs[]`; permanent buffs persist
  - [ ] Weapon stat methods (`get_damage()`, `get_shot_delay()`, `get_cost()`) iterate `active_buffs` at call time
- [ ] `buff_day_reached` signal from GameState → spawn a `BuffData` pickup near player
- [ ] Playtest: enemy death drops healing item; player walks over it; HP restores correctly

### Reminders
- `use_item` on a FishWeapon should equip it to the active weapon slot (main or secondary depending on what's empty/held)
- `SpawnEnemySystem` reads `active_buffs` to rebuild `SpawnContext` — ensure `BuffSystem.active_buffs` is accessible via signal or getter

### Bugs
_None yet_

### Warnings
_None yet_

---

## Phase 6 — Fishing System `TODO` _(DIO)_

**Goal:** During DAY, player can fish. The minigame produces items into inventory. Fish unlocked by day count.

### Checklist
- [ ] Populate `ItemsDB` with all concrete `.tres` files:
  - [ ] `FishWeaponData` instances (N weapons, varied rarities and `spawn_day` thresholds)
  - [ ] `HealingItemData` instances (class I–IV)
  - [ ] `FishingPoleData` instances (normal, reinforced, fish pole variant)
- [ ] `FishingSystem` script: only active when `GameState` state == `DAY`
- [ ] `interact` input near water/dock → start fishing
- [ ] `FishingMinigame.tscn` (Stardew-style bar-catch UI):
  - [ ] Vertical bar, fish cursor moves erratically; player cursor controlled by button hold
  - [ ] Cursor speed/bar size driven by equipped `FishingPoleData` (`base_bar_size`, `base_lure_speed`)
  - [ ] Fill a progress meter while fish cursor is inside player cursor zone
  - [ ] Success → produce item; failure → nothing (or line snap animation)
- [ ] Fish pool filtered by `spawn_day ≤ GameState.day_count` — only eligible items from `ItemsDB` are catchable
- [ ] Catch probability influenced by `FishingPoleData.base_lure_chance * rarity.lure_multiplier`
- [ ] Produced item (FishWeaponData or HealingItemData or FishingPoleData) added to `InventorySystem` via `pickup()`
- [ ] Minigame cancels if DAY ends mid-fish (TRANSITION signal)

### Reminders
- `spawn_day` on `FishWeaponData` is the primary progression gate — tune thresholds in Phase 9
- `base_lure_chance` and `lure_multiplier` from `RarityTier` together control rare-fish probability

### Bugs
_None yet_

### Warnings
_None yet_

---

## Phase 7 — UI / HUD `TODO` _(TBD — GLS?)_

**Goal:** All player information is visible. Inventory can be opened and managed. Art-framing screens are in place.

### Checklist
- [ ] `HUD.tscn` (CanvasLayer always visible during gameplay):
  - [ ] HP bar (tied to Player.health)
  - [ ] CP bar (tied to CombatSystem.cp)
  - [ ] SP bar (tied to CombatSystem.sp)
  - [ ] Equipped weapon icon + name (main + secondary)
  - [ ] Item slot icons (item_slot_1, item_slot_2)
  - [ ] Day counter + phase label (DAY / NIGHT)
  - [ ] Night wave progress (enemies remaining / total)
- [ ] `InventoryUI.tscn` (opens/closes with `open_inventory` input):
  - [ ] Grid view of store arrays
  - [ ] Click to equip FishWeapon to main or secondary slot
  - [ ] Click to use HealingItem immediately
- [ ] Screen effects:
  - [ ] Hurt flash (red vignette on take_damage)
  - [ ] Low-HP persistent red vignette (below 25% HP)
  - [ ] Bloody camera gradual tint (below 10% HP)
- [ ] `IntroScreen.tscn`: shown on game start; artist-statement text + "Press to continue"
- [ ] `GameOverScreen.tscn`: shows nights survived; short fisherfolk-labor recap text; "Play Again" button
- [ ] All UI elements legible at the low-res SubViewport resolution

### Reminders
- Intro/game-over text is the arts course deliverable — write intentional copy here, not placeholder filler
- Low-res viewport may require integer-scaled UI or a separate CanvasLayer not affected by SubViewport

### Bugs
_None yet_

### Warnings
- UI scaling strategy needs validation: Control nodes in CanvasLayer may need `anchor` and `size` tuned for the integer-scaled window

---

## Phase 8 — Art & Audio Integration `TODO` _(TBD — GLS?)_

**Goal:** The game looks and sounds like Fishpocalypse. The arts course concepts are fully legible.

### Checklist

#### PSX Render Pipeline
- [ ] SubViewport resolution finalized and locked
- [ ] All sprite imports: `texture_filter = Nearest`, no mipmaps
- [ ] Optional: PSX vertex-jitter shader on environment mesh
- [ ] Optional: dithering post-process shader on SubViewport

#### Day Palette (Module 2 — warm/cutesy)
- [ ] `WorldEnvironment` day preset: warm ambient, soft directional light, mild fog
- [ ] Lo-fi ambient morning audio loops in AudioManager
- [ ] Island and props use warm/earthy color palette textures

#### Night Palette (Module 2 — gritty/horror)
- [ ] `WorldEnvironment` night preset: dark, high-contrast, cool/red-tinted ambient
- [ ] Red sea shader (ShaderMaterial on water plane: animated red tint + foam)
- [ ] Screen grain shader (CanvasLayer, NIGHT only)
- [ ] Heavy retro horror audio loop in AudioManager
- [ ] Day→night crossfade wired in GameState TRANSITION state

#### Philippine Mythology Enemy Skins (Module 1 & 2)
- [ ] Research + select names for Normal, Tanky, Shooting fish types → document in `PLAN.md`
- [ ] Normal Fish → `_________`: sprite sheet created/sourced, assigned to `NormalFish.tscn`
- [ ] Tanky Fish → `_________`: sprite sheet, assigned
- [ ] Shooting Fish → `_________`: sprite sheet, assigned
- [ ] Names visible in enemy death/intro (at minimum in HUD or kill-feed label)

#### Fisherfolk Narrative Framing (Module 1)
- [ ] Intro screen copy: 2–4 sentences; frames the experience as fisherfolk labor/precarity
- [ ] Game-over copy: ties nights survived to a statement about persistence/precarity; not generic "you died"
- [ ] DAY period feel: ambient fish sounds, dock ambience; reinforce labor

#### Combat VFX
- [ ] Overkill explosion: particle burst (GPUParticles3D) + brief screen shake on enemy overkill
- [ ] Projectile hit: small impact particle
- [ ] Blood decal: a `Decal` node stamped on ground at enemy death position (one texture, no system needed)

#### SFX / Audio
- [ ] Player footstep (day surface)
- [ ] Player hurt sound
- [ ] Player dodge whoosh
- [ ] Enemy hit sound
- [ ] Enemy death sound
- [ ] Weapon fire SFX (per weapon type or generic; routed through AudioManager)
- [ ] Fishing minigame SFX (cast, reel, catch, fail)
- [ ] Day/night music crossfade confirmed working in AudioManager

#### Asset Replacement
- [ ] Replace all `assets/_placeholder/` sprites with final art
- [ ] Replace placeholder Island geometry with final 3D island mesh + textures
- [ ] Re-bake NavigationRegion3D after final Island mesh

### Reminders
- Document Philippine mythology enemy names here and in `PLAN.md` — this is an explicit arts grade criterion
- The day→night transition is the **central artistic image**. Play it. It must be visceral and clear.

### Bugs
_None yet_

### Warnings
- Re-bake navigation after any mesh change or enemies will path incorrectly

---

## Phase 9 — Balance, Optimization & Ship `TODO`

**Goal:** The game is fun, stable at 100+ enemies, and ships as a playable Windows executable.

### Checklist

#### Balance
- [ ] Tune `RarityTier` stat multipliers (`weapon_multiplier`, `shot_delay_multiplier`, etc. — are rare weapons meaningfully stronger?)
- [ ] Tune `SpawnEnemySystem` scaling factor (does difficulty ramp feel fair/escalating?)
- [ ] Tune weapon economy: CP costs vs recharge rate — can player sustain fire without trivially camping?
- [ ] Tune buff-day rewards — are buffs impactful enough to feel earned?
- [ ] Tune fishing drop rates — are good weapons too easy/hard to fish up? (`base_lure_chance` + `lure_multiplier` per tier)
- [ ] Tune `spawn_day` gates on `FishWeaponData` — does progression feel earned?

#### Performance
- [ ] Enemy pooling: pre-instantiate N enemies at level load; recycle on death instead of `queue_free()`
- [ ] Confirm stable fps with 100+ enemies active (Godot profiler: check physics, navigation, rendering)
- [ ] NavigationAgent3D update tick rate (can lower for offscreen enemies)
- [ ] Billboard/Sprite3D LOD (hide or simplify far enemies)
- [ ] Occlusion culling enabled in project settings

#### Final Pass
- [ ] Bug pass: play through 20+ nights looking for crashes, stuck enemies, inventory edge cases
- [ ] Export templates installed for Windows Desktop
- [ ] Export via: `godot4 --headless --path . --export-release "Windows Desktop" builds/fishpocalypse.exe`
- [ ] Exported `.exe` launches, intro screen shows, full loop works
- [ ] Playtest with someone unfamiliar — do the art concepts land without explanation?

### Reminders
- The arts grade depends on the playtest question above: are Module 1 + Module 2 legible to an outside viewer?

### Bugs
_None yet_

### Warnings
_None yet_

---

## Known Cross-Phase Reminders

- **After every implementation session:** Update the relevant phase status, tick checklist items, and log any bugs or warnings discovered. Update `PLAN.md` if any architectural or scope decision changes.
- **Navigation re-bake:** Required any time `Island.tscn` geometry changes (Phase 0, Phase 8).
- **Placeholder marking:** All stand-in assets live in `assets/_placeholder/` — check before Phase 8 that nothing is still pointing there unintentionally.
- **Arts course deadline:** The Module 1 + 2 art integration must be grader-legible. Don't defer the intro/outro copy and mythology naming — schedule them intentionally in Phase 8.
