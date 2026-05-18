class_name FishingSpot
extends Node3D

signal player_entered(spot: FishingSpot, player: Node3D)
signal player_exited()

@onready var facing_marker: Marker3D = $FacingMarker
@onready var _area: Area3D = $FishingSpotArea

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	add_to_group("fishing_spots")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered.emit(self, body)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_exited.emit()
