class_name FishWeaponData
extends Resource

@export var weight: float = 1.0
@export var spawn_day: int = 1
@export var base_damage_per_shot: float = 10.0
@export var base_shot_delay: float = 0.5
@export var base_projectiles_per_shot: int = 1
@export var base_recharge_cost: float = 10.0
@export var rarity: RarityTier
@export var projectile: ProjectileData
@export var sprite_frames: SpriteFrames
@export var sfx: AudioStream
## Local offset from weapon root to the grip (hand). ZERO uses auto alignment for 40×16 posils frames.
@export var hold_offset: Vector3 = Vector3.ZERO
## Local offset from weapon root to the muzzle. ZERO uses auto alignment from frame width.
@export var muzzle_offset: Vector3 = Vector3.ZERO
