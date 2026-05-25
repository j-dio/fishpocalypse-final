# Inventory, Pickup, Consume & Fishing Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-pickup + 4-slot inventory to the player, item consume/drop logic, a Stardew-style fishing bite reaction, and re-route fishing catches through ItemSpawner as physical world drops.

**Architecture:** `InventorySystem.gd` lives as a child node on `DebugPlayer`. Item template scenes each get a child `Area3D` that fires `body_entered` when the player (a CharacterBody3D in group `"player"`) walks over them — items call `InventorySystem.pickup(self)` directly. Fishing catches no longer touch inventory at all — `FishingSystem` calls `ItemSpawner.spawn_X()`, the item lands as a world pickup, and auto-pickup handles the rest.

**Tech Stack:** Godot 4.5, GDScript, existing scenes in `scenes/`, scripts in `scripts/`

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| CREATE | `scripts/components/health_component.gd` | Reusable HP node: `take_damage`, `heal`, `died` signal |
| CREATE | `scripts/player/inventory_system.gd` | 4-slot inventory: `pickup`, `use_item`, `drop_item`, signals |
| MODIFY | `scripts/itemSystem/0_weaponTemplate.gd` | Add `PickupArea` Area3D in `_ready`, `_on_picked_up` |
| MODIFY | `scripts/itemSystem/1_poleTemplate.gd` | Add `PickupArea` Area3D in `_ready`, `_on_picked_up` |
| MODIFY | `scripts/itemSystem/2_healingItemTemplate.gd` | Add `PickupArea` Area3D in `_ready`, `_on_picked_up` |
| MODIFY | `scripts/player/DebugPlayer.gd` | Wire `InventorySystem` + `HealthComponent`; debug use-item keys |
| MODIFY | `scenes/player/DebugPlayer.tscn` | Add `InventorySystem` + `HealthComponent` child nodes |
| MODIFY | `scripts/fishSystem/fishing_minigame.gd` | Add `WAITING`/`BITE` states, `start_wait()`, reaction window |
| MODIFY | `scenes/FishingRelated/fishing_minigame.tscn` | Add `WaitLabel` + `BiteLabel` Label nodes |
| MODIFY | `scripts/fishSystem/fishing_system.gd` | Add `item_spawner` export; route `_on_caught` through spawner |
| MODIFY | `scenes/FishingRelated/FishingMain.tscn` | Add `ItemSpawner` child node; assign `item_spawner` export |

---

## Task 1: Health Component

**Files:**
- Create: `scripts/components/health_component.gd`

- [ ] **Step 1: Create the file**

```gdscript
# scripts/components/health_component.gd
class_name HealthComponent
extends Node

signal died()
signal health_changed(current: float, maximum: float)

@export var max_hp: float = 100.0
var current_hp: float = 0.0

func _ready() -> void:
    current_hp = max_hp

func take_damage(amount: float) -> void:
    current_hp = maxf(current_hp - amount, 0.0)
    health_changed.emit(current_hp, max_hp)
    if current_hp <= 0.0:
        died.emit()

func heal(amount: float) -> void:
    current_hp = minf(current_hp + amount, max_hp)
    health_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
    return current_hp > 0.0
```

- [ ] **Step 2: Verify — open Godot, confirm no parse errors on the script**

- [ ] **Step 3: Commit**

```
git add scripts/components/health_component.gd
git commit -m "feat: add HealthComponent node (take_damage, heal, died signal)"
```

---

## Task 2: InventorySystem

**Files:**
- Create: `scripts/player/inventory_system.gd`

- [ ] **Step 1: Create the file**

