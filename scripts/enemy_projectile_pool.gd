# projectile_pool.gd
# autoload singleton; add via Project > Project Settings > Autoload
# name it "ProjectilePool"
extends Node

@export var max_projectiles: int = 20  # adjust in inspector or set directly
var _pool: Array[Node]  = []
var _free_list: Array[int] = []
var current_count: int = 0
var _scene: PackedScene  # set once by the first ranged enemy that calls init_pool()

func init_pool(scene: PackedScene) -> void:
	if not _pool.is_empty(): return  # already built; only run once
	_scene = scene
	_pool.resize(max_projectiles)
	for i in max_projectiles:
		var inst: Node = _scene.instantiate()
		inst.set_process(false)
		inst.visible   = false
		inst.add_to_group(&"enemy_projectile")
		get_tree().current_scene.add_child.call_deferred(inst)
		inst.set_meta(&"pool_idx", i)
		_pool[i]       = inst
		_free_list.append(i)
	print("[proj_pool] built; size; ", max_projectiles)
	
	
func can_shoot() -> bool:
	return current_count < max_projectiles and not _free_list.is_empty()
	
	
func acquire() -> Node:
	if _free_list.is_empty(): return null
	
	var idx: int = _free_list.pop_back()
	current_count += 1
	var proj = _pool[idx]
	proj.init(Vector3.ZERO, 6, self)
	return proj
	
	
func release(proj: Node) -> void:
	if proj == null: return
	if not proj.has_meta(&"pool_idx"):
		if not proj.is_queued_for_deletion(): proj.queue_free()
		push_warning("[ProjectilePool] Tried to release a non-pooled projectile")
		return
		
	proj.visible = false
	proj.set_process(false)
	proj.global_position = Vector3(0.0, -9999.0, 0.0)
	
	var idx: int = proj.get_meta(&"pool_idx")
	_free_list.push_back(idx)
	current_count -= 1
