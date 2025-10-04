extends Node3D

### References
@export var rot_node: Node3D
@export var area_3d: Area3D
@export var collision_shape: CollisionShape3D
@export var raycast: RayCast3D
@export var laser_visuals: MeshInstance3D
@export var audio_player: AudioStreamPlayer
@export var shoot_timer: Timer
@export var laser_visuals_timer: Timer

### Stats
@export var attack_damage := 20.0
@export var attack_range := 80.0
@export var attack_cooldown := 2.0
@export var sell_value := 150.0

### Visuals
@export var laser_visuals_duraion := 0.3

### Private Variables
var is_active := true   # Enabled when building can target/shoot



### Initialize Node
func _ready() -> void:
	
	# Initialize references
	if collision_shape.shape != null:
		collision_shape.shape.radius = attack_range
	else:
		push_warning("HitscanBuilding.Area3D.CollisionShape3D.Shape is null!")
		
	shoot_timer.wait_time = attack_cooldown
	laser_visuals_timer.wait_time = laser_visuals_duraion


### Enables the raycast in the direction of the leading enemy and applies damage to enemy if hit
func _on_shoot_timer_timeout():
	
	# Get nearest enemy in range
	var target: Node3D = get_leading_enemy()
	if target == null:
		return
	
	# Rotate rot_node towards target
	rotate_to_target(target.global_position)
	
	# Set height of raycast target (in case of a height difference between building and enemy)
	raycast.target_position.y = target.global_position.y - raycast.global_position.y
	
	# Set length of raycast target (ignore height)
	var target_pos_2d:= Vector3(target.global_position.x, 0, target.global_position.z)
	var ray_pos_2d:= Vector3(raycast.global_position.x, 0, raycast.global_position.z)
	raycast.target_position.z = ray_pos_2d.distance_to(target_pos_2d)
	
	raycast.enabled = true
	raycast.force_raycast_update()
	show_laser_visuals()  # Temporarily show a cylinder mesh following the raycast
	
	# Make sure raycast collides with an enemy
	if !raycast.is_colliding():
		raycast.enabled = false
		return
	
	# Make sure colliding object is an enemy
	var collider = raycast.get_collider()
	if !collider.is_in_group("enemies"):
		return
	
	# Apply damage to enemy
	if collider.has_method("take_damage"):
		audio_player.play()   # Play hitscan shoot sfx
		collider.take_damage(attack_damage)
		
	raycast.enabled = false


### Uses raycast as a guide to update and show laser visual cylinder
func show_laser_visuals() -> void:
	
	# Set height of visual cylinder to length of ray
	laser_visuals.mesh.height = raycast.target_position.length()
	# Set position of visual cylinder between position and target (include offset of ray from building origin)
	laser_visuals.position = raycast.position + (raycast.target_position / 2)
	
	var direction: Vector3 = raycast.target_position.normalized()
	laser_visuals.rotation.x = atan2(direction.z, direction.y)    # Rotate on x axis in direction
	
	laser_visuals.visible = true
	laser_visuals_timer.start()


### Hides laser visuals when laser visuals timer expires
func _on_laser_visuals_timer_timeout():
	laser_visuals.visible = false


### Returns the enemy who is furthest along in enemy path.
func get_leading_enemy() -> Node3D:
	# Get all enemies in attack range
	var all_enemies: Array[Node3D] = area_3d.get_overlapping_bodies()
	
	if all_enemies.size() == 0:   # Return null if no enemies in range
		return null
	
	# Get furthest enemy on path from all enemies in attack range
	var furthest_enemy_on_path: Node3D = null
	var furthest_enemy_path_percent := 0.0
	for enemy in all_enemies:
		
		if !enemy.has_method("get_path_completion_percentage"): # Make sure we can access path percent
			continue
		
		# Check if current enemy is new furthest enemy on path
		var cur_enemy_path_percent: float = enemy.get_path_completion_percentage()
		if cur_enemy_path_percent > furthest_enemy_path_percent:
			furthest_enemy_path_percent = cur_enemy_path_percent
			furthest_enemy_on_path = enemy
	
	return furthest_enemy_on_path


### Rotates the ProjectileSpawnRotation node toward target
func rotate_to_target(target_pos: Vector3) -> void:
	var direction: Vector3 = target_pos - global_position   # Direction to target
	rot_node.rotation.y = atan2(direction.x, direction.z)   # Rotate on y axis in direction


### Despawns building and returns the sell value
func sell_building() -> float:
	queue_free()   # Despawn building
	return sell_value


### Allows building to start targeting and shooting
func activate_building() -> void:
	shoot_timer.start()
	is_active = true


### Stops building from targeting and shooting
func deactivate_building() -> void:
	shoot_timer.stop()
	is_active = false