```gdscript
# scripts/player/inventory_system.gd
class_name InventorySystem
extends Node

signal slot_changed(slot_name: String)
signal item_dropped(data: Resource)

var main_slot: FishWeaponData = null
var secondary_slot: FishWeaponData = null
var item_slot_1: HealingItemData = null
var item_slot_2: HealingItemData = null

var _active_weapon_slot: String = "main_slot"

# Called by item template nodes when the player walks over them.
func pickup(item_node: Node3D) -> void:
    var data: Resource = item_node.get("data")
    if data == null:
        push_warning("InventorySystem: pickup called on node with no 'data' property")
        return
    if data is FishWeaponData:
        _pickup_weapon(data, item_node)
    elif data is HealingItemData:
        _pickup_healing(data, item_node)
    elif data is FishingPoleData:
        item_node._on_picked_up()  # no slot yet; silently consume the node

func _pickup_weapon(data: FishWeaponData, item_node: Node3D) -> void:
    if main_slot == null:
        main_slot = data
        item_node._on_picked_up()
        slot_changed.emit("main_slot")
    elif secondary_slot == null:
        secondary_slot = data
        item_node._on_picked_up()
        slot_changed.emit("secondary_slot")
    else:
        # Both slots full — replace active slot, drop old data
        var old_data: FishWeaponData
        if _active_weapon_slot == "main_slot":
            old_data = main_slot
            main_slot = data
        else:
            old_data = secondary_slot
            secondary_slot = data
        item_node._on_picked_up()
        slot_changed.emit(_active_weapon_slot)
        item_dropped.emit(old_data)

func _pickup_healing(data: HealingItemData, item_node: Node3D) -> void:
    if item_slot_1 == null:
        item_slot_1 = data
        item_node._on_picked_up()
        slot_changed.emit("item_slot_1")
    elif item_slot_2 == null:
        item_slot_2 = data
        item_node._on_picked_up()
        slot_changed.emit("item_slot_2")
    # else: all item slots full — item stays on ground (do nothing)

# Use a healing item in a given slot. Slot must be "item_slot_1" or "item_slot_2".
func use_item(slot: String) -> void:
    var data: HealingItemData
    match slot:
        "item_slot_1": data = item_slot_1
        "item_slot_2": data = item_slot_2
        _: return
    if data == null:
        return
    var health: HealthComponent = get_parent().get_node_or_null("HealthComponent")
    if health:
        health.heal(data.base_heal_amount)
    else:
        push_warning("InventorySystem: HealthComponent not found on player — heal skipped")
    match slot:
        "item_slot_1": item_slot_1 = null
        "item_slot_2": item_slot_2 = null
    slot_changed.emit(slot)

# Clear a slot and emit item_dropped so HUD (Phase 7) can react.
func drop_item(slot: String) -> void:
    var data: Resource = null
    match slot:
        "main_slot":      data = main_slot;      main_slot = null
        "secondary_slot": data = secondary_slot; secondary_slot = null
        "item_slot_1":    data = item_slot_1;    item_slot_1 = null
        "item_slot_2":    data = item_slot_2;    item_slot_2 = null
        _: return
    if data == null:
        return
    item_dropped.emit(data)
    slot_changed.emit(slot)

func set_active_weapon_slot(slot: String) -> void:
    if slot in ["main_slot", "secondary_slot"]:
        _active_weapon_slot = slot
```

- [ ] **Step 2: Verify — open Godot, confirm no parse errors**

- [ ] **Step 3: Commit**

```
git add scripts/player/inventory_system.gd
git commit -m "feat: add InventorySystem with 4 slots, pickup routing, use_item, drop_item"
```

---

## Task 3: Item Template Pickup Integration

**Files:**
- Modify: `scripts/itemSystem/0_weaponTemplate.gd`
- Modify: `scripts/itemSystem/1_poleTemplate.gd`
- Modify: `scripts/itemSystem/2_healingItemTemplate.gd`

Each template gets:
- A `PickupArea` (Area3D) created programmatically in `_ready`
- `_on_body_entered` that detects the player and calls `InventorySystem.pickup(self)`
- `_on_picked_up` that `queue_free()`s the node

- [ ] **Step 1: Add pickup logic to `0_weaponTemplate.gd`**

Add after the closing of `shoot()`:

