extends Node3D
class_name Weapon

@export var data: FishWeaponData
var rarity: RarityTier

@onready var sprite: AnimatedSprite3D = $Sprite3D
@onready var audio: AudioStreamPlayer3D = $WeaponAudio
@onready var fire_timer: Timer = $Timer
@onready var muzzle: Marker3D = $Muzzle

# Data injector to make weapon
func setup(new_data: FishWeaponData, rolled_rarity: RarityTier):
	data = new_data
	rarity = rolled_rarity
	apply_data()

# Used when player picks up weapon only. player must call this if to shoot
func activate():
	if fire_timer:
		if not fire_timer.timeout.is_connected(shoot):
			fire_timer.timeout.connect(shoot)
		fire_timer.start()
	else:
		push_warning("Weapon: Cannot start fire_timer — node missing")

func apply_data():
	if sprite: sprite.sprite_frames = data.sprite_frames if data.sprite_frames else null
	else: push_warning("Weapon: AnimatedSprite3D node missing")
		
	if audio: audio.stream = data.sfx if data.sfx else null
	else: push_warning("Weapon: AudioStreamPlayer3D node missing")
		
	if fire_timer: fire_timer.wait_time = data.base_shot_delay * (rarity.shot_delay_multiplier if rarity else 1.0)
	else: push_warning("Weapon: Timer node missing")


func shoot():
	if data == null or rarity == null: return
	if data.projectile == null:
		push_warning("Weapon: No projectile data assigned")
		return

	for i in range(data.base_projectiles_per_shot):
		if not data.projectile.get("scene"):
			push_warning("Weapon: ProjectileData has no scene assigned")
			return
		var p = data.projectile.scene.instantiate()
		p.global_position = muzzle.global_position if muzzle else global_position
		p.damage = data.base_damage_per_shot * rarity.weapon_multiplier
		get_tree().current_scene.add_child(p)

	if audio: audio.play()
	fire_timer.start()

func _ready() -> void:
	_setup_pickup_area()

func _setup_pickup_area() -> void:
	var area := Area3D.new()
	area.name = "PickupArea"
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	col.shape = sphere
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var inv: InventorySystem = body.get_node_or_null("InventorySystem")
	if inv:
		inv.pickup(self)

func _on_picked_up() -> void:
	queue_free()
