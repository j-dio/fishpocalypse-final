# Shore-Based Fishing Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed FishingSpot nodes with a user-placed ShoreZone Area3D so the player can fish anywhere along the island shoreline, and display a pulsing "Press F to Fish" prompt above the player's head instead of at a fixed world position.

**Architecture:** A new `ShoreZone` (Area3D + script) emits `player_entered_shore` / `player_exited_shore` signals that `FishingSystem` connects to — the same signal pattern already used by `FishingSpot`. When fishing starts, `FishingSystem` computes the direction from the player toward the nearest water (away from island center), rotates the player to face it, and picks the matching animation (`fish_front`, `fish_left`, `fish_right`). A `Label3D` child added to `DebugPlayer` shows the prompt above the player's head and pulses via a sine wave in `_process`.

**Tech Stack:** Godot 4.5, GDScript, existing `FishingSystem` / `DebugPlayer` / `AnimatedSprite3D` animation system.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| **Create** | `scripts/fishSystem/shore_zone.gd` | Emits signals when player enters/exits the shore Area3D |
| **Create** | `scenes/FishingRelated/shore_zone.tscn` | Reusable scene; user places + scales this in the editor |
| **Modify** | `scripts/fishSystem/fishing_system.gd` | Remove FishingSpot logic; add ShoreZone connection, water-direction math, animation selection, prompt show/hide calls |
| **Modify** | `scripts/player/DebugPlayer.gd` | Add `show_fishing_prompt()`, `hide_fishing_prompt()`, `play_fishing_anim()`, pulse in `_process` |
| **Modify** | `scenes/player/DebugPlayer.tscn` | Add `FishingPrompt` Label3D node as child of DebugPlayer root |
| **Manual** | `scenes/MainScene/MainScene.tscn` | Remove old FishingSpot instances; user places ShoreZone in editor |

---

## Task 1 — Create ShoreZone script

**Files:**
- Create: `scripts/fishSystem/shore_zone.gd`

- [ ] **Step 1: Write `shore_zone.gd`**

```gdscript
# scripts/fishSystem/shore_zone.gd
class_name ShoreZone
extends Area3D

signal player_entered_shore(player: Node3D)
signal player_exited_shore()

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    add_to_group("shore_zones")

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        player_entered_shore.emit(body)

func _on_body_exited(body: Node3D) -> void:
    if body.is_in_group("player"):
        player_exited_shore.emit()
```

- [ ] **Step 2: Commit**

```
git add scripts/fishSystem/shore_zone.gd
git commit -m "feat: add ShoreZone script for shoreline fishing detection"
```

---

## Task 2 — Create ShoreZone scene

**Files:**
- Create: `scenes/FishingRelated/shore_zone.tscn`

- [ ] **Step 1: Write `shore_zone.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/fishSystem/shore_zone.gd" id="1_shore"]

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(10, 4, 2)

[node name="ShoreZone" type="Area3D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1_shore")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_1")
```

The default box is `10 × 4 × 2` — a thin strip. The user will scale each placed instance in the editor to hug the actual shoreline.

- [ ] **Step 2: Commit**

```
git add scenes/FishingRelated/shore_zone.tscn
git commit -m "feat: add ShoreZone scene (user places + scales around island edge)"
```

---

## Task 3 — Add FishingPrompt Label3D to DebugPlayer scene

**Files:**
- Modify: `scenes/player/DebugPlayer.tscn`

The node goes in at the end of the file, as a direct child of the `DebugPlayer` root node (same level as `Sprite3D`, `Kamot`, etc.).

- [ ] **Step 1: Append `FishingPrompt` node to `DebugPlayer.tscn`**

Open `scenes/player/DebugPlayer.tscn`. At the very end of the file (after all existing `[node ...]` entries), add:

```
[node name="FishingPrompt" type="Label3D" parent="."]
position = Vector3(0, 2.2, 0)
pixel_size = 0.01
text = "Press F to Fish"
font_size = 32
billboard = 1
modulate = Color(1, 1, 0, 1)
visible = false
```

- [ ] **Step 2: Verify in Godot editor**

Open Godot, let it reimport. Open `DebugPlayer.tscn`. Confirm a `FishingPrompt` Label3D appears in the scene tree under `DebugPlayer`, floating above the sprite, with yellow text, hidden by default.

- [ ] **Step 3: Commit**

```
git add scenes/player/DebugPlayer.tscn
git commit -m "feat: add FishingPrompt Label3D above player head (hidden by default)"
```

---