```gdscript
# --- Pickup (world item behaviour) ---

func _ready() -> void:
    _setup_pickup_area()

func _setup_pickup_area() -> void:
    var area := Area3D.new()
    area.name = "PickupArea"
    var col := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.2
    col.shape = sphere
    area.add_child(col)
    area.body_entered.connect(_on_body_entered)
    add_child(area)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    var inv: InventorySystem = body.get_node_or_null("InventorySystem")
    if inv:
        inv.pickup(self)

func _on_picked_up() -> void:
    queue_free()
```

- [ ] **Step 2: Add pickup logic to `1_poleTemplate.gd`**

Add after `apply_data()`:

```gdscript
# --- Pickup (world item behaviour) ---

func _ready() -> void:
    _setup_pickup_area()

func _setup_pickup_area() -> void:
    var area := Area3D.new()
    area.name = "PickupArea"
    var col := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.2
    col.shape = sphere
    area.add_child(col)
    area.body_entered.connect(_on_body_entered)
    add_child(area)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    var inv: InventorySystem = body.get_node_or_null("InventorySystem")
    if inv:
        inv.pickup(self)

func _on_picked_up() -> void:
    queue_free()
```

- [ ] **Step 3: Add pickup logic to `2_healingItemTemplate.gd`**

Add after `get_final_heal()`:

```gdscript
# --- Pickup (world item behaviour) ---

func _ready() -> void:
    _setup_pickup_area()

func _setup_pickup_area() -> void:
    var area := Area3D.new()
    area.name = "PickupArea"
    var col := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.2
    col.shape = sphere
    area.add_child(col)
    area.body_entered.connect(_on_body_entered)
    add_child(area)

func _on_body_entered(body: Node3D) -> void:
    if not body.is_in_group("player"):
        return
    var inv: InventorySystem = body.get_node_or_null("InventorySystem")
    if inv:
        inv.pickup(self)

func _on_picked_up() -> void:
    queue_free()
```

- [ ] **Step 4: Verify — open Godot, confirm no parse errors on all three scripts**

- [ ] **Step 5: Commit**

```
git add scripts/itemSystem/0_weaponTemplate.gd scripts/itemSystem/1_poleTemplate.gd scripts/itemSystem/2_healingItemTemplate.gd
git commit -m "feat: add PickupArea and _on_picked_up to all item templates"
```

---

## Task 4: Wire Player — Add InventorySystem + HealthComponent

**Files:**
- Modify: `scenes/player/DebugPlayer.tscn` (add two child nodes in Godot editor)
- Modify: `scripts/player/DebugPlayer.gd`

- [ ] **Step 1: In the Godot editor, open `scenes/player/DebugPlayer.tscn`**

Add two child nodes to `DebugPlayer` (the root CharacterBody3D):
1. Node → rename to `HealthComponent` → assign script `scripts/components/health_component.gd`
2. Node → rename to `InventorySystem` → assign script `scripts/player/inventory_system.gd`

Save the scene.

- [ ] **Step 2: Update `scripts/player/DebugPlayer.gd`**

Replace the full file with:

