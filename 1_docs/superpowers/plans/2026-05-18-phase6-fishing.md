# Phase 6 — Fishing System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement DIO's complete Phase 6 scope — all Resource data classes, 19 concrete `.tres` files populating `ItemsDB`, a `FishingSystem` node with DAY-gating and weighted catch logic, and a Stardew-style `FishingMinigame` bar-catch UI.

**Architecture:** Seven `Resource` subclasses define the data model. Nineteen `.tres` files populate `ItemsDB` (8 weapons, 4 healing items, 3 poles, 6 rarity tiers). `FishingSystem` is a `Node` in `Main.tscn` that listens to `GameState` signals and orchestrates catching. `FishingMinigame` is a standalone fullscreen `Control` scene with a state machine (IDLE → ACTIVE → RESULT), custom-drawn bar, and hold-to-rise player zone physics. `FishingSpot` is a reusable `Node3D` prefab (Area3D + Marker3D) placed at each water edge.

**Tech Stack:** Godot 4.5, GDScript 2.0, `.tres` text-format resources

**Prerequisite:** `GameState` autoload from SEN's Phase 0/1 must be registered in `project.godot`. `FishingSystem` degrades gracefully (push_error, no crash) if absent.

---

## File Map

| File | Responsibility |
|------|---------------|
| `resources/rarity_tier.gd` | `RarityTier` Resource — one row of the rarity table |
| `resources/rarity_config.gd` | `RarityConfig` Resource — ordered array of all tiers |
| `resources/projectile_data.gd` | `ProjectileData` stub — CJ's Phase 3 class; create only if absent |
| `resources/fish_weapon_data.gd` | `FishWeaponData` Resource — weapon stats + spawn gate |
| `resources/healing_item_data.gd` | `HealingItemData` Resource — heal stats |
| `resources/fishing_pole_data.gd` | `FishingPoleData` Resource — minigame bar/speed config |
| `resources/items_db.gd` | `ItemsDB` Resource — the loot pool arrays |
| `resources/data/rarities/common.tres` … `question.tres` | Six `RarityTier` instances |
| `resources/data/rarities/rarity_config.tres` | `RarityConfig` referencing the six tiers |
| `resources/data/weapons/sardine_shooter.tres` … `bakunawa_beam.tres` | Eight `FishWeaponData` instances |
| `resources/data/items/bandage.tres` … `sea_blessing.tres` | Four `HealingItemData` instances |
| `resources/data/poles/basic_pole.tres` … `spirit_pole.tres` | Three `FishingPoleData` instances |
| `resources/data/items_db.tres` | Populated `ItemsDB` instance |
| `scripts/fishing_bar.gd` | `FishingBar` — custom-draw Control for the minigame bar |
| `scripts/fishing_minigame.gd` | `FishingMinigame` — state machine + cursor physics |
| `scenes/ui/fishing_minigame.tscn` | Fullscreen `Control` scene for the minigame |
| `scripts/fishing_spot.gd` | `FishingSpot` — Area3D trigger + player-entered signal |
| `scenes/fishing_spot.tscn` | Reusable spot prefab (Area3D + FacingMarker) |
| `scripts/fishing_system.gd` | `FishingSystem` — orchestrates DAY-gating, catch roll, pickup |

---

## Task 1 — Folder structure + Resource GDScript classes

**Files:**
- Create: `resources/rarity_tier.gd`
- Create: `resources/rarity_config.gd`
- Create: `resources/projectile_data.gd`
- Create: `resources/fish_weapon_data.gd`
- Create: `resources/healing_item_data.gd`
- Create: `resources/fishing_pole_data.gd`
- Create: `resources/items_db.gd`

- [ ] **Create folder tree**

```bash
mkdir -p resources/data/rarities resources/data/weapons resources/data/items resources/data/poles
mkdir -p scripts scenes/ui
```

- [ ] **Write `resources/rarity_tier.gd`**

```gdscript
class_name RarityTier
extends Resource

@export var name: String = ""
@export var color: Color = Color.WHITE
@export var weapon_multiplier: float = 1.0
@export var shot_delay_multiplier: float = 1.0
@export var lure_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0
@export var heal_multiplier: float = 1.0
```

- [ ] **Write `resources/rarity_config.gd`**

```gdscript
class_name RarityConfig
extends Resource

@export var tiers: Array[RarityTier] = []
```

- [ ] **Write `resources/projectile_data.gd`** (stub — skip if CJ already created it)

