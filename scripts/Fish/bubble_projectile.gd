extends Area3D
var direction: Vector3 = Vector3.ZERO
var damage: float = 6.0
var speed: float = 2.0
var lifetime: float = 8.0
var timer: float = 0.0
var grace_timer: float = 0.3
var target: Node3D = null
var turn_speed: float = 2.0

var target_scale: float = 1
var grow_duration: float = 0.4  # seconds to reach full size

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	target = get_tree().get_first_node_in_group("player")
	scale = Vector3.ZERO  # start invisible/tiny

func init(dir: Vector3, dmg: float) -> void:
	direction = dir
	damage = dmg

func _process(delta):
	timer += delta
	if grace_timer > 0.0:
		grace_timer -= delta
	if timer >= lifetime:
		queue_free()
		return

	# Grow from zero to target_scale over grow_duration
	if timer < grow_duration:
		var t = timer / grow_duration
		var current_scale = lerp(0.0, target_scale, t)
		scale = Vector3.ONE * current_scale
	else:
		scale = Vector3.ONE * target_scale

	if target != null and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired, turn_speed * delta).normalized()
	global_position += direction * speed * delta

func _on_body_entered(body) -> void:
	if grace_timer > 0.0:
		return
	if body.is_in_group("player"):
		if body.has_method("_take_damage"):
			body._take_damage(damage)
	queue_free()

func hit() -> void:
	queue_free()