```gdscript
extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 9.0
@export var dodge_speed := 18.0
@export var dodge_time := 0.15
@export var gravity := 20.0

@onready var anim: AnimatedSprite3D = $Sprite3D
@onready var inventory: InventorySystem = $InventorySystem
@onready var health: HealthComponent = $HealthComponent

var is_dodging := false
var dodge_timer := 0.0
var dodge_dir := Vector3.ZERO
var current_anim := ""

func _ready() -> void:
    add_to_group("player")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0

    if is_dodging:
        dodge_timer -= delta
        velocity.x = dodge_dir.x * dodge_speed
        velocity.z = dodge_dir.z * dodge_speed
        _play_anim("dodge")
        if dodge_timer <= 0:
            is_dodging = false
        move_and_slide()
        return

    var input_dir := Vector3.ZERO
    if Input.is_action_pressed("D"): input_dir.x += 1
    if Input.is_action_pressed("A"): input_dir.x -= 1
    if Input.is_action_pressed("S"): input_dir.z += 1
    if Input.is_action_pressed("W"): input_dir.z -= 1
    input_dir = input_dir.normalized()

    var speed := run_speed if Input.is_action_pressed("RUN") else walk_speed
    velocity.x = input_dir.x * speed
    velocity.z = input_dir.z * speed

    if Input.is_action_just_pressed("DODGE") and input_dir != Vector3.ZERO:
        is_dodging = true
        dodge_timer = dodge_time
        dodge_dir = input_dir
        move_and_slide()
        return

    if Input.is_action_just_pressed("SHOOT"):
        print("Shoot! (CombatSystem not yet wired — Phase 3)")

    _play_move_anim()
    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    # Debug: use healing item in slot 1 with key 1, slot 2 with key 2
    if event.is_action_pressed("ui_accept"):   # Enter key — use item_slot_1
        inventory.use_item("item_slot_1")
        _log_inventory()
    if event.is_action_pressed("ui_cancel"):   # Escape key — drop main_slot
        inventory.drop_item("main_slot")
        _log_inventory()

func _log_inventory() -> void:
    print("[Inventory] main=%s | secondary=%s | item1=%s | item2=%s" % [
        inventory.main_slot.resource_path if inventory.main_slot else "empty",
        inventory.secondary_slot.resource_path if inventory.secondary_slot else "empty",
        inventory.item_slot_1.resource_path if inventory.item_slot_1 else "empty",
        inventory.item_slot_2.resource_path if inventory.item_slot_2 else "empty",
    ])

func _play_move_anim() -> void:
    if Input.is_action_pressed("W"):
        _play_anim("walk_back")
    elif Input.is_action_pressed("S"):
        _play_anim("walk_front")
    elif Input.is_action_pressed("A"):
        _play_anim("walk_left")
    elif Input.is_action_pressed("D"):
        _play_anim("walk_right")
    else:
        _play_anim("idle")

func _play_anim(name: String) -> void:
    if current_anim == name:
        return
    current_anim = name
    anim.play(name)
```

- [ ] **Step 3: Verify — run `DEBUGSCENE.tscn`. Open the Godot Remote inspector, select DebugPlayer, confirm `InventorySystem` and `HealthComponent` nodes are present as children.**

- [ ] **Step 4: Test pickup — in DEBUGSCENE, press `INTERACT` near the `Test_SpawnSystem` to spawn a random item (it already has this test binding). Walk the player over the spawned item. Check the Output panel — `[Inventory]` log should print showing the slot filled.**

- [ ] **Step 5: Commit**

```
git add scenes/player/DebugPlayer.tscn scripts/player/DebugPlayer.gd
git commit -m "feat: add InventorySystem and HealthComponent to DebugPlayer; wire auto-pickup"
```

---

## Task 5: Fishing Wait Mechanic — Script

**Files:**
- Modify: `scripts/fishSystem/fishing_minigame.gd`

- [ ] **Step 1: Replace `fishing_minigame.gd` with the updated version**