```gdscript
class_name ProjectileData
extends Resource

enum OwnerType { PLAYER, ENEMY }

@export var owner_type: OwnerType = OwnerType.PLAYER
@export var speed: float = 20.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0
@export var sprite: Texture2D
```

- [ ] **Write `resources/fish_weapon_data.gd`**

```gdscript
class_name FishWeaponData
extends Resource

@export var spawn_day: int = 1
@export var base_damage_per_shot: float = 10.0
@export var base_shot_delay: float = 0.5
@export var base_projectiles_per_shot: int = 1
@export var base_recharge_cost: float = 10.0
@export var rarity: RarityTier
@export var projectile: ProjectileData
@export var sprite_frames: SpriteFrames
@export var sfx: AudioStream
```

- [ ] **Write `resources/healing_item_data.gd`**

```gdscript
class_name HealingItemData
extends Resource

enum ItemClass { I = 1, II = 2, III = 3, IV = 4 }

@export var item_class: ItemClass = ItemClass.I
@export var base_heal_amount: float = 10.0
@export var use_delay: float = 1.0
@export var stack_limit: int = 5
@export var rarity: RarityTier
@export var sprite: Texture2D
```

- [ ] **Write `resources/fishing_pole_data.gd`**

```gdscript
class_name FishingPoleData
extends Resource

@export var base_bar_size: float = 0.25
@export var base_lure_speed: float = 1.5
@export var base_lure_chance: float = 0.4
@export var rarity: RarityTier
@export var sprite_frames: SpriteFrames
```

- [ ] **Write `resources/items_db.gd`**

```gdscript
class_name ItemsDB
extends Resource

@export var fish_weapons: Array[FishWeaponData] = []
@export var healing_items: Array[HealingItemData] = []
@export var fishing_poles: Array[FishingPoleData] = []
```

- [ ] **Verify in Godot** — Open project. Check Output for parse errors. In the FileSystem dock, all seven `.gd` files should appear. Create a dummy Resource in the editor (Ctrl+N → Search "RarityTier") to confirm class registration.

- [ ] **Commit**

```bash
git add resources/
git commit -m "feat: add Resource subclass GDScript files for Phase 6 data model"
```

---

## Task 2 — Rarity tier `.tres` files

**Files:** `resources/data/rarities/common.tres`, `uncommon.tres`, `rare.tres`, `epic.tres`, `legendary.tres`, `question.tres`, `rarity_config.tres`

- [ ] **Write `resources/data/rarities/common.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "Common"
color = Color(0.651, 0.651, 0.651, 1)
weapon_multiplier = 1.0
shot_delay_multiplier = 1.0
lure_multiplier = 1.0
cost_multiplier = 1.0
heal_multiplier = 1.0
```

- [ ] **Write `resources/data/rarities/uncommon.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "Uncommon"
color = Color(0.196, 0.804, 0.196, 1)
weapon_multiplier = 1.3
shot_delay_multiplier = 0.9
lure_multiplier = 1.2
cost_multiplier = 0.9
heal_multiplier = 1.2
```

- [ ] **Write `resources/data/rarities/rare.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "Rare"
color = Color(0.255, 0.412, 0.882, 1)
weapon_multiplier = 1.7
shot_delay_multiplier = 0.8
lure_multiplier = 1.5
cost_multiplier = 0.8
heal_multiplier = 1.5
```

- [ ] **Write `resources/data/rarities/epic.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "Epic"
color = Color(0.627, 0.125, 0.941, 1)
weapon_multiplier = 2.2
shot_delay_multiplier = 0.7
lure_multiplier = 2.0
cost_multiplier = 0.7
heal_multiplier = 2.0
```

- [ ] **Write `resources/data/rarities/legendary.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "Legendary"
color = Color(1.0, 0.843, 0.0, 1)
weapon_multiplier = 3.0
shot_delay_multiplier = 0.6
lure_multiplier = 3.0
cost_multiplier = 0.6
heal_multiplier = 3.0
```

- [ ] **Write `resources/data/rarities/question.tres`**

```
[gd_resource type="Resource" script_class="RarityTier" load_steps=2 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_tier.gd" id="1_rt"]

[resource]
script = ExtResource("1_rt")
name = "???"
color = Color(1.0, 0.0, 0.5, 1)
weapon_multiplier = 5.0
shot_delay_multiplier = 0.4
lure_multiplier = 5.0
cost_multiplier = 0.4
heal_multiplier = 5.0
```

- [ ] **Write `resources/data/rarities/rarity_config.tres`**

