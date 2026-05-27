extends Area3D

var direction: Vector3 = Vector3.ZERO
var damage: int = 6
var speed: float = 2.0
var turn_speed: float = 2.0
var target_scale: float = 1.0
var grow_duration: float = 0.4

const GRACE_END: float = 0.3
const LIFETIME: float = 8.0
const _SCALE_EPSILON: float = 0.001
const _INV_GROW_DUR: float = 0.25

var _timer: float = 0.0
var _grew: bool = false
var _target: CharacterBody3D = null

# Reference to the pool that owns this projectile
var _pool: Node = null
func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_target = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	scale = Vector3.ONE * _SCALE_EPSILON
	
	
func init(dir: Vector3, dmg: int, pool: Node = null) -> void:
	# Reset everything for reuse
	direction = dir
	damage = dmg
	_timer = 0.0
	_grew = false
	_pool = pool
	
	scale = Vector3.ONE * _SCALE_EPSILON
	visible = true
	set_process(true)
	
	
func _process(delta: float) -> void:
	_timer += delta
	
	if _timer >= LIFETIME:
		_retire()
		return
		
	# Growth
	if not _grew:
		if _timer < grow_duration:
			scale = Vector3.ONE * (_timer * _INV_GROW_DUR * target_scale)
		else:
			scale = Vector3.ONE * target_scale
			_grew = true
			
	# Homing
	if _timer > GRACE_END and _target != null:
		var desired = (_target.global_position - global_position).normalized()
		direction = direction.lerp(desired, turn_speed * delta).normalized()
	global_position += direction * speed * delta
	
	
func _on_body_entered(body: Node3D) -> void:
	if _timer <= GRACE_END:
		return
	if body.is_in_group(&"player"):
		body._take_damage(damage)
	_retire()
	
	
func _retire() -> void:
	if _pool != null: _pool.release(self)
	else: queue_free()