```gdscript
# scripts/fishSystem/fishing_minigame.gd
class_name FishingMinigame
extends Control

signal caught(item: Resource)
signal failed()

enum State { IDLE, WAITING, BITE, ACTIVE, RESULT_SUCCESS, RESULT_FAIL }

# Bar minigame constants
const RISE_ACCEL := 4.5
const FALL_GRAVITY := 3.2
const FILL_RATE := 0.35
const DRAIN_RATE := 0.22
const RESULT_DISPLAY_TIME := 0.8
const DIR_CHANGE_MIN := 0.15
const DIR_CHANGE_MAX := 0.45

# Wait/bite constants
const WAIT_MIN := 2.0
const WAIT_MAX := 5.0
const BITE_WINDOW_MIN := 0.6
const BITE_WINDOW_MAX := 0.8

@onready var _fish_bar: FishingBar = $CenterBox/ContentVBox/BarsHBox/FishBar
@onready var _catch_progress: ProgressBar = $CenterBox/ContentVBox/BarsHBox/CatchProgress
@onready var _wait_label: Label = $WaitLabel
@onready var _bite_label: Label = $BiteLabel

var _state: State = State.IDLE

# Bar minigame vars
var _fish_pos: float = 0.5
var _fish_vel: float = 0.0
var _fish_dir_timer: float = 0.0
var _zone_pos: float = 0.35
var _zone_vel: float = 0.0
var _zone_size: float = 0.25
var _fish_speed: float = 1.5
var _catch_val: float = 0.0
var _result_timer: float = 0.0

# Wait/bite vars
var _pending_item: Resource = null
var _pending_pole: FishingPoleData = null
var _wait_timer: float = 0.0
var _bite_window: float = 0.0

# Entry point called by FishingSystem (replaces old start()).
func start_wait(item: Resource, pole: FishingPoleData) -> void:
    _pending_item = item
    _pending_pole = pole
    _wait_timer = randf_range(WAIT_MIN, WAIT_MAX)
    _set_state(State.WAITING)

func cancel() -> void:
    _set_state(State.IDLE)

func is_active() -> bool:
    return _state != State.IDLE

func _set_state(s: State) -> void:
    _state = s
    # Hide everything by default
    visible = false
    _wait_label.visible = false
    _bite_label.visible = false
    $CenterBox.visible = false

    match s:
        State.IDLE:
            pass  # all hidden above

        State.WAITING:
            visible = true
            _wait_label.visible = true
            _wait_label.text = "Waiting for a bite..."

        State.BITE:
            visible = true
            _bite_label.visible = true
            _bite_label.text = "!! BITE !!\nPress [F]"

        State.ACTIVE:
            visible = true
            $CenterBox.visible = true
            _fish_pos = 0.5
            _fish_vel = 0.0
            _zone_pos = 0.35
            _zone_vel = 0.0
            _catch_val = 0.25
            _fish_dir_timer = 0.0
            _zone_size = _pending_pole.base_bar_size
            _fish_speed = _pending_pole.base_lure_speed

        State.RESULT_SUCCESS, State.RESULT_FAIL:
            visible = true
            $CenterBox.visible = true
            _result_timer = RESULT_DISPLAY_TIME

func _process(delta: float) -> void:
    match _state:
        State.WAITING:
            _wait_timer -= delta
            if _wait_timer <= 0.0:
                _bite_window = randf_range(BITE_WINDOW_MIN, BITE_WINDOW_MAX)
                _set_state(State.BITE)

        State.BITE:
            _bite_window -= delta
            if _bite_window <= 0.0:
                # Missed the window — reel in empty
                _set_state(State.IDLE)
                failed.emit()

        State.ACTIVE:
            _update_fish(delta)
            _update_zone(delta)
            _update_progress(delta)
            _fish_bar.fish_pos = _fish_pos
            _fish_bar.zone_pos = _zone_pos
            _fish_bar.zone_size = _zone_size
            _fish_bar.queue_redraw()
            _catch_progress.value = _catch_val

        State.RESULT_SUCCESS, State.RESULT_FAIL:
            _result_timer -= delta
            if _result_timer <= 0.0:
                var succeeded := (_state == State.RESULT_SUCCESS)
                _set_state(State.IDLE)
                if succeeded:
                    caught.emit(_pending_item)
                else:
                    failed.emit()

func _unhandled_input(event: InputEvent) -> void:
    if _state == State.BITE and event.is_action_pressed("INTERACT"):
        _set_state(State.ACTIVE)

func _update_fish(delta: float) -> void:
    _fish_dir_timer -= delta
    if _fish_dir_timer <= 0.0:
        _fish_vel = randf_range(-_fish_speed, _fish_speed)
        _fish_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
    _fish_pos += _fish_vel * delta
    if _fish_pos <= 0.0:
        _fish_pos = 0.0
        _fish_vel = absf(_fish_vel)
    elif _fish_pos >= 1.0:
        _fish_pos = 1.0
        _fish_vel = -absf(_fish_vel)

func _update_zone(delta: float) -> void:
    if InputMap.has_action("INTERACT") and Input.is_action_pressed("INTERACT"):
        _zone_vel -= RISE_ACCEL * delta
    _zone_vel += FALL_GRAVITY * delta
    _zone_vel = clampf(_zone_vel, -10.0, 10.0)
    _zone_pos += _zone_vel * delta
    _zone_pos = clampf(_zone_pos, 0.0, 1.0 - _zone_size)

func _update_progress(delta: float) -> void:
    if _is_fish_in_zone():
        _catch_val += FILL_RATE * delta
    else:
        _catch_val -= DRAIN_RATE * delta
    _catch_val = clampf(_catch_val, 0.0, 1.0)
    if _catch_val >= 1.0:
        _set_state(State.RESULT_SUCCESS)
    elif _catch_val <= 0.0:
        _set_state(State.RESULT_FAIL)

func _is_fish_in_zone() -> bool:
    return _fish_pos >= _zone_pos and _fish_pos <= (_zone_pos + _zone_size)
```

