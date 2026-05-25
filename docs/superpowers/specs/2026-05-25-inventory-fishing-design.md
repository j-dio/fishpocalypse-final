# Inventory, Pickup, Consume & Fishing Improvements — Design Spec
_Date: 2026-05-25_

---

## Scope

Addresses four gaps in the current codebase:

1. **Inventory System + Auto-Pickup** — player can collect world items into fixed slots
2. **Item Consume / Delete** — healing items are used up; weapons swap in/out
3. **Fishing Wait Mechanic** — Stardew-style bite reaction before the minigame opens
4. **Fishing → ItemSpawner connection** — caught items become physical pickups, not direct inventory inserts

Enemy base class is **out of scope** (deferred until teammate clarifies requirements).

---

## 1. Inventory System + Auto-Pickup

### Slot Structure

`InventorySystem.gd` lives as a child node on the Player. It holds four typed slots:

```
main_slot:      FishWeaponData  | null
secondary_slot: FishWeaponData  | null
item_slot_1:    HealingItemData | null
item_slot_2:    HealingItemData | null
```

No pole slot in the hotbar. `FishingSystem._get_equipped_pole()` already falls back to `items_db.fishing_poles[0]` — pole handling stays implicit until the HUD is built in Phase 7.

### Auto-Pickup

- Player scene gains an `Area3D` child (`PickupZone`) with a small sphere `CollisionShape3D`
- When a world item node (WeaponTemplate, HealingItemTemplate, PoleTemplate) enters the zone, it calls `InventorySystem.pickup(item_node)`
- `pickup()` reads `item_node.data`, routes by type:
  - `FishWeaponData` → first empty weapon slot (`main_slot` then `secondary_slot`)
  - `HealingItemData` → first empty item slot (`item_slot_1` then `item_slot_2`)
  - `FishingPoleData` → ignored for now (no slot)
- If all relevant slots are full, the item stays on the ground — nothing is destroyed
- The world item node calls `queue_free()` on itself after emitting its data; `InventorySystem` never touches the scene tree directly

### Signals

```gdscript
signal slot_changed(slot_name: String)   # emitted on any slot mutation
signal item_dropped(data: Resource)      # emitted when a slot is cleared by drop
```

### Drop / Remove

`InventorySystem.drop_item(slot_name: String)`:
- Clears the named slot (`= null`)
- Emits `item_dropped(data)` — Phase 7 HUD listens to this to update the bar
- For pre-HUD testing: a debug keybind clears `main_slot`

### Weapon Full-Slot Behaviour

If a weapon is picked up and both weapon slots are occupied:
- The currently active slot's weapon is dropped as a physical pickup at the player's feet via `ItemSpawner.spawn_weapon(old_data, rarity)`
- The new weapon takes that slot

---

## 2. Item Consume / Delete

### Healing Items

`InventorySystem.use_item(slot: String)`:
- Checks slot holds a `HealingItemData`
- Calls `player.health.heal(data.base_heal_amount)` — requires Health component (Phase 2); stubs gracefully if absent
- Clears the slot, emits `slot_changed(slot_name)`
- Input: `use_item_1` / `use_item_2` actions — stubbed now, wired to HUD in Phase 7

### Weapons

- Picked up → fills an empty slot or replaces active slot (see Section 1)
- No "consume" — weapons persist until manually dropped
- `swap_active()` toggles which weapon slot is "active" — no deletion

### World Item Self-Cleanup

Each item template scene (`WeaponTemplate`, `HealingItemTemplate`, `PoleTemplate`) implements:

```gdscript
func _on_picked_up() -> void:
    emit_signal("picked_up", data)
    queue_free()
```

`InventorySystem.pickup()` calls this after reading the data. The scene tree stays clean — `InventorySystem` never calls `queue_free()` itself.

---

## 3. Fishing Wait Mechanic (Stardew-Style)

### New States

```gdscript
enum State { IDLE, WAITING, BITE, ACTIVE, RESULT_SUCCESS, RESULT_FAIL }
```

### State Flow

