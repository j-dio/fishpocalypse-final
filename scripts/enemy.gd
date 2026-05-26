extends CharacterBody3D
@export var player_reference: CharacterBody3D
@export var max_health: float = 30.0
@export var speed: float = 1.0
@export var damage: float = 5.0
@export var is_elite: bool = false
var health: float

var gravity: float = 9.8
var jump_force: float = 5.0
var jump_cooldown: float = 0.6
var jump_timer: float = 0.0

var last_position: Vector3
var stuck_timer: float = 0.0
var stuck_threshold: float = 0.3
var stuck_distance: float = 0.05

func _ready() -> void:
	health = max_health
	if is_elite:
		_apply_elite_modifiers()
	last_position = global_position
	
func _apply_elite_modifiers() -> void:
	max_health *= 3.0
	health = max_health
	damage *= 2.0
	speed *= 1.3
	scale *= 1.4
	
func _physics_process(delta):
	if player_reference == null:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	jump_timer -= delta
	
	var direction = (player_reference.global_position - global_position).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	
	# Check terrain collisions only (ignore other enemies)
	var blocked_by_terrain = false
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			_deal_damage_to_player(collider)
		if not collider.is_in_group("player") and not collider is StaticBody3D:
			continue
		var normal = collision.get_normal()
		if abs(normal.y) < 0.5:
			blocked_by_terrain = true
	# Stuck detection — only count if terrain is the blocker
	
	var moved = global_position.distance_to(last_position)
	if moved < stuck_distance and blocked_by_terrain:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_position
	if stuck_timer >= stuck_threshold and is_on_floor() and jump_timer <= 0.0:
		velocity.y = jump_force
		stuck_timer = 0.0
		jump_timer = jump_cooldown
		
func _deal_damage_to_player(player) -> void:
	if player.has_method("_take_damage"):
		player._take_damage(damage)
		
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()
		
func die() -> void:
	queue_free()