- [ ] **Step 2: Verify — open Godot, confirm no parse errors on `fishing_minigame.gd`**

Note: `$WaitLabel` and `$BiteLabel` will show warnings until added to the scene in the next task.

- [ ] **Step 3: Commit**

```
git add scripts/fishSystem/fishing_minigame.gd
git commit -m "feat: add WAITING/BITE states to FishingMinigame with Stardew-style reaction window"
```

---

## Task 6: Fishing Wait Mechanic — Scene Nodes

**Files:**
- Modify: `scenes/FishingRelated/fishing_minigame.tscn` (Godot editor)

- [ ] **Step 1: Open `scenes/FishingRelated/fishing_minigame.tscn` in the Godot editor**

Add two `Label` nodes as **direct children of the root `FishingMinigame` Control** (siblings of `CenterBox`):

**WaitLabel:**
- Name: `WaitLabel`
- Text: `Waiting for a bite...`
- Layout Mode: Anchors — set to `Center` preset (anchor to center of screen)
- Visible: `false` (unchecked in Inspector)
- Font size: 16 or larger (use Theme Override > Font Size)

**BiteLabel:**
- Name: `BiteLabel`
- Text: `!! BITE !!\nPress [F]`
- Layout Mode: Anchors — set to `Center` preset
- Visible: `false` (unchecked in Inspector)
- Font size: 24 (make it stand out)
- Modulate color: bright yellow `Color(1, 0.9, 0.1)` for contrast

Save the scene.

- [ ] **Step 2: Run `scenes/FishingRelated/FishingMain.tscn` directly (set it as the run scene temporarily). Stand the DebugPlayer near the `FishingSpot` (add a DebugPlayer to FishingMain if not present). Press `F` — the "Waiting for a bite..." label should appear. Wait 2–5 seconds — "!! BITE !!" should flash. Press `F` during the bite window — the bar minigame should open. Let the timer expire without pressing — it should return to idle silently.**

- [ ] **Step 3: Commit**

```
git add scenes/FishingRelated/fishing_minigame.tscn
git commit -m "feat: add WaitLabel and BiteLabel nodes to FishingMinigame scene"
```

---

## Task 7: Fishing System — Update `_start_fishing` Call

**Files:**
- Modify: `scripts/fishSystem/fishing_system.gd`

This is a one-line change: `_start_fishing` currently calls `minigame.start(item, pole)`. Change it to `minigame.start_wait(item, pole)`.

- [ ] **Step 1: In `fishing_system.gd`, find `_start_fishing()` and update the minigame call**

