class_name ProjectileData
extends Resource

enum OwnerType { PLAYER, ENEMY }
enum ProjectileType { BULLET, LASER }

@export var owner_type: OwnerType = OwnerType.PLAYER
@export var type: ProjectileType = ProjectileType.BULLET

@export var speed: float = 20.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

@export var sprite: Texture2D

# laser-specific (optional but important)
@export var beam_length: float = 50.0
@export var tick_rate: float = 0.1
