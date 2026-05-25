extends Node3D

@export var player: CharacterBody3D
@export var enemy: PackedScene

var spawn_distance: float = 50.0
var base_spawn_amount: int = 1
var enemies_spawned_this_night: int = 0
var is_night: bool = false

func _ready() -> void:
	# assume the day/night system is in a group
	var day_night_system = get_tree().get_first_node_in_group("day_night")
	if day_night_system == null:
		push_warning("No Day/Night system found in group 'day_night'")
		return
	day_night_system.day_night_changed.connect(_on_night_changed)
	
	
func _on_night_changed(active: bool) -> void:
	is_night = active
	
func _on_timer_timeout() -> void:
	if is_night:
		var spawn_count: int = calculate_spawn_amount()
		amount(spawn_count)
		enemies_spawned_this_night += spawn_count
	else:
		enemies_spawned_this_night = 0
		
func calculate_spawn_amount() -> int:
	return randi_range(base_spawn_amount, base_spawn_amount + 3)
	
func spawn(pos: Vector3) -> void:
	var enemy_instance = enemy.instantiate()
	enemy_instance.position = pos
	if "player_reference" in enemy_instance:
		enemy_instance.player_reference = player
	get_tree().current_scene.add_child(enemy_instance)
	
	
func get_random_position() -> Vector3:
	var dir = Vector3.RIGHT.rotated(Vector3.UP, randf_range(0.0, TAU))
	return player.position + dir * spawn_distance
	
	
func amount(number: int = 1) -> void:
	for i in range(number):
		spawn(get_random_position())
