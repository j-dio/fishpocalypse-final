extends Node3D
class_name HealingItemTemplate

@export var data: HealingItemData
var rarity: RarityTier

var stack_count: int = 1

@onready var sprite: Sprite3D = $Sprite3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var timer: Timer = $Timer

func setup(new_data: HealingItemData, rolled_rarity: RarityTier, initial_stack: int = 1):
	data = new_data
	rarity = rolled_rarity
	stack_count = clamp(initial_stack, 1, data.stack_limit)
	apply_data()
	
func apply_data():
	if data == null: return
	sprite.texture = data.sprite
	
	timer.wait_time = data.use_delay * rarity.heal_multiplier
	timer.one_shot = true
	
func use(target):
	if data == null: return
	if not timer.is_stopped(): return
	timer.start()
	var heal_amount := data.base_heal_amount * rarity.heal_multiplier
	if target.has_method("heal"): target.heal(heal_amount)
	audio.play()
	consume_stack()
	
func consume_stack():
	stack_count -= 1
	if stack_count <= 0: queue_free()
	
func get_final_heal() -> float:
	return data.base_heal_amount * rarity.heal_multiplier
