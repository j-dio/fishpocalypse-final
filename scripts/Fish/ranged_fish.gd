extends "res://scripts/enemy.gd"
@export var projectile_scene: PackedScene
var attack_range: float = 18.0
var preferred_distance: float = 12.0
var attack_cooldown: float = 2.5
var attack_timer: float = 0.0

var shoot_frame_timer: float = 0.0
var shoot_frame_duration: float = 0.4  # How long frame 1 stays visible

func _ready() -> void:
	max_health = 20.0
	speed = 0.8
	damage = 6.0
	super._ready()
	$AnimatedSprite3D.animation = "default"
	$AnimatedSprite3D.frame = 0
	$AnimatedSprite3D.pause()  # We'll control frames manually

func _physics_process(delta):
	if player_reference == null:
		return
	attack_timer += delta

	# Count down shoot frame timer
	if shoot_frame_timer > 0.0:
		shoot_frame_timer -= delta
		if shoot_frame_timer <= 0.0:
			$AnimatedSprite3D.frame = 0  # Return to idle frame

	var dist = global_position.distance_to(player_reference.global_position)
	var direction = (player_reference.global_position - global_position).normalized()

	if dist > preferred_distance + 2.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	elif dist < preferred_distance - 2.0:
		velocity.x = -direction.x * speed
		velocity.z = -direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			_deal_damage_to_player(collider)

	if dist <= attack_range and attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_shoot(direction)

func _shoot(dir: Vector3) -> void:
	if projectile_scene == null:
		push_warning("Ranged fish has no projectile_scene assigned")
		return
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3.UP * 0.5 + dir * 1.5
	proj.init(dir, damage)

	# Flash to shoot frame
	$AnimatedSprite3D.frame = 1
	shoot_frame_timer = shoot_frame_duration