```
[gd_resource type="Resource" script_class="RarityConfig" load_steps=8 version=4.4]

[ext_resource type="Script" path="res://resources/rarity_config.gd" id="1_rc"]
[ext_resource type="Resource" path="res://resources/data/rarities/common.tres" id="2_c"]
[ext_resource type="Resource" path="res://resources/data/rarities/uncommon.tres" id="3_u"]
[ext_resource type="Resource" path="res://resources/data/rarities/rare.tres" id="4_r"]
[ext_resource type="Resource" path="res://resources/data/rarities/epic.tres" id="5_e"]
[ext_resource type="Resource" path="res://resources/data/rarities/legendary.tres" id="6_l"]
[ext_resource type="Resource" path="res://resources/data/rarities/question.tres" id="7_q"]

[resource]
script = ExtResource("1_rc")
tiers = [ExtResource("2_c"), ExtResource("3_u"), ExtResource("4_r"), ExtResource("5_e"), ExtResource("6_l"), ExtResource("7_q")]
```

- [ ] **Verify in Godot** — Inspector-click `rarity_config.tres`. The `Tiers` array should show 6 entries with correct names/colors.

- [ ] **Commit**

```bash
git add resources/data/rarities/
git commit -m "feat: add rarity tier tres files and RarityConfig"
```

---

## Task 3 — FishWeaponData `.tres` files (8 weapons)

**Files:** `resources/data/weapons/` — all 8 weapon `.tres` files

Each file follows this template (only varying fields shown per weapon). The `projectile` field is omitted (defaults null — Phase 3 populates it).

- [ ] **Write `resources/data/weapons/sardine_shooter.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/common.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 1
base_damage_per_shot = 8.0
base_shot_delay = 0.9
base_projectiles_per_shot = 1
base_recharge_cost = 8.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/tuna_lobber.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/common.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 1
base_damage_per_shot = 12.0
base_shot_delay = 1.4
base_projectiles_per_shot = 1
base_recharge_cost = 10.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/mackerel_burst.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/uncommon.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 3
base_damage_per_shot = 9.0
base_shot_delay = 0.8
base_projectiles_per_shot = 2
base_recharge_cost = 14.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/bangus_blaster.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/uncommon.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 5
base_damage_per_shot = 7.0
base_shot_delay = 0.4
base_projectiles_per_shot = 1
base_recharge_cost = 7.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/squid_spray.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/rare.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 8
base_damage_per_shot = 11.0
base_shot_delay = 0.7
base_projectiles_per_shot = 3
base_recharge_cost = 18.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/crab_cannon.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/epic.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 12
base_damage_per_shot = 35.0
base_shot_delay = 1.6
base_projectiles_per_shot = 1
base_recharge_cost = 22.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/shark_shotgun.tres`**

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/epic.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 18
base_damage_per_shot = 18.0
base_shot_delay = 1.0
base_projectiles_per_shot = 4
base_recharge_cost = 28.0
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/weapons/bakunawa_beam.tres`** _(placeholder for Philippine mythology legendary — name/skin assigned Phase 8)_

```
[gd_resource type="Resource" script_class="FishWeaponData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fish_weapon_data.gd" id="1_fwd"]
[ext_resource type="Resource" path="res://resources/data/rarities/legendary.tres" id="2_rar"]

[resource]
script = ExtResource("1_fwd")
spawn_day = 25
base_damage_per_shot = 80.0
base_shot_delay = 1.2
base_projectiles_per_shot = 1
base_recharge_cost = 40.0
rarity = ExtResource("2_rar")
```

- [ ] **Verify in Godot** — Click `sardine_shooter.tres` in FileSystem. Inspector should show all fields with correct values and the Rarity sub-resource showing "Common".

- [ ] **Commit**

```bash
git add resources/data/weapons/
git commit -m "feat: add 8 FishWeaponData tres files with spawn_day progression"
```

---

## Task 4 — HealingItemData + FishingPoleData `.tres` files

**Files:** `resources/data/items/` (4 files), `resources/data/poles/` (3 files)

- [ ] **Write `resources/data/items/bandage.tres`**

```
[gd_resource type="Resource" script_class="HealingItemData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/healing_item_data.gd" id="1_hid"]
[ext_resource type="Resource" path="res://resources/data/rarities/common.tres" id="2_rar"]

