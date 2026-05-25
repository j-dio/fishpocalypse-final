class_name FishingSystem
extends Node

# Weights indexed by rarity order in RarityConfig.tiers (common=0 … ???=5)
const BASE_RARITY_WEIGHTS: Array[float] = [100.0, 60.0, 30.0, 10.0, 3.0, 1.0]

@export var items_db: ItemsDB
@export var rarity_config: RarityConfig
@export var minigame: FishingMinigame
@export var item_spawner: ItemSpawner

var _can_fish: bool = false
var _in_spot: bool = false
var _current_spot: FishingSpot = null
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
	call_deferred("_connect_fishing_spots")

func _on_day_started() -> void:
	_can_fish = true

func _on_day_ended() -> void:
	_can_fish = false
	if minigame.is_active():
		minigame.cancel()
		_unfreeze_player()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("INTERACT"):
		print("[FishingSystem] F pressed | can_fish:%s | in_spot:%s | minigame_null:%s" % [_can_fish, _in_spot, minigame == null])
	if not _can_fish or not _in_spot or minigame.is_active():
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
	if _current_spot != null and _player != null:
		_player.global_rotation.y = _current_spot.facing_marker.global_rotation.y
	minigame.start_wait(item, pole)
	_freeze_player()

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

func _on_spot_entered(spot: FishingSpot, player: Node3D) -> void:
	_in_spot = true
	_current_spot = spot
	_player = player

func _on_spot_exited() -> void:
	_in_spot = false
	_current_spot = null
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

func _connect_fishing_spots() -> void:
	for spot: FishingSpot in get_tree().get_nodes_in_group("fishing_spots"):
		spot.player_entered.connect(_on_spot_entered)
		spot.player_exited.connect(_on_spot_exited)

func _get_item_rarity(item: Resource) -> RarityTier:
	var r: RarityTier = item.get("rarity") as RarityTier
	if r != null:
		return r
	if rarity_config and not rarity_config.tiers.is_empty():
		return rarity_config.tiers[0]
	return null
