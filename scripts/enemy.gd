extends CharacterBody3D

@export var player_reference: CharacterBody3D
@export var max_health: float = 30.0
@export var speed: float      = 1.0
@export var damage: float     = 5.0
@export var is_elite: bool    = false

const SEPARATION_RADIUS: float   = 1.8
const SEPARATION_STRENGTH: float = 2.8

var health: float
var gravity: float         = 9.8
var jump_force: float      = 5.0
var jump_cooldown: float   = 0.6
var jump_timer: float      = 0.0
var last_position: Vector3
var stuck_timer: float     = 0.0
var stuck_threshold: float = 0.3
var stuck_distance: float  = 0.05

# despawn if enemy hasn't moved >1.5 units within this window
const MAX_STUCK_DURATION: float = 8.0
var _unstuck_timer: float  = 0.0
var _check_pos: Vector3

func _ready() -> void:
	add_to_group("enemy")
	health        = max_health
	last_position = global_position
	_check_pos    = global_position
	if is_elite:
		_apply_elite_modifiers()

func reset() -> void:
	health         = max_health
	jump_timer     = 0.0
	stuck_timer    = 0.0
	_unstuck_timer = 0.0
	last_position  = global_position
	_check_pos     = global_position
	velocity       = Vector3.ZERO
	if is_elite:
		_apply_elite_modifiers()

func _apply_elite_modifiers() -> void:
	max_health *= 3.0
	health      = max_health
	damage     *= 2.0
	speed      *= 1.3
	scale      *= 1.4

func _physics_process(delta: float) -> void:
	if player_reference == null:
		return

	jump_timer -= delta

	# water escape: stronger jump than terrain-stuck jump to clear island edges
	if global_position.y < -0.5 and jump_timer <= 0.0:
		velocity.y = jump_force * 2.0
		jump_timer = jump_cooldown

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var direction := (player_reference.global_position - global_position).normalized()
	var sep := _compute_separation()
	velocity.x = direction.x * speed + sep.x
	velocity.z = direction.z * speed + sep.z
	move_and_slide()

	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider.is_in_group("player"):
			_deal_damage_to_player(collider)

	_apply_stuck_escape(delta)


func _compute_separation() -> Vector3:
	var sep := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group(&"active_enemy"):
		if other == self: continue
		var delta_pos := global_position - other.global_position
		var dist := delta_pos.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			sep += delta_pos.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	if sep.length_squared() > 0.0:
		sep = sep.normalized() * SEPARATION_STRENGTH
	return sep


# shared escape logic called by subclasses that override _physics_process
func _apply_stuck_escape(delta: float) -> void:
	var blocked_by_terrain := false
	for i in get_slide_collision_count():
		var col     := get_slide_collision(i)
		var collider := col.get_collider()
		if not collider is StaticBody3D:
			continue
		if abs(col.get_normal().y) < 0.5:
			blocked_by_terrain = true

	var moved := global_position.distance_to(last_position)
	if moved < stuck_distance and blocked_by_terrain:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_position

	# removed is_on_floor() guard — enemy inside geometry won't be on_floor
	# but still needs to jump free; jump_timer prevents re-trigger spam
	if stuck_timer >= stuck_threshold and jump_timer <= 0.0:
		velocity.y  = jump_force
		stuck_timer = 0.0
		jump_timer  = jump_cooldown

	# despawn if enemy has not moved significantly in MAX_STUCK_DURATION seconds
	# catches enemies fully embedded in geometry where no collision normals fire
	if global_position.distance_to(_check_pos) > 1.5:
		_check_pos     = global_position
		_unstuck_timer = 0.0
	else:
		_unstuck_timer += delta
		if _unstuck_timer >= MAX_STUCK_DURATION:
			die()


func _deal_damage_to_player(player) -> void:
	if player.has_method("_take_damage"):
		player._take_damage(damage)

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func apply_day_scaling(day: int) -> void:
	var hp_mult  := 1.0 + (day * 0.02)
	var dmg_mult := 1.0 + (day * 0.01)
	max_health    = max_health * hp_mult
	health        = max_health
	damage        = damage * dmg_mult

func die() -> void:
	var spawner := get_parent()
	if spawner.has_method(&"_release_to_pool"):
		spawner._release_to_pool(self)
	else:
		queue_free()
