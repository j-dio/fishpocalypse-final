extends Node
class_name ItemSpawner

@export var dbg := false

# Trajectory
@export var drop_height: float = 10.0
# REMOVED: drop_horizontal_force; was exported but never used

# Preloaded scenes
@onready var weapon_scene  := preload("res://scenes/ItemRelated/weaponTemplate.tscn")
@onready var healing_scene := preload("res://scenes/ItemRelated/healingItemTemplate.tscn")
@onready var pole_scene    := preload("res://scenes/ItemRelated/poleTemplate.tscn")

@export var rarity_config: RarityConfig
@onready var spawn_marker: Marker3D = $Marker3D

# ItemSpawner overall pool selection
@export var test_weapon_pool:  Array[FishWeaponData]
@export var test_healing_pool: Array[HealingItemData]
@export var test_pole_pool:    Array[FishingPoleData]

var _player_in_range := false


func _ready() -> void:
	add_to_group("item_spawners")
	$Area3D.body_entered.connect(_on_body_entered)
	$Area3D.body_exited.connect(_on_body_exited)


# DELETE AFTER manual test trigger via INTERACT
func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("INTERACT"):
		spawn_random_item(test_weapon_pool, test_healing_pool, test_pole_pool)


# INTERNAL
func _launch_arc(item: Node3D, spread_radius: float, angle: float, pickup_area: Area3D = null) -> void:
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
	# Re-enable pickup once the full landing animation has settled
	if pickup_area:
		tween.tween_callback(func():
			if is_instance_valid(pickup_area):
				pickup_area.monitoring = true
		)

	# Spin: 3 full rotations that ease out — fast on launch, stops on landing
	item.create_tween()\
		.tween_property(item, "rotation:y", item.rotation.y + TAU * 3.0, 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if dbg: print("[SPAWNER] Arc -> ", land_pos, " angle=", rad_to_deg(angle), "°")
	
	
# ADDED: shared instantiate helper; spawn_weapon/healing/pole were identical except scene + type
func _instantiate(scene: PackedScene, data: Resource, rarity: RarityTier,
				  spread: float, angle: float) -> Node3D:
	var item := scene.instantiate() as Node3D
	get_tree().current_scene.add_child(item)
	# Disable pickup area before the first physics step so the item doesn't get
	# instantly absorbed — it spawns at the player's position, so without this
	# body_entered fires in frame 1 before the arc animation can play.
	var pickup_area := item.get_node_or_null("PickupArea") as Area3D
	if pickup_area:
		pickup_area.monitoring = false
	item.setup(data, rarity)
	_launch_arc(item, spread, angle, pickup_area)
	return item
	
	
func _pick_weighted_rarity() -> RarityTier:
	if not rarity_config or rarity_config.tiers.is_empty(): return null
	var total_weight := 0.0
	for tier in rarity_config.tiers:
		total_weight += tier.weight
		
	if total_weight <= 0.0: return rarity_config.tiers[0]
	
	var roll    := randf() * total_weight
	var current := 0.0
	for tier in rarity_config.tiers:
		current += tier.weight
		if roll <= current: return tier
	return rarity_config.tiers.back()

# MAIN SPAWNERS
# CHANGED: _position param removed (was never used, marker position always used instead)
# CHANGED: angle moved here from _launch_arc - sentinel resolved at call site, not inside arc
func spawn_weapon(data: FishWeaponData, rarity: RarityTier,
				  spread: float = 2.0, angle: float = -1.0) -> Node3D:
	if not data or not rarity:
		push_error("[ItemSpawner] Missing data or rarity for weapon"); return null
	var a := angle if angle >= 0.0 else randf() * TAU
	if dbg: print("[SPAWNER] Weapon: ", data.resource_path, " (", rarity.name, ")")
	return _instantiate(weapon_scene, data, rarity, spread, a)
	
	
# CHANGED: same as spawn_weapon - _position removed, angle resolved here
func spawn_healing_item(data: HealingItemData, rarity: RarityTier,
						spread: float = 2.0, angle: float = -1.0) -> Node3D:
	if not data or not rarity:
		push_error("[ItemSpawner] Missing data or rarity for healing item"); return null
	var a := angle if angle >= 0.0 else randf() * TAU
	if dbg: print("[SPAWNER] Healing: ", data.resource_path, " (", rarity.name, ")")
	return _instantiate(healing_scene, data, rarity, spread, a)
	
	
# CHANGED: same as spawn_weapon — _position removed, angle resolved here
func spawn_pole(data: FishingPoleData, rarity: RarityTier,
				spread: float = 2.0, angle: float = -1.0) -> Node3D:
	if not data or not rarity:
		push_error("[ItemSpawner] Missing data or rarity for pole"); return null
	var a := angle if angle >= 0.0 else randf() * TAU
	if dbg: print("[SPAWNER] Pole: ", data.resource_path, " (", rarity.name, ")")
	return _instantiate(pole_scene, data, rarity, spread, a)
	
	
# CHANGED: now delegates to spawn_X instead of duplicating instantiation logic
func spawn_circle(items_to_spawn: Array, spread_radius: float = 2.0) -> void:
	var count := items_to_spawn.size()
	if count == 0: return
	var step := TAU / count #CHANGED: cached outside loop - was recomputing TAU/count every iteration
	for i in count:
		var entry = items_to_spawn[i]
		var angle := step * i
		match entry.get("type", ""):
			"weapon":  spawn_weapon(entry.data,  entry.rarity, spread_radius, angle)
			"healing": spawn_healing_item(entry.data, entry.rarity, spread_radius, angle)
			"pole":    spawn_pole(entry.data, entry.rarity, spread_radius, angle)
	
	
# CHANGED: _position param removed (unused)
# CHANGED: pool check moved before type pick - old code picked a type then found an empty pool and returned null
func spawn_random_item(weapon_pool:  Array[FishWeaponData],
					   healing_pool: Array[HealingItemData],
					   pole_pool:    Array[FishingPoleData]) -> Node3D:
	if not rarity_config or rarity_config.tiers.is_empty():
		push_error("[ItemSpawner] RarityConfig missing or empty"); return null
		
	var rarity := _pick_weighted_rarity()
	if not rarity:
		push_error("[ItemSpawner] Failed to pick rarity"); return null
		
	# ADDED: build list of only non-empty pools first, then pick - guarantees valid pick
	var available: Array[int] = []
	if not weapon_pool.is_empty():  available.append(0)
	if not healing_pool.is_empty(): available.append(1)
	if not pole_pool.is_empty():    available.append(2)
	if available.is_empty(): push_warning("[ItemSpawner] All pools empty"); return null
	
	match available[randi() % available.size()]:
		0: return spawn_weapon(weapon_pool[randi() % weapon_pool.size()], rarity)
		1: return spawn_healing_item(healing_pool[randi() % healing_pool.size()], rarity)
		2: return spawn_pole(pole_pool[randi() % pole_pool.size()], rarity)
	return null
	
	
# DELETE AFTER area detection only needed for test interaction
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if dbg: print("[ItemSpawner] Player entered range")

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if dbg: print("[ItemSpawner] Player left range")
