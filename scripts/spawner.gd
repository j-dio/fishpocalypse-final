extends Node3D

@export var player : CharacterBody3D
@export var enemy : PackedScene

var distance : float = 50.0

var minute : int:
	set(value):
		minute = value
		
var second : int:
	set(value):
		second = value
		if second >= 60:
			second -= 60
			minute += 1
		
func spawn(pos : Vector3):
	var enimi_instance = enemy.instantiate()

	enimi_instance.position = pos
	enimi_instance.player_reference = player
	get_tree().current_scene.add_child(enimi_instance)

func get_random_position() -> Vector3:
	var random_direction = Vector3.RIGHT.rotated(
		Vector3.UP,
		randf_range(0, 2 * PI)
	)

	return player.position + random_direction * distance
	
func amount(number : int = 1):
	for i in range(number):
		spawn(get_random_position())

func _on_timer_timeout() -> void:
	second += 1
	amount(second%2)
