# Phase 6 — Fishing System Design
_2026-05-18 · DIO_

## Scope

DIO owns Phase 6 entirely:
- All Resource subclass stubs (for classes CJ/SEN haven't written yet)
- All concrete `.tres` data files populating `ItemsDB`
- `FishingSystem` script — DAY-only gating, fishing spot trigger
- `FishingMinigame.tscn` — Stardew-style vertical bar-catch UI

Depends on but does NOT implement: `GameState` (SEN), `InventorySystem` (CJ).

---

## Data Layer

### Resource stubs (create if absent, never duplicate if CJ/SEN already wrote them)

| File | Class | Notes |
|------|-------|-------|
| `resources/rarity_tier.gd` | `RarityTier` | name, color, weapon_multiplier, shot_delay_multiplier, lure_multiplier, cost_multiplier, heal_multiplier |
| `resources/rarity_config.gd` | `RarityConfig` | tiers: Array[RarityTier] |
| `resources/projectile_data.gd` | `ProjectileData` | owner_type, speed, damage, lifetime, sprite |
| `resources/fish_weapon_data.gd` | `FishWeaponData` | spawn_day, base_damage_per_shot, base_shot_delay, base_projectiles_per_shot, base_recharge_cost, rarity, projectile, sprite_frames, sfx |
| `resources/healing_item_data.gd` | `HealingItemData` | item_class, base_heal_amount, use_delay, stack_limit, rarity, sprite |
| `resources/fishing_pole_data.gd` | `FishingPoleData` | base_bar_size, base_lure_speed, base_lure_chance, rarity, sprite_frames |
| `resources/items_db.gd` | `ItemsDB` | fish_weapons: Array[FishWeaponData], healing_items: Array[HealingItemData], fishing_poles: Array[FishingPoleData] |

### .tres files

**FishWeapons** — 8 total, spread across rarities, `spawn_day` gates progression:

| File | Rarity | spawn_day | Notes |
|------|--------|-----------|-------|
| `sardine_shooter.tres` | common | 1 | 1 projectile, slow fire |
| `tuna_lobber.tres` | common | 1 | 1 projectile, arc feel (slower speed) |
| `mackerel_burst.tres` | uncommon | 3 | 2 projectiles/shot, spread |
| `bangus_blaster.tres` | uncommon | 5 | fast fire, low damage |
| `squid_spray.tres` | rare | 8 | 3 projectiles/shot |
| `crab_cannon.tres` | epic | 12 | high damage, slow fire |
| `shark_shotgun.tres` | epic | 18 | 4 projectiles/shot, short lifetime |
| `bakunawa_beam.tres` | legendary | 25 | max damage, placeholder for mythology skin |

**HealingItems** — 4 total (one per class):

| File | item_class | base_heal_amount | stack_limit |
|------|------------|-----------------|-------------|
| `bandage.tres` | I | 10 | 5 |
| `fish_wrap.tres` | II | 25 | 4 |
| `herbal_brew.tres` | III | 50 | 3 |
| `sea_blessing.tres` | IV | 100 | 2 |

**FishingPoles** — 3 total:

| File | base_bar_size | base_lure_speed | base_lure_chance | rarity |
|------|--------------|----------------|-----------------|--------|
| `basic_pole.tres` | 0.25 | 1.0 | 0.4 | common |
| `reinforced_pole.tres` | 0.35 | 0.8 | 0.55 | uncommon |
| `spirit_pole.tres` | 0.5 | 0.6 | 0.75 | rare |

**RarityTiers** — 1 `rarity_config.tres` with 6 tiers (common → uncommon → rare → epic → legendary → ???):

| Tier | lure_multiplier | weapon_multiplier | heal_multiplier |
|------|----------------|-------------------|----------------|
| common | 1.0 | 1.0 | 1.0 |
| uncommon | 1.2 | 1.3 | 1.2 |
| rare | 1.5 | 1.7 | 1.5 |
| epic | 2.0 | 2.2 | 2.0 |
| legendary | 3.0 | 3.0 | 3.0 |
| ??? | 5.0 | 5.0 | 5.0 |

---

## FishingSystem Script

**File:** `scripts/fishing_system.gd` — Node attached to a `FishingSpot` node in `Main.tscn`.

**DAY gating:**
- On `_ready`: connect `GameState.day_started` → `_on_day_started`, `GameState.night_started` / `GameState.transition_started` → `_on_day_ended`
- `_can_fish: bool` — true only when GameState state is DAY

**Fishing spot trigger:**
- Each `FishingSpot` is a Node3D placed at the island perimeter (grass meets water edge). Contains:
  - `Area3D` (`FishingSpotArea`) — collision shape covering the stand-here zone; `body_entered` / `body_exited` track whether Player is in range
  - `Marker3D` (`FacingMarker`) — child node positioned outward toward the water; its `-Z` forward points away from the island
- `interact` input while in range + `_can_fish` → `start_fishing(spot: FishingSpot)`
- On `start_fishing`: snap player `global_rotation.y` to match `spot.facing_marker.global_rotation.y` so the player billboard faces the water (prevents fishing-into-a-wall visually)

**Catch pool:**
- On catch, build eligible pool: all `ItemsDB.fish_weapons` where `spawn_day <= GameState.day_count`, plus all healing items, plus all fishing poles
- Selection weight per item = `BASE_RARITY_WEIGHT[rarity_index] * (1.0 + pole.base_lure_chance * item.rarity.lure_multiplier)` where `BASE_RARITY_WEIGHT = [100, 60, 30, 10, 3, 1]` (common→???) — common items dominate; better poles amplify rare item weights more via lure_multiplier
- Pick one item weighted-randomly from the pool; call `player.inventory_system.pickup(item)`

**Cancel:**
- Connect `GameState.transition_started` → `cancel_fishing()` — hides minigame, resets state mid-game

---

## FishingMinigame.tscn

**Node:** `Control` (CanvasLayer child or direct child of Main while fishing)

**Visual:** Center-screen overlay, warm day palette. Wood-bordered tall vertical bar + right-side progress bar. World stays visible behind it (no dim).

**Node tree:**
```
FishingMinigame (Control)
  BarPanel (PanelContainer)          # wood border frame
    BarContainer (HBoxContainer)
      MainBar (Control)              # the tall bar, fish cursor + player zone drawn here
      ProgressBar (ProgressBar)      # right-side catch meter, vertical
  HoldLabel (Label)                  # "Hold [F] to rise"
```

**Script (`scripts/fishing_minigame.gd`):**

State machine — `IDLE → ACTIVE → RESULT`:
- `IDLE`: hidden
- `ACTIVE`: `_process` runs fish cursor + player zone physics
- `RESULT`: brief flash (success green / fail red), emit `caught(item)` or `failed`, back to IDLE

Fish cursor physics:
- Moves at `base_lure_speed` (from equipped pole)
- Bounces off top/bottom of bar
- Adds random velocity impulse on a short timer (`_change_fish_direction_timer`)

Player zone physics:
- The same `interact` (F) input that triggers fishing is held during the minigame to raise the zone — `FishingSystem` suppresses the trigger check once `FishingMinigame` is ACTIVE so there is no double-fire
- Hold `interact` (Input.is_action_pressed("interact")) → apply upward velocity
- Always apply downward gravity
- Clamped to bar bounds
- Height = `base_bar_size * BAR_HEIGHT`

Progress logic:
- Fish cursor overlaps player zone → `catch_progress += FILL_RATE * delta`
- No overlap → `catch_progress -= DRAIN_RATE * delta`
- `catch_progress` clamped 0–1
- Reach 1.0 → success; drain to 0.0 → failure

**Signals emitted:**
- `caught(item_resource: Resource)`
- `failed()`

---

## Interfaces Relied On (not implemented here)

| Interface | Owner | How used |
|-----------|-------|---------|
| `GameState.day_count` | SEN | filter spawn_day |
| `GameState.day_started` signal | SEN | enable fishing |
| `GameState.night_started` signal | SEN | disable fishing |
| `GameState.transition_started` signal | SEN | cancel mid-game |
| `player.inventory_system.pickup(resource)` | CJ | deliver caught item |
| `player.inventory_system` node ref | CJ | accessed via group or signal |

---

## Out of Scope for Phase 6

- Fishing SFX (Phase 8)
- Fishing animation on player sprite (Phase 8)
- Night fishing (not in design)
- Fishing pole equipped-slot UI (Phase 7)
