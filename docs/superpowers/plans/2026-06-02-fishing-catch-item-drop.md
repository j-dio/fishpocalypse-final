# Fishing Catch → Item Drop Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two bugs that prevent caught items from appearing and enhance the catch animation so items arc high, spin, and land near the player with a squash-settle bounce.

**Architecture:** The signal pipeline (`FishingMinigame.caught` → `FishingSystem._on_caught` → `ItemSpawner.spawn_weapon/healing/pole`) is already correctly wired in `MainScene.tscn`. No new nodes, scenes, or scripts needed — only five existing files change. Bug 1 is a wrong resource reference in a .tscn. Bug 2 is a missing billboard flag on three sprite nodes. The animation rewrite is a single function in one .gd file.

**Tech Stack:** Godot 4.5, GDScript, Tween API (`item.create_tween()`), AnimatedSprite3D

---

## File Map

| File | What changes |
|---|---|
| `scenes/player/DebugPlayer.tscn` | InventorySystem.items_db → real items_db.tres |
| `scenes/ItemRelated/WeaponTemplate.tscn` | Add `billboard = 1` to AnimatedSprite3D |
| `scenes/ItemRelated/HealingItemTemplate.tscn` | Add `billboard = 1` to sprite node if missing |
| `scenes/ItemRelated/PoleTemplate.tscn` | Add `billboard = 1` to sprite node if missing |
| `scripts/itemSpawnerSystem/ItemSpawner.gd` | Rewrite `_launch_arc()`, remove `bounce_amount`, raise `drop_height` default, widen default spread |

---

## Task 1: Fix Starting Fishing Pole (InventorySystem items_db)

**Files:**
- Modify: `scenes/player/DebugPlayer.tscn`

**Why this is broken:** `DebugPlayer.tscn` assigns `InventorySystem` an inline empty `ItemsDB` sub-resource (`Resource_1p3k1` — arrays for fish_weapons, healing_items, fishing_poles are all absent, defaulting to empty). `InventorySystem._ready()` only auto-equips a pole when `items_db.fishing_poles` is non-empty. With an empty resource it skips, so the player starts with nothing in the pole slot.

The real item database is at `res://assets/resources/items/items_db.tres` (uid `uid://dyjmr7uqctvpk`) — it already has 8 weapons, 4 healing items, and 3 fishing poles populated.

**Note:** `FishingSystem._get_equipped_pole()` checks `_player.has_node("InventorySystem")` (direct child) but the actual path is `COMPONENTS/InventorySystem`, so it always falls back to `FishingSystem.items_db.fishing_poles[0]` regardless. This fix makes the pole visible in the player's inventory and equips it via `InventorySystem`, even though `FishingSystem` currently reads it through its own fallback. Fishing still works either way.

- [ ] Open `scenes/player/DebugPlayer.tscn` in a plain text editor (not the Godot scene editor).

- [ ] Find the last `[ext_resource ...]` line near the top. It currently ends with:
```
[ext_resource type="Texture2D" uid="uid://bvosluw4bj2ob" path="res://assets/sprites/border_health.png" id="12_bmswy"]
[ext_resource type="Texture2D" uid="uid://odyn88wwwt5i" path="res://assets/sprites/fists.png" id="13_blpqp"]
```
Add this new line immediately after:
```
[ext_resource type="Resource" uid="uid://dyjmr7uqctvpk" path="res://assets/resources/items/items_db.tres" id="items_db_ref"]
```

- [ ] Find and **delete** this entire sub_resource block (it is the empty inline ItemsDB, no longer needed):
```
[sub_resource type="Resource" id="Resource_1p3k1"]
script = ExtResource("7_blpqp")
metadata/_custom_type_script = "uid://xpnm82ynjqsm"
```

- [ ] Find the InventorySystem node block and change its `items_db` line:

Before:
```
[node name="InventorySystem" type="Node" parent="COMPONENTS" unique_id=1226888241]
script = ExtResource("4_inv")
items_db = SubResource("Resource_1p3k1")
```

After:
```
[node name="InventorySystem" type="Node" parent="COMPONENTS" unique_id=1226888241]
script = ExtResource("4_inv")
items_db = ExtResource("items_db_ref")
```

- [ ] Open the Godot editor. It may prompt to reimport — allow it. Open `scenes/MainScene/MainScene.tscn`. Press **F5** to run. Verify no parse errors appear in the Output panel.

