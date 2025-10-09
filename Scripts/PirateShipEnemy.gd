extends "res://Scripts/Enemy.gd"

### Pirate Ship Specific
@export var ufo_enemy_scene: PackedScene
@export var ufo_spawn_count := 2

### Initialize Pirate Ship
func _ready() -> void:
	super._ready()
	# Pirate ship is slower than UFO
	move_speed = move_speed * 0.5

### Override death to spawn UFOs
func die() -> void:
	if !is_alive:
		return
	
	spawn_ufos()
	super.die()

### Spawns UFO enemies when pirate ship dies
func spawn_ufos() -> void:
	if !ufo_enemy_scene:
		return
	
	for i in ufo_spawn_count:
		var ufo = ufo_enemy_scene.instantiate()
		get_tree().root.add_child(ufo)
		
		# Position UFOs around the death location
		var offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		ufo.global_position = global_position + offset
		
		# Set path and progress to match pirate ship
		if ufo.has_method("set_path") and !path_points.is_empty():
			ufo.set_path(path_points)
			ufo.current_path_index = current_path_index
			ufo.path_completion_percentage = path_completion_percentage
		
		# Connect signals
		if ufo.has_signal("enemy_died"):
			var enemy_manager = get_node("/root/EnemyManager")
			if enemy_manager:
				ufo.enemy_died.connect(enemy_manager._on_enemy_died)
		if ufo.has_signal("enemy_reached_end"):
			var enemy_manager = get_node("/root/EnemyManager")
			if enemy_manager:
				ufo.enemy_reached_end.connect(enemy_manager._on_enemy_reached_end)