```
IDLE
  └─ start_wait(item, pole) called by FishingSystem
       └─ WAITING
            Player sees: bobber on water, gentle ripple animation
            Timer: randf_range(2.0, 5.0) seconds
            └─ timer fires → BITE
                 Simultaneously:
                   • Bobber jerks downward (animation)
                   • "!" Label3D pops above player head (signal to player node)
                   • AudioManager.play_sfx("fishing_bite") stub
                 Reaction window: randf_range(0.6, 0.8) seconds
                 └─ INTERACT pressed in time
                      • "HIT!" label flashes above player
                      • Player animation freezes
                      • → ACTIVE (existing bar minigame)
                 └─ Window expires without input
                      • Bobber floats back up (reel-in animation)
                      • → IDLE (player must recast with INTERACT)
```

### API Change

`FishingSystem._start_fishing()` calls `minigame.start_wait(item, pole)` instead of `minigame.start(item, pole)`.

`start()` becomes an internal method called only after a successful bite reaction — existing minigame bar logic is untouched.

### Visual Nodes Required

- `BobberSprite` — `Sprite3D` or `AnimatedSprite3D` placed at the fishing spot's water surface; driven by `FishingMinigame` state
- `ExclamationLabel` — `Label3D` or `Sprite3D` above the player; hidden by default, shown on BITE state via signal
- Animations: `idle_ripple` (loop), `bite_jerk` (one-shot), `reel_in` (one-shot)

---

## 4. Fishing → ItemSpawner Connection

### Problem

`FishingSystem._on_caught()` currently tries to call `inv.pickup(item)` directly — the item never becomes a physical world object and `FishingSystem` is tightly coupled to `InventorySystem`.

### Solution

`FishingSystem` gets `@export var item_spawner: ItemSpawner` (assigned in scene Inspector).

On successful catch, `_on_caught(item, rarity)` routes by type:

```gdscript
if item is FishWeaponData:
    item_spawner.spawn_weapon(item, rarity)
elif item is HealingItemData:
    item_spawner.spawn_healing_item(item, rarity)
elif item is FishingPoleData:
    item_spawner.spawn_pole(item, rarity)
```

The item arc-tweens out of the water near the player (existing `ItemSpawner._launch_arc()` handles this). It lands on the ground as a real pickup node. The Player's `PickupZone` Area3D then picks it up automatically.

### Rarity Threading

`FishWeaponData` and `FishingPoleData` already carry a `rarity: RarityTier` field — `_on_caught()` reads `item.rarity` directly and passes it to `item_spawner.spawn_X(data, item.rarity)`.

`HealingItemData` has no rarity field. For healing item catches, `item_spawner.spawn_healing_item(item, rarity_config.tiers[0])` is used (always common). If rarity variance on healing drops is wanted later, add a `rarity: RarityTier` field to `HealingItemData`.

### Dependency Map After This Change

```
FishingSystem  →  ItemSpawner  →  [world item node]
                                        ↓
                               Player PickupZone Area3D
                                        ↓
                               InventorySystem.pickup()
```

`FishingSystem` has zero knowledge of `InventorySystem`. Clean separation.

---

## File Changes Summary

| File | Change |
|---|---|
| `scripts/player/InventorySystem.gd` | **NEW** — 4 slots, pickup routing, use_item, drop_item, signals |
| `scenes/player/DebugPlayer.tscn` | Add `InventorySystem` child node + `PickupZone` Area3D |
| `scripts/itemSystem/0_weaponTemplate.gd` | Add `_on_picked_up()` self-cleanup |
| `scripts/itemSystem/1_poleTemplate.gd` | Add `_on_picked_up()` self-cleanup |
| `scripts/itemSystem/2_healingItemTemplate.gd` | Add `_on_picked_up()` self-cleanup |
| `scripts/fishSystem/fishing_minigame.gd` | Add `WAITING`/`BITE` states, `start_wait()`, reaction window logic |
| `scripts/fishSystem/fishing_system.gd` | Change `_on_caught()` to call `item_spawner.spawn_X()`; add `item_spawner` export; pass rarity through |

---

## Out of Scope

- HUD hotbar visuals (Phase 7)
- Pole slot in inventory
- Enemy base class (deferred)
- AudioManager SFX (Phase 8) — stubs in place only
- Health component implementation (Phase 2 dependency — `use_item` stubs gracefully if absent)