## Task 4 — Add prompt + animation methods to DebugPlayer script

**Files:**
- Modify: `scripts/player/DebugPlayer.gd`

- [ ] **Step 1: Add `@onready` reference for the prompt**

In `DebugPlayer.gd`, find this block near the top:

```gdscript
@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var spotlight: SpotLight3D = $SpotLight3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
```

Add one line below it:

```gdscript
@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var spotlight: SpotLight3D = $SpotLight3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var _fishing_prompt: Label3D = $FishingPrompt
```

- [ ] **Step 2: Add `_process` for pulsing**

`DebugPlayer.gd` has no `_process` function — add it below `_physics_process`:

```gdscript
func _process(_delta: float) -> void:
    if _fishing_prompt != null and _fishing_prompt.visible:
        var t := Time.get_ticks_msec() / 1000.0
        _fishing_prompt.modulate.a = 0.6 + 0.4 * sin(t * 3.0)
```

This pulses the label between 60 % and 100 % opacity three times per second.

- [ ] **Step 3: Add the three public methods called by FishingSystem**

Add these at the bottom of `DebugPlayer.gd` (before the final closing, after `end_dodge`):

```gdscript
func show_fishing_prompt() -> void:
    if _fishing_prompt != null:
        _fishing_prompt.visible = true

func hide_fishing_prompt() -> void:
    if _fishing_prompt != null:
        _fishing_prompt.visible = false
        _fishing_prompt.modulate.a = 1.0

func play_fishing_anim(anim_name: String) -> void:
    _play_anim(anim_name)
```

- [ ] **Step 4: Manual test — prompt visibility**

Run `scenes/MainScene/MainScene.tscn` (or `DEBUGSCENE.tscn`). Open the Godot Remote Scene tree and call `show_fishing_prompt()` via the debugger, or temporarily add `show_fishing_prompt()` to `_ready()`. Confirm the yellow label appears above the player's head and pulses. Remove any temporary test code.

- [ ] **Step 5: Commit**

```
git add scripts/player/DebugPlayer.gd
git commit -m "feat: add fishing prompt pulse + play_fishing_anim to DebugPlayer"
```

---

## Task 5 — Refactor FishingSystem

**Files:**
- Modify: `scripts/fishSystem/fishing_system.gd`

This is the largest change. Replace the file wholesale with the version below — it preserves all existing logic (rarity roll, item spawn, freeze/unfreeze, day gating) while wiring up `ShoreZone` instead of `FishingSpot`.

- [ ] **Step 1: Replace `fishing_system.gd` with the refactored version**