[resource]
script = ExtResource("1_hid")
item_class = 1
base_heal_amount = 10.0
use_delay = 0.8
stack_limit = 5
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/items/fish_wrap.tres`**

```
[gd_resource type="Resource" script_class="HealingItemData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/healing_item_data.gd" id="1_hid"]
[ext_resource type="Resource" path="res://resources/data/rarities/uncommon.tres" id="2_rar"]

[resource]
script = ExtResource("1_hid")
item_class = 2
base_heal_amount = 25.0
use_delay = 1.0
stack_limit = 4
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/items/herbal_brew.tres`**

```
[gd_resource type="Resource" script_class="HealingItemData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/healing_item_data.gd" id="1_hid"]
[ext_resource type="Resource" path="res://resources/data/rarities/rare.tres" id="2_rar"]

[resource]
script = ExtResource("1_hid")
item_class = 3
base_heal_amount = 50.0
use_delay = 1.2
stack_limit = 3
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/items/sea_blessing.tres`**

```
[gd_resource type="Resource" script_class="HealingItemData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/healing_item_data.gd" id="1_hid"]
[ext_resource type="Resource" path="res://resources/data/rarities/epic.tres" id="2_rar"]

[resource]
script = ExtResource("1_hid")
item_class = 4
base_heal_amount = 100.0
use_delay = 1.5
stack_limit = 2
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/poles/basic_pole.tres`**

```
[gd_resource type="Resource" script_class="FishingPoleData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fishing_pole_data.gd" id="1_fpd"]
[ext_resource type="Resource" path="res://resources/data/rarities/common.tres" id="2_rar"]

[resource]
script = ExtResource("1_fpd")
base_bar_size = 0.25
base_lure_speed = 1.6
base_lure_chance = 0.4
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/poles/reinforced_pole.tres`**

```
[gd_resource type="Resource" script_class="FishingPoleData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fishing_pole_data.gd" id="1_fpd"]
[ext_resource type="Resource" path="res://resources/data/rarities/uncommon.tres" id="2_rar"]

[resource]
script = ExtResource("1_fpd")
base_bar_size = 0.35
base_lure_speed = 1.3
base_lure_chance = 0.55
rarity = ExtResource("2_rar")
```

- [ ] **Write `resources/data/poles/spirit_pole.tres`**

```
[gd_resource type="Resource" script_class="FishingPoleData" load_steps=3 version=4.4]

[ext_resource type="Script" path="res://resources/fishing_pole_data.gd" id="1_fpd"]
[ext_resource type="Resource" path="res://resources/data/rarities/rare.tres" id="2_rar"]

[resource]
script = ExtResource("1_fpd")
base_bar_size = 0.5
base_lure_speed = 0.9
base_lure_chance = 0.75
rarity = ExtResource("2_rar")
```

- [ ] **Commit**

```bash
git add resources/data/items/ resources/data/poles/
git commit -m "feat: add HealingItemData and FishingPoleData tres files"
```

---

## Task 5 — Populate `ItemsDB.tres`

**File:** `resources/data/items_db.tres`

- [ ] **Write `resources/data/items_db.tres`**

```
[gd_resource type="Resource" script_class="ItemsDB" load_steps=17 version=4.4]

[ext_resource type="Script" path="res://resources/items_db.gd" id="1_db"]
[ext_resource type="Resource" path="res://resources/data/weapons/sardine_shooter.tres" id="2_w1"]
[ext_resource type="Resource" path="res://resources/data/weapons/tuna_lobber.tres" id="3_w2"]
[ext_resource type="Resource" path="res://resources/data/weapons/mackerel_burst.tres" id="4_w3"]
[ext_resource type="Resource" path="res://resources/data/weapons/bangus_blaster.tres" id="5_w4"]
[ext_resource type="Resource" path="res://resources/data/weapons/squid_spray.tres" id="6_w5"]
[ext_resource type="Resource" path="res://resources/data/weapons/crab_cannon.tres" id="7_w6"]
[ext_resource type="Resource" path="res://resources/data/weapons/shark_shotgun.tres" id="8_w7"]
[ext_resource type="Resource" path="res://resources/data/weapons/bakunawa_beam.tres" id="9_w8"]
[ext_resource type="Resource" path="res://resources/data/items/bandage.tres" id="10_h1"]
[ext_resource type="Resource" path="res://resources/data/items/fish_wrap.tres" id="11_h2"]
[ext_resource type="Resource" path="res://resources/data/items/herbal_brew.tres" id="12_h3"]
[ext_resource type="Resource" path="res://resources/data/items/sea_blessing.tres" id="13_h4"]
[ext_resource type="Resource" path="res://resources/data/poles/basic_pole.tres" id="14_p1"]
[ext_resource type="Resource" path="res://resources/data/poles/reinforced_pole.tres" id="15_p2"]
[ext_resource type="Resource" path="res://resources/data/poles/spirit_pole.tres" id="16_p3"]

