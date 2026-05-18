extends Node3D
class_name PoleTemplate

signal fish_bite
signal fish_caught

@export var data: FishingPoleData
var rarity: RarityTier

@onready var sprite: Sprite3D = $Sprite3D
@onready var hook: Marker3D = $Hook
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var timer: Timer = $Timer

## idk how to connect to the fishing system