```gdscript
# scripts/fishSystem/fishing_system.gd
class_name FishingSystem
extends Node

# Weights indexed by rarity order in RarityConfig.tiers (common=0 … ???=5)
const BASE_RARITY_WEIGHTS: Array[float] = [100.0, 60.0, 30.0, 10.0, 3.0, 1.0]

@export var items_db: ItemsDB
@export var rarity_config: RarityConfig
@export var minigame: FishingMinigame
@export var item_spawner: ItemSpawner

## World-space center of the island. Used to compute which direction faces water.
## Set this once in the Inspector to match your island's center position.
@export var island_center: Vector3 = Vector3.ZERO

var _can_fish: bool = false
var _in_shore_zone: bool = false
var _player: Node3D = null
var _locked_player: Node3D = null
var _game_state: Node = null

func _ready() -> void:
	if minigame == null:
		minigame = get_node_or_null("../UI/FishingMinigame")
	if minigame == null:
		push_error("FishingSystem: FishingMinigame not found at ../UI/FishingMinigame — assign via Inspector.")
		return
	if items_db == null:
		push_error("FishingSystem: 'items_db' export not assigned in Inspector.")
		return
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		push_error("FishingSystem: GameState autoload not found. Register game_state.gd in Project > Autoloads.")
		return
	_game_state.day_started.connect(_on_day_started)
	_game_state.night_started.connect(_on_day_ended)
	if _game_state.has_signal("transition_started"):
		_game_state.transition_started.connect(_on_day_ended)
	minigame.caught.connect(_on_caught)
	minigame.failed.connect(_on_failed)
	call_deferred("_connect_shore_zones")

func _on_day_started() -> void:
	_can_fish = true

func _on_day_ended() -> void:
	_can_fish = false
	if minigame.is_active():
		minigame.cancel()
		_unfreeze_player()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_fish or not _in_shore_zone or minigame.is_active():
		return
	if not InputMap.has_action("INTERACT"):
		return
	if event.is_action_pressed("INTERACT"):
		_start_fishing()

func _start_fishing() -> void:
	var pole := _get_equipped_pole()
	if pole == null:
		return
	var item := _roll_item(pole)
	if item == null:
		push_warning("FishingSystem: catch pool empty (all weapons locked by spawn_day?)")
		return
	# Face the player toward water and play the matching fishing animation
	var water_dir := _get_water_direction()
	if _player != null and water_dir.length_squared() > 0.001:
		_player.global_rotation.y = atan2(water_dir.x, water_dir.z)
	var anim_name := _pick_fishing_anim(water_dir)
	if _player != null and _player.has_method("play_fishing_anim"):
		_player.play_fishing_anim(anim_name)
	minigame.start_wait(item, pole)
	_freeze_player()

## Returns the normalised XZ direction from the player toward the nearest water,
## computed as "away from the island center". Y is zeroed out.
func _get_water_direction() -> Vector3:
	if _player == null:
		return Vector3.FORWARD
	var dir := _player.global_position - island_center
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return Vector3.FORWARD
	return dir.normalized()

## Maps a water direction to the correct fishing animation name.
## fish_front covers both +Z and -Z shores (no fish_back animation exists).
## fish_right → water is in the +X direction.
## fish_left  → water is in the -X direction.
func _pick_fishing_anim(water_dir: Vector3) -> String:
	var ax := absf(water_dir.x)
	var az := absf(water_dir.z)
	if az >= ax:
		return "fish_front"
	return "fish_right" if water_dir.x > 0.0 else "fish_left"

func _roll_item(pole: FishingPoleData) -> Resource:
	var pool: Array[Resource] = []
	var weights: Array[float] = []
	var raw = _game_state.get("day_count") if _game_state != null else 1
	if raw == null:
		push_warning("FishingSystem: GameState.day_count not found — defaulting to 1")
	var day: int = raw if raw != null else 1

	for w: FishWeaponData in items_db.fish_weapons:
		if w.spawn_day <= day:
			var idx := _rarity_index(w.rarity)
			pool.append(w)
			weights.append(BASE_RARITY_WEIGHTS[idx] * (1.0 + pole.base_lure_chance * (w.rarity.lure_multiplier if w.rarity != null else 1.0)))

	for h: HealingItemData in items_db.healing_items:
		pool.append(h)
		weights.append(BASE_RARITY_WEIGHTS[0] * (1.0 + pole.base_lure_chance))

	for p: FishingPoleData in items_db.fishing_poles:
		var idx := _rarity_index(p.rarity)
		pool.append(p)
		weights.append(BASE_RARITY_WEIGHTS[idx] * (1.0 + pole.base_lure_chance * (p.rarity.lure_multiplier if p.rarity != null else 1.0)))

	if pool.is_empty():
		return null
	return _weighted_pick(pool, weights)

func _weighted_pick(pool: Array[Resource], weights: Array[float]) -> Resource:
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := randf() * total
	var acc := 0.0
	for i: int in pool.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return pool[-1]

func _rarity_index(rarity: RarityTier) -> int:
	if rarity_config == null or rarity == null:
		return 0
	for i: int in rarity_config.tiers.size():
		if rarity_config.tiers[i] == rarity:
			return i
	return 0

func _get_equipped_pole() -> FishingPoleData:
	if _player != null and _player.has_node("InventorySystem"):
		var inv := _player.get_node("InventorySystem")
		if inv.has_method("get_equipped_pole"):
			var p: FishingPoleData = inv.get_equipped_pole()
			if p != null:
				return p
	if not items_db.fishing_poles.is_empty():
		return items_db.fishing_poles[0]
	push_error("FishingSystem: no fishing poles in ItemsDB")
	return null

func _on_shore_entered(player: Node3D) -> void:
	_in_shore_zone = true
	_player = player
	if _player.has_method("show_fishing_prompt"):
		_player.show_fishing_prompt()

func _on_shore_exited() -> void:
	_in_shore_zone = false
	if _player != null and _player.has_method("hide_fishing_prompt"):
		_player.hide_fishing_prompt()
	_player = null

func _on_caught(item: Resource) -> void:
	_unfreeze_player()
	if item_spawner == null:
		push_error("FishingSystem: 'item_spawner' export not assigned — caught item lost")
		return
	if _player != null:
		item_spawner.spawn_marker.global_position = _player.global_position
	var rarity: RarityTier = _get_item_rarity(item)
	if item is FishWeaponData:
		item_spawner.spawn_weapon(item as FishWeaponData, rarity)
	elif item is HealingItemData:
		var common: RarityTier = rarity_config.tiers[0] if rarity_config and not rarity_config.tiers.is_empty() else null
		item_spawner.spawn_healing_item(item as HealingItemData, common)
	elif item is FishingPoleData:
		item_spawner.spawn_pole(item as FishingPoleData, rarity)

func _on_failed() -> void:
	_unfreeze_player()

func _freeze_player() -> void:
	if _player == null:
		return
	_locked_player = _player
	_locked_player.set_physics_process(false)
	if _locked_player is CharacterBody3D:
		(_locked_player as CharacterBody3D).velocity = Vector3.ZERO

func _unfreeze_player() -> void:
	if _locked_player == null:
		return
	_locked_player.set_physics_process(true)
	_locked_player = null

func _connect_shore_zones() -> void:
	for zone: ShoreZone in get_tree().get_nodes_in_group("shore_zones"):
		zone.player_entered_shore.connect(_on_shore_entered)
		zone.player_exited_shore.connect(_on_shore_exited)

func _get_item_rarity(item: Resource) -> RarityTier:
	var r: RarityTier = item.get("rarity") as RarityTier
	if r != null:
		return r
	if rarity_config and not rarity_config.tiers.is_empty():
		return rarity_config.tiers[0]
	return null
```

