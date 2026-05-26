# enemySpawner.gd
extends Node3D

@export var player: CharacterBody3D
@export var tanky_fish: PackedScene
@export var normal_fish: PackedScene
@export var ranged_fish: PackedScene

var spawn_distance: float = 50.0
var base_spawn_amount: int = 1
var enemies_spawned_this_night: int = 0
var is_night: bool = false
var day_count: int = 0
var next_elite_day: int = 0

const SPAWN_TABLE = [
	{"scene": "tanky",  "weight": 35},
	{"scene": "normal", "weight": 50},
	{"scene": "ranged", "weight": 15},
]

func _ready() -> void:
	var day_night_system = get_tree().get_first_node_in_group("day_night")
	if day_night_system == null:
		push_warning("No Day/Night system found in group 'day_night'")
		return
	day_night_system.day_night_changed.connect(_on_night_changed)
	_pick_next_elite_day()

func _pick_next_elite_day() -> void:
	next_elite_day = day_count + randi_range(2, 3)

func _on_night_changed(active: bool) -> void:
	is_night = active
	if not active:
		day_count += 1
		enemies_spawned_this_night = 0

func _on_timer_timeout() -> void:
	if not is_night:
		return
	var spawn_count = calculate_spawn_amount()
	for i in range(spawn_count):
		spawn(get_random_position(), false)
	enemies_spawned_this_night += spawn_count
	if day_count >= next_elite_day:
		spawn(get_random_position(), true)
		_pick_next_elite_day()

func calculate_spawn_amount() -> int:
	return randi_range(base_spawn_amount, base_spawn_amount + 3)

func _pick_random_scene() -> PackedScene:
	var total_weight = 0
	for entry in SPAWN_TABLE:
		total_weight += entry["weight"]
	var roll = randi_range(1, total_weight)
	var cumulative = 0
	for entry in SPAWN_TABLE:
		cumulative += entry["weight"]
		if roll <= cumulative:
			match entry["scene"]:
				"tanky":  return tanky_fish
				"normal": return normal_fish
				"ranged": return ranged_fish if ranged_fish != null else normal_fish
	return normal_fish

func spawn(pos: Vector3, elite: bool = false) -> void:
	var scene = _pick_random_scene()
	if scene == null:
		push_warning("Missing enemy PackedScene — check spawner exports")
		return
	var instance = scene.instantiate()
	instance.position = pos
	if "player_reference" in instance:
		instance.player_reference = player
	if "is_elite" in instance:
		instance.is_elite = elite
	get_tree().current_scene.add_child(instance)

func get_random_position() -> Vector3:
	var dir = Vector3.RIGHT.rotated(Vector3.UP, randf_range(0.0, TAU))
	return player.position + dir * spawn_distance
