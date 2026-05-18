extends Node3D
class_name Weapon

@export var data: FishWeaponData
var rarity: RarityTier

@onready var sprite: Sprite3D = $Sprite3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var fire_timer: Timer = $Timer
@onready var muzzle: Marker3D = $Muzzle


func setup(new_data: FishWeaponData, rolled_rarity: RarityTier):
	data = new_data
	rarity = rolled_rarity
	apply_data()

	fire_timer.timeout.connect(shoot)
	fire_timer.start()


func apply_data():
	sprite.sprite_frames = data.sprite_frames
	audio.stream = data.sfx
	fire_timer.wait_time = data.base_shot_delay * rarity.shot_delay_multiplier

func shoot():
	if data == null:
		return

	for i in range(data.base_projectiles_per_shot):
		var p = data.projectile.scene.instantiate()

		p.global_position = muzzle.global_position
		p.damage = data.base_damage_per_shot * rarity.weapon_multiplier

		get_tree().current_scene.add_child(p)

	audio.play()
	fire_timer.start()
