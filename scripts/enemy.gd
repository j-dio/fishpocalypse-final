extends CharacterBody3D

@export var player_reference : CharacterBody3D

var speed : float = 10

func _physics_process(delta):

	if player_reference == null:
		return

	var direction = (player_reference.global_position - global_position).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