- [ ] **Step 2: Commit**

```
git add scripts/fishSystem/fishing_system.gd
git commit -m "refactor: replace FishingSpot group with ShoreZone; add water-direction + animation logic"
```

---

## Task 6 — Scene cleanup + ShoreZone placement

**Files:**
- Modify: `scenes/MainScene/MainScene.tscn` (manual editor work)

- [ ] **Step 1: Remove old FishingSpot nodes from MainScene**

Open `scenes/MainScene/MainScene.tscn` in the Godot editor. In the Scene panel, find and delete any nodes of type `FishingSpot` (they have the blue circle visual). There may be one or more. Delete them all.

- [ ] **Step 2: Place ShoreZone instances around the island**

Drag `scenes/FishingRelated/shore_zone.tscn` into the scene. Position and scale it as a thin strip along each side of the island shoreline. For a rectangular island you'll need 4 strips (one per side). Each strip should:
- Sit at the same height as the terrain edge (y ≈ 0)
- Be wide enough that a walking player overlaps it before reaching the water
- Have `collision_mask = 1` so it detects the player's `CharacterBody3D`

> **Tip:** Use the Godot editor's scale handles in the viewport. The `CollisionShape3D` inside shows as a wireframe box — scale the node until the box covers a 2–3 unit band along the shore.

- [ ] **Step 3: Set `island_center` on FishingSystem**

Select the `FishingSystem` node in the scene. In the Inspector, set `Island Center` to the world-space center of your island (probably `Vector3(0, 0, 0)` or wherever the terrain mid-point is).

- [ ] **Step 4: Commit scene changes**

```
git add scenes/MainScene/MainScene.tscn
git commit -m "feat: remove FishingSpot nodes; add ShoreZone strips around island perimeter"
```

---

## Task 7 — End-to-end playtest

- [ ] **Step 1: Run the scene and walk away from shore**

Stand in the middle of the island. Confirm no "Press F to Fish" prompt appears above the player.

- [ ] **Step 2: Walk to the shoreline**

Walk toward any edge of the island until the player enters a ShoreZone strip. Confirm the yellow "Press F to Fish" label appears above the player's head and pulses gently.

- [ ] **Step 3: Walk back inland**

Walk back toward the center. Confirm the prompt disappears immediately when the player exits the ShoreZone.

- [ ] **Step 4: Press F to fish**

Stand in a ShoreZone. Press F. Confirm:
- Player rotates to face the water
- The correct fishing animation plays (`fish_front`, `fish_left`, or `fish_right` depending on which shore)
- The fishing minigame starts (waiting for bite message appears)
- The prompt disappears while fishing

- [ ] **Step 5: Complete or cancel the minigame**

Let it complete (catch or fail). Confirm the player unfreezes, returns to idle/walk animation, and the prompt reappears (player is still standing in the ShoreZone).

- [ ] **Step 6: Verify night blocks fishing**

Wait for night (or toggle day/night). Try pressing F in a ShoreZone. Confirm the minigame does not start.

- [ ] **Step 7: Final commit**

```
git add .
git commit -m "feat: shore-based fishing with auto-facing and pulsing head prompt"
```