[resource]
script = ExtResource("1_db")
fish_weapons = [ExtResource("2_w1"), ExtResource("3_w2"), ExtResource("4_w3"), ExtResource("5_w4"), ExtResource("6_w5"), ExtResource("7_w6"), ExtResource("8_w7"), ExtResource("9_w8")]
healing_items = [ExtResource("10_h1"), ExtResource("11_h2"), ExtResource("12_h3"), ExtResource("13_h4")]
fishing_poles = [ExtResource("14_p1"), ExtResource("15_p2"), ExtResource("16_p3")]
```

- [ ] **Verify in Godot** — Click `items_db.tres`. Inspector arrays should show 8 weapons, 4 healing items, 3 poles. Expand one entry to confirm nested data loads.

- [ ] **Commit**

```bash
git add resources/data/items_db.tres
git commit -m "feat: populate ItemsDB tres with 8 weapons, 4 healing items, 3 poles"
```

---

## Task 6 — FishingSpot scene + script

**Files:**
- Create: `scripts/fishing_spot.gd`
- Create: `scenes/fishing_spot.tscn`

- [ ] **Write `scripts/fishing_spot.gd`**

```gdscript
class_name FishingSpot
extends Node3D

signal player_entered(spot: FishingSpot, player: Node3D)
signal player_exited()

@onready var facing_marker: Marker3D = $FacingMarker
@onready var _area: Area3D = $FishingSpotArea

func _ready() -> void:
    _area.body_entered.connect(_on_body_entered)
    _area.body_exited.connect(_on_body_exited)
    add_to_group("fishing_spots")

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player"):
        player_entered.emit(self, body)

func _on_body_exited(body: Node3D) -> void:
    if body.is_in_group("player"):
        player_exited.emit()
```

- [ ] **Write `scenes/fishing_spot.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/fishing_spot.gd" id="1_fsp"]

[sub_resource type="CylinderShape3D" id="SubResource_1"]
height = 1.5
radius = 1.2

[node name="FishingSpot" type="Node3D"]
script = ExtResource("1_fsp")

[node name="FishingSpotArea" type="Area3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="FishingSpotArea"]
shape = SubResource("SubResource_1")

[node name="FacingMarker" type="Marker3D" parent="."]
position = Vector3(0.0, 0.0, -2.0)
```

- [ ] **Verify in Godot** — Open `fishing_spot.tscn`. Scene tree should show: FishingSpot → FishingSpotArea → CollisionShape3D and FacingMarker. The CollisionShape3D should display a cylinder in the 3D viewport.

- [ ] **Commit**

```bash
git add scripts/fishing_spot.gd scenes/fishing_spot.tscn
git commit -m "feat: add FishingSpot scene with Area3D trigger and FacingMarker"
```

---

## Task 7 — FishingBar + FishingMinigame script + scene

**Files:**
- Create: `scripts/fishing_bar.gd`
- Create: `scripts/fishing_minigame.gd`
- Create: `scenes/ui/fishing_minigame.tscn`

- [ ] **Write `scripts/fishing_bar.gd`** — Custom-draw Control that renders bar contents

```gdscript
class_name FishingBar
extends Control

var fish_pos: float = 0.5
var zone_pos: float = 0.35
var zone_size: float = 0.25

func _draw() -> void:
    var w := size.x
    var h := size.y

    # Background
    draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.08, 0.13))

    # Catch zone — fixed blue band (center 40% of bar)
    var cz_y := h * 0.30
    var cz_h := h * 0.40
    draw_rect(Rect2(1.0, cz_y, w - 2.0, cz_h), Color(0.18, 0.48, 0.9, 0.15))
    draw_line(Vector2(1.0, cz_y), Vector2(w - 1.0, cz_y), Color(0.3, 0.6, 1.0, 0.7), 1.0)
    draw_line(Vector2(1.0, cz_y + cz_h), Vector2(w - 1.0, cz_y + cz_h), Color(0.3, 0.6, 1.0, 0.7), 1.0)

    # Player zone (green, hold to rise)
    var pz_top := zone_pos * h
    var pz_bot := (zone_pos + zone_size) * h
    draw_rect(Rect2(2.0, pz_top, w - 4.0, pz_bot - pz_top), Color(0.71, 0.91, 0.32, 0.78))
    draw_line(Vector2(2.0, pz_top), Vector2(w - 2.0, pz_top), Color(0.83, 1.0, 0.44), 2.0)

    # Fish cursor (red, 6 px tall)
    var fc_y := fish_pos * h
    draw_rect(Rect2(0.0, fc_y - 3.0, w, 6.0), Color(1.0, 0.42, 0.42))
    draw_rect(Rect2(0.0, fc_y - 1.0, w, 2.0), Color(1.0, 0.75, 0.75))