- [ ] In-game: check that the inventory UI shows a fishing pole in the pole slot. The pole has no sprite art yet (that's a Phase 8 task) so the slot will show an empty placeholder — that is correct.

- [ ] Stop the game. Commit:
```
git add scenes/player/DebugPlayer.tscn
git commit -m "fix: point InventorySystem to real items_db so starting pole auto-equips"
```

---

## Task 2: Fix Billboard Mode — WeaponTemplate

**Files:**
- Modify: `scenes/ItemRelated/WeaponTemplate.tscn`

**Why this is broken:** The `AnimatedSprite3D` named `Sprite3D` has no `billboard` property, defaulting to `0` (BILLBOARD_DISABLED). The sprite lies flat in the XY plane. From the game's angled top-down camera, it is nearly edge-on and invisible. All other billboard sprites in the project use `billboard = 1` (BILLBOARD_ENABLED).

- [ ] Open `scenes/ItemRelated/WeaponTemplate.tscn` in a plain text editor.

- [ ] Find the Sprite3D node. It currently reads:
```
[node name="Sprite3D" type="AnimatedSprite3D" parent="." unique_id=403291015]
flip_h = true
pixel_size = 0.05
shaded = true
texture_filter = 2
```

- [ ] Add `billboard = 1` between `pixel_size` and `shaded`:
```
[node name="Sprite3D" type="AnimatedSprite3D" parent="." unique_id=403291015]
flip_h = true
pixel_size = 0.05
billboard = 1
shaded = true
texture_filter = 2
```

- [ ] Commit:
```
git add scenes/ItemRelated/WeaponTemplate.tscn
git commit -m "fix: enable billboard on WeaponTemplate sprite so dropped weapons are visible"
```

---

## Task 3: Fix Billboard Mode — HealingItemTemplate and PoleTemplate

**Files:**
- Modify: `scenes/ItemRelated/HealingItemTemplate.tscn`
- Modify: `scenes/ItemRelated/PoleTemplate.tscn`

**Why:** Same invisible-sprite issue as Task 2. Check each file — if `billboard = 1` is already present on the sprite node, skip that file.

- [ ] Open `scenes/ItemRelated/HealingItemTemplate.tscn` in a text editor. Find the sprite node (Sprite3D or AnimatedSprite3D — look for a node with `pixel_size`). If `billboard = 1` is **not** already on it, add it (same position as Task 2: between `pixel_size` and `shaded` or any adjacent property).

- [ ] Open `scenes/ItemRelated/PoleTemplate.tscn` in a text editor. Find the sprite node. If `billboard = 1` is **not** already on it, add it the same way.

- [ ] Commit only the files that actually changed:
```
git add scenes/ItemRelated/HealingItemTemplate.tscn scenes/ItemRelated/PoleTemplate.tscn
git commit -m "fix: enable billboard on healing item and pole pickup sprites"
```
(If only one file changed, add only that one.)

---

## Task 4: Rewrite `_launch_arc()` with Enhanced Catch Animation

**Files:**
- Modify: `scripts/itemSpawnerSystem/ItemSpawner.gd`

**What changes and why:**

| Old behaviour | New behaviour |
|---|---|
| Peak at midpoint between origin and land, 4 units high | Peak directly above origin, 10 units high — looks like item yanked from water |
| Single bounce (second arc, separate tween) | Scale squash-spring-settle on landing — more physical feel |
| 1× Y spin, linear | 3× Y spin, EASE_OUT — spins fast on launch, slows to a stop |
| `bounce_amount` export (0.6) | Removed — replaced by scale squash sequence |
| Default spread 1.2 units | Default spread 2.0 units — lands further, easier to see |

- [ ] Open `scripts/itemSpawnerSystem/ItemSpawner.gd`.

- [ ] **Remove** the `bounce_amount` export and raise `drop_height` default. Find:
```gdscript
@export var drop_height: float = 4.0
@export var bounce_amount: float = 0.6
```
Replace with:
```gdscript
@export var drop_height: float = 10.0
```

- [ ] **Replace** the entire `_launch_arc` function. Find the whole function (from `func _launch_arc` to the closing `if dbg:` line) and replace with:
```gdscript
func _launch_arc(item: Node3D, spread_radius: float, angle: float) -> void:
	var origin   := spawn_marker.global_position
	var land_pos := origin + Vector3(cos(angle), 0.0, sin(angle)) * spread_radius
	var peak_pos := origin + Vector3.UP * drop_height

	item.global_position = origin
	item.scale = Vector3.ONE

	# Position: shoot straight up then fall to landing spot
	var tween := item.create_tween()
	tween.tween_property(item, "global_position", peak_pos, 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", land_pos, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Squash flat on impact
	tween.tween_property(item, "scale", Vector3(1.4, 0.35, 1.4), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Spring back with overshoot (TRANS_BACK adds natural overshoot)
	tween.tween_property(item, "scale", Vector3(0.85, 1.2, 0.85), 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Settle to normal
	tween.tween_property(item, "scale", Vector3.ONE, 0.10)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Spin: 3 full rotations that ease out — fast on launch, stops on landing
	item.create_tween()\
		.tween_property(item, "rotation:y", item.rotation.y + TAU * 3.0, 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if dbg: print("[SPAWNER] Arc -> ", land_pos, " angle=", rad_to_deg(angle), "°")
```

- [ ] **Update default spread** from `1.2` to `2.0` in the three public spawn functions. Find each signature and change the default:

`spawn_weapon` — before:
```gdscript
func spawn_weapon(data: FishWeaponData, rarity: RarityTier,
				  spread: float = 1.2, angle: float = -1.0) -> Node3D:
```
After:
```gdscript
func spawn_weapon(data: FishWeaponData, rarity: RarityTier,
				  spread: float = 2.0, angle: float = -1.0) -> Node3D:
```

`spawn_healing_item` — before:
```gdscript
func spawn_healing_item(data: HealingItemData, rarity: RarityTier,
						spread: float = 1.2, angle: float = -1.0) -> Node3D:
```
After:
```gdscript
func spawn_healing_item(data: HealingItemData, rarity: RarityTier,
						spread: float = 2.0, angle: float = -1.0) -> Node3D:
```

`spawn_pole` — before:
```gdscript
func spawn_pole(data: FishingPoleData, rarity: RarityTier,
				spread: float = 1.2, angle: float = -1.0) -> Node3D:
```
After:
```gdscript
func spawn_pole(data: FishingPoleData, rarity: RarityTier,
				spread: float = 2.0, angle: float = -1.0) -> Node3D:
```

- [ ] Commit:
```
git add scripts/itemSpawnerSystem/ItemSpawner.gd
git commit -m "feat: enhance catch arc — high launch, 3-spin ease-out, squash-spring landing"
```

---

## Task 5: End-to-End Playtest

**No file changes.** This task is manual verification only.

- [/] Press **F5** to run `scenes/MainScene/MainScene.tscn`. Check the Output panel — there should be no red errors on startup.

- [/] **Starting pole check:** Open the inventory UI. The pole slot should show an entry (no sprite art yet — placeholder is expected; the slot should not be completely absent). (could only be verified through console print due to missing pole sprite)

- [/] **Fishing trigger check:** Walk the player to the water's edge. The yellow "Press F to Fish" label should appear above the player.

- [/] **Minigame check:** Press F. The minigame UI appears with "Waiting for a bite..." label.

- [/] **Catch check:** When the bite indicator shows, press F again. Hold F to keep the zone over the fish icon until the catch bar fills to 100%.

- [ ] **Animation check:** After success, an item should visibly shoot up ~10 units, spin three times slowing to a stop, then land ~2 units from the player. On landing it flattens briefly (squash), springs back tall, then settles to normal size.

- [ ] **Pickup check:** Walk into the landed item. It should be added to the player's inventory (weapon goes to weapon slot, healing item to item slot, pole to pole slot). Check the Output panel for the `[Inventory]` print that confirms pickup.

- [ ] **Fail-state check:** Start fishing again. Let the catch bar drain to 0. The minigame should close with no item spawning and the player unfrozen (can move immediately).

- [ ] If any step fails, check the Output panel for `push_error` messages. Common culprits:
  - `"FishingSystem: 'item_spawner' export not assigned"` → NodePath in MainScene.tscn not resolving; re-open the scene in the Godot editor and re-assign `item_spawner` by dragging the ItemSpawner node into the FishingSystem inspector slot, then save.
  - `"[ItemSpawner] Missing data or rarity for weapon"` → `rarity_config` not assigned to FishingSystem in the Inspector; assign `res://assets/resources/rarities/rarity_config.tres`.