Find this block (around line 66–69):
```gdscript
func _start_fishing() -> void:
    var pole := _get_equipped_pole()
    if pole == null:
        return
    var item := _roll_item(pole)
    if item == null:
        push_warning("FishingSystem: catch pool empty (all weapons locked by spawn_day?)")
        return
    if _current_spot != null and _player != null:
        _player.global_rotation.y = _current_spot.facing_marker.global_rotation.y
    minigame.start(item, pole)
    _freeze_player()
```

Replace `minigame.start(item, pole)` with `minigame.start_wait(item, pole)`:

```gdscript
func _start_fishing() -> void:
    var pole := _get_equipped_pole()
    if pole == null:
        return
    var item := _roll_item(pole)
    if item == null:
        push_warning("FishingSystem: catch pool empty (all weapons locked by spawn_day?)")
        return
    if _current_spot != null and _player != null:
        _player.global_rotation.y = _current_spot.facing_marker.global_rotation.y
    minigame.start_wait(item, pole)
    _freeze_player()
```

- [ ] **Step 2: Verify — open Godot, confirm no parse errors**

- [ ] **Step 3: Commit**

```
git add scripts/fishSystem/fishing_system.gd
git commit -m "fix: call minigame.start_wait() from FishingSystem instead of deprecated start()"
```

---

## Task 8: Fishing → ItemSpawner Connection

**Files:**
- Modify: `scripts/fishSystem/fishing_system.gd`
- Modify: `scenes/FishingRelated/FishingMain.tscn` (Godot editor)

- [ ] **Step 1: Add `item_spawner` export and update `_on_caught` in `fishing_system.gd`**

At the top of `FishingSystem`, add:
```gdscript
@export var item_spawner: ItemSpawner
```

Replace the existing `_on_caught` and `_on_failed` methods:

```gdscript
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

func _get_item_rarity(item: Resource) -> RarityTier:
    var r: RarityTier = item.get("rarity") as RarityTier
    if r != null:
        return r
    if rarity_config and not rarity_config.tiers.is_empty():
        return rarity_config.tiers[0]
    return null
```

- [ ] **Step 2: Open `scenes/FishingRelated/FishingMain.tscn` in the Godot editor**

1. Add an `ItemSpawner` child node by instancing `scenes/ItemRelated/ItemSpawner.tscn` under the root `Main` node.
2. In the Inspector for `ItemSpawner`, assign `rarity_config` to `assets/resources/rarities/rarity_config.tres`.
3. Select the `FishingSystem` node. In its Inspector, assign the `Item Spawner` export slot to the `ItemSpawner` node you just added.

Save the scene.

- [ ] **Step 3: End-to-end verify — run `FishingMain.tscn` (with a DebugPlayer that has InventorySystem). Stand near the FishingSpot, press `F`, wait for the bite cue, press `F` again, complete the minigame. A physical item should arc out near the player. Walk over it — the Output panel should print `[Inventory] main=...` confirming the item was picked up.**

- [ ] **Step 4: Commit**

```
git add scripts/fishSystem/fishing_system.gd scenes/FishingRelated/FishingMain.tscn
git commit -m "feat: route fishing catches through ItemSpawner as physical world drops"
```

---

## Task 9: Update PHASES.md

- [ ] **Step 1: Open `1_docs/PHASES.md` and tick the newly completed items**

In **Phase 5**:
- [x] `HealingItemData` Resource
- [x] `ItemsDB`, `.tres` files
- [x] Item pickup scenes with `_on_picked_up` self-cleanup
- [x] `ItemSpawner` scatter drop
- [x] `InventorySystem` on Player (4 slots, pickup, use_item, drop_item)
- [x] `HealthComponent` (stub — heal works, take_damage wired in Phase 3)

In **Phase 6**:
- [x] Minigame `WAITING`/`BITE` states (Stardew-style wait mechanic)
- [x] Caught item delivered via `ItemSpawner` + auto-pickup

- [ ] **Step 2: Commit**

```
git add 1_docs/PHASES.md
git commit -m "docs: update PHASES.md — inventory, pickup, fishing improvements complete"
```