```

- [ ] **Write `scripts/fishing_minigame.gd`**

```gdscript
class_name FishingMinigame
extends Control

signal caught(item: Resource)
signal failed()

enum State { IDLE, ACTIVE, RESULT_SUCCESS, RESULT_FAIL }

const RISE_ACCEL := 4.5
const FALL_GRAVITY := 3.2
const FILL_RATE := 0.35
const DRAIN_RATE := 0.22
const RESULT_DISPLAY_TIME := 0.8
const DIR_CHANGE_MIN := 0.15
const DIR_CHANGE_MAX := 0.45

@onready var _fish_bar: FishingBar = $CenterBox/ContentVBox/BarsHBox/FishBar
@onready var _catch_progress: ProgressBar = $CenterBox/ContentVBox/BarsHBox/CatchProgress

var _state: State = State.IDLE
var _fish_pos: float = 0.5
var _fish_vel: float = 0.0
var _fish_dir_timer: float = 0.0
var _zone_pos: float = 0.35
var _zone_vel: float = 0.0
var _zone_size: float = 0.25
var _fish_speed: float = 1.5
var _catch_val: float = 0.0
var _pending_item: Resource = null
var _result_timer: float = 0.0

func start(item: Resource, pole: FishingPoleData) -> void:
    _pending_item = item
    _zone_size = pole.base_bar_size
    _fish_speed = pole.base_lure_speed
    _fish_pos = 0.5
    _fish_vel = 0.0
    _zone_pos = 0.35
    _zone_vel = 0.0
    _catch_val = 0.25  # start at 25% so first drain doesn't instant-fail
    _fish_dir_timer = 0.0
    _set_state(State.ACTIVE)

func cancel() -> void:
    _set_state(State.IDLE)

func is_active() -> bool:
    return _state == State.ACTIVE

func _set_state(s: State) -> void:
    _state = s
    match s:
        State.IDLE:
            visible = false
        State.ACTIVE:
            visible = true
        State.RESULT_SUCCESS, State.RESULT_FAIL:
            _result_timer = RESULT_DISPLAY_TIME

func _process(delta: float) -> void:
    match _state:
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
    if Input.is_action_pressed("interact"):
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

- [ ] **Write `scenes/ui/fishing_minigame.tscn`**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/fishing_minigame.gd" id="1_fmg"]
[ext_resource type="Script" path="res://scripts/fishing_bar.gd" id="2_fb"]

[node name="FishingMinigame" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
visible = false
script = ExtResource("1_fmg")

[node name="CenterBox" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="ContentVBox" type="VBoxContainer" parent="CenterBox"]
layout_mode = 2
theme_override_constants/separation = 6

[node name="BarsHBox" type="HBoxContainer" parent="CenterBox/ContentVBox"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="FishBar" type="Control" parent="CenterBox/ContentVBox/BarsHBox"]
layout_mode = 2
custom_minimum_size = Vector2(40.0, 200.0)
script = ExtResource("2_fb")

[node name="CatchProgress" type="ProgressBar" parent="CenterBox/ContentVBox/BarsHBox"]
layout_mode = 2
custom_minimum_size = Vector2(14.0, 200.0)
show_percentage = false
fill_mode = 3
min_value = 0.0
max_value = 1.0
step = 0.001
value = 0.0

[node name="HoldLabel" type="Label" parent="CenterBox/ContentVBox"]
layout_mode = 2
text = "Hold [F] to rise"
horizontal_alignment = 1
```

- [ ] **Verify in Godot** — Open `fishing_minigame.tscn`. Temporarily set `visible = true` on the root node. Run the scene (F6). You should see: a dark 40×200 bar on the left, a thin progress bar on the right, and "Hold [F] to rise" below. The bar canvas stays blank (no cursor) since `_state == IDLE`. No errors in Output.

- [ ] **Commit**

```bash
git add scripts/fishing_bar.gd scripts/fishing_minigame.gd scenes/ui/fishing_minigame.tscn
git commit -m "feat: add FishingMinigame scene with bar-catch state machine"
```

---

## Task 8 — FishingSystem script

**File:** `scripts/fishing_system.gd`

- [ ] **Write `scripts/fishing_system.gd`**

```gdscript
class_name FishingSystem
extends Node

# Weights indexed by rarity order in RarityConfig.tiers (common=0 … ???=5)
const BASE_RARITY_WEIGHTS: Array[float] = [100.0, 60.0, 30.0, 10.0, 3.0, 1.0]

@export var items_db: ItemsDB
@export var rarity_config: RarityConfig
@export var minigame: FishingMinigame

var _can_fish: bool = false
var _in_spot: bool = false
var _current_spot: FishingSpot = null
var _player: Node3D = null
var _game_state: Node = null

func _ready() -> void:
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
    for spot: FishingSpot in get_tree().get_nodes_in_group("fishing_spots"):
        spot.player_entered.connect(_on_spot_entered)
        spot.player_exited.connect(_on_spot_exited)

func _on_day_started() -> void:
    _can_fish = true

func _on_day_ended() -> void:
    _can_fish = false
    if minigame.is_active():
        minigame.cancel()

func _unhandled_input(event: InputEvent) -> void:
    if not _can_fish or not _in_spot or minigame.is_active():
        return
    if event.is_action_pressed("interact"):
        _start_fishing()

func _start_fishing() -> void:
    if _current_spot != null and _player != null:
        _player.global_rotation.y = _current_spot.facing_marker.global_rotation.y
    var pole := _get_equipped_pole()
    if pole == null:
        return
    var item := _roll_item(pole)
    if item == null:
        push_warning("FishingSystem: catch pool empty (all weapons locked by spawn_day?)")
        return
    minigame.start(item, pole)

func _roll_item(pole: FishingPoleData) -> Resource:
    var pool: Array[Resource] = []
    var weights: Array[float] = []
    var day: int = _game_state.get("day_count") if _game_state != null else 1

    for w: FishWeaponData in items_db.fish_weapons:
        if w.spawn_day <= day:
            var idx := _rarity_index(w.rarity)
            pool.append(w)
            weights.append(BASE_RARITY_WEIGHTS[idx] * (1.0 + pole.base_lure_chance * w.rarity.lure_multiplier))

    for h: HealingItemData in items_db.healing_items:
        var idx := _rarity_index(h.rarity)
        pool.append(h)
        weights.append(BASE_RARITY_WEIGHTS[idx] * (1.0 + pole.base_lure_chance * h.rarity.lure_multiplier))

    for p: FishingPoleData in items_db.fishing_poles:
        var idx := _rarity_index(p.rarity)
        pool.append(p)
        weights.append(BASE_RARITY_WEIGHTS[idx] * (1.0 + pole.base_lure_chance * p.rarity.lure_multiplier))

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

func _on_spot_entered(spot: FishingSpot, player: Node3D) -> void:
    _in_spot = true
    _current_spot = spot
    _player = player

func _on_spot_exited() -> void:
    _in_spot = false
    _current_spot = null

func _on_caught(item: Resource) -> void:
    if _player == null:
        return
    var inv := _player.get_node_or_null("InventorySystem")
    if inv == null:
        push_warning("FishingSystem: InventorySystem not on player — item lost until CJ's Phase 5 is merged")
        return
    inv.pickup(item)

func _on_failed() -> void:
    pass  # Phase 8: play fail SFX via AudioManager
```

- [ ] **Verify parse** — Open Godot. Confirm `fishing_system.gd` shows no errors in Output. No scene wiring yet; errors about missing `GameState` are expected and intentional.

- [ ] **Commit**

```bash
git add scripts/fishing_system.gd
git commit -m "feat: add FishingSystem with DAY-gating, weighted catch roll, and pickup handoff"
```

---

## Task 9 — Integration into Main.tscn + end-to-end test

**Prerequisite:** GameState autoload from SEN must be registered (`project.godot` autoloads section). If not yet available, add a minimal stub (see note below) to unblock testing.

**Note — GameState stub (only if SEN's is absent):** Create `autoloads/game_state.gd` with bare signals and `day_count`:

```gdscript
extends Node

signal day_started()
signal night_started()
signal wave_cleared()
signal buff_day_reached()

var day_count: int = 1
```

Then in `project.godot` add:

```
[autoload]
GameState="*res://autoloads/game_state.gd"
```

- [ ] **Add `interact` to the input map in `project.godot`**

The existing input map uses `W`, `A`, `S`, `D`, `DODGE`, `SHOOT` — `interact` is absent. Both `FishingSystem` and `FishingMinigame` call `Input.is_action_pressed("interact")` and will crash without it. Add this block inside the `[input]` section (maps to F key, physical keycode 70):

```
interact={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":102,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Register GameState stub** _(skip if SEN's is already in place — confirmed absent as of 2026-05-18)_

Create `autoloads/game_state.gd` with the stub above, then add a new `[autoload]` section to `project.godot`:

```
[autoload]

GameState="*res://autoloads/game_state.gd"
```

- [ ] **Add FishingSystem + FishingMinigame + FishingSpot to `Main.tscn`**

If `Main.tscn` doesn't exist yet, create a minimal placeholder:

```
[gd_scene load_steps=1 format=3]

[node name="Main" type="Node3D"]
```

Then add children by editing the file — append after the `[node name="Main"...]` block:

```
[ext_resource type="Script" path="res://scripts/fishing_system.gd" id="N_fs"]
[ext_resource type="PackedScene" path="res://scenes/ui/fishing_minigame.tscn" id="N_fmg"]
[ext_resource type="PackedScene" path="res://scenes/fishing_spot.tscn" id="N_fsp"]
[ext_resource type="Resource" path="res://resources/data/items_db.tres" id="N_db"]
[ext_resource type="Resource" path="res://resources/data/rarities/rarity_config.tres" id="N_rc"]

[node name="FishingSystem" type="Node" parent="."]
script = ExtResource("N_fs")
items_db = ExtResource("N_db")
rarity_config = ExtResource("N_rc")

[node name="FishingMinigame" parent="." instance=ExtResource("N_fmg")]

[node name="FishingSpot" parent="." instance=ExtResource("N_fsp")]
position = Vector3(5.0, 0.0, 0.0)
```

> **Easier alternative:** Add the nodes manually in the Godot editor Scene panel, then set `items_db`, `rarity_config`, and `minigame` in the Inspector on FishingSystem.

- [ ] **Wire FishingSystem.minigame in Inspector** — In the Godot editor, select the `FishingSystem` node, find the `Minigame` export, and assign the `FishingMinigame` node.

- [ ] **Add player to `"player"` group** _(required for FishingSpot to recognise it)_ — Select the Player node, go to Node → Groups, add `"player"`.

- [ ] **Manual end-to-end test**

Run the main scene (F5). Check each item:

| # | Action | Expected |
|---|--------|----------|
| 1 | Open Output before running | No parse errors on any Phase 6 `.gd` file |
| 2 | Run scene; GameState stub is loaded | No "GameState not found" error in Output |
| 3 | Walk player character into FishingSpot cylinder | `FishingSystem._on_spot_entered` fires (add a temporary `print("in spot")` to confirm, then remove) |
| 4 | Press F while in spot (DAY state) | `FishingMinigame` becomes visible; bar and progress bar appear |
| 5 | Hold F | Green player zone rises; release F → zone falls |
| 6 | Keep fish cursor inside player zone | Progress bar fills upward |
| 7 | Let fish cursor escape zone | Progress bar drains |
| 8 | Fill progress to 100% | Minigame closes; `caught` signal fires; Output shows item name (add temp `print(item.name)` in `_on_caught`) |
| 9 | Let progress drain to 0% | Minigame closes; `failed` signal fires |
| 10 | Emit `night_started` from GameState (call `GameState.night_started.emit()` in console or stub) | Minigame cancels mid-game if open |

- [ ] **Remove any temporary `print()` / debug calls** added during testing.

- [ ] **Final commit**

```bash
git add .
git commit -m "feat: integrate Phase 6 fishing system into Main scene — Phase 6 complete"
```

---

## Self-Review Notes

- `_catch_val` starts at `0.25` (not `0.0`) so first frame of no-overlap doesn't instantly fail
- `FishingSystem._unhandled_input` suppressed while `minigame.is_active()` — prevents double-trigger of the same `interact` press
- `_get_equipped_pole()` falls back to `items_db.fishing_poles[0]` if `InventorySystem` absent — fishing works before CJ's Phase 5 merges
- `_rarity_index()` returns 0 (common weight) if rarity not found in config — safe default, no crash
- `bakunawa_beam.tres` is the Phase 8 placeholder for the legendary mythology weapon — name and sprite assigned then
- `projectile` field omitted from all weapon `.tres` files — defaults to null until CJ's Phase 3 populates it
