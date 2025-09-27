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
var attack_range_sqr : float
var is_active := true   # Enabled when building can target/shoot



### Initialize Node
func _ready() -> void:
	
	# Initialize references
	if collision_shape.shape != null:
		collision_shape.shape.radius = attack_range
	else:
		push_warning("HitscanBuilding.Area3D.CollisionShape3D.Shape is null!")
		
	raycast.target_position = Vector3(0, 0, attack_range)
	shoot_timer.wait_time = attack_cooldown
	laser_visuals_timer.wait_time = laser_visuals_duraion

	# Initialize Variables
	attack_range_sqr = pow(attack_range, 2)


### Enables the raycast in the direction of the leading enemy 
### 	and applies damage to enemy if hit
func _on_shoot_timer_timeout():
	
	# Get nearest enemy in range
	var target: Node3D = get_leading_enemy()
	if target == null:
		return
	
	# Rotate ProjectileSpawnRotation towards target
	rotate_to_target(target.global_position)
	
	### Raycast Towards Target
	# Adjust raycast target height in case of a height difference between building and enemy
	raycast.target_position.y = target.global_position.y - raycast.global_position.y
	
	raycast.enabled = true
	raycast.force_raycast_update()
	show_laser_visuals()  # Temporarily show a cylinder mesh following the raycast
	
	#print("----------")
	#print("Enemy position: ", target.global_position)
	#print("Raycast position: ", raycast.global_position)
	#print("Raycast target position: ", raycast.target_position)
	#print("Raycast forward vector: ", -raycast.global_transform.basis.z)
	#print("Rotation Node forward vector: ", -rot_node.global_transform.basis.z)
	#print("----------")
	
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
	
	var ray_length := 1.0
	if raycast.is_colliding():
		ray_length = (raycast.get_collision_point() - raycast.global_position).length() + 1
	else:
		ray_length = raycast.target_position.length()
		
	# Set height of visual cylinder to length of ray
	laser_visuals.mesh.height = ray_length
	# Set position of visual cylinder between position and target
	laser_visuals.position = raycast.position + (raycast.target_position.normalized() * ray_length/2)
	laser_visuals.visible = true
	laser_visuals_timer.start()


### Hides laser visuals when laser visuals timer expires
func _on_laser_visuals_timer_timeout():
	laser_visuals.visible = false


### Returns the enemy who is furthest along in enemy path.
func get_leading_enemy() -> Node3D:
	
	# TODO - need enemies to be implemented so I can determine which one is furthest in path
	# NOTE - for now I am just using closest enemy to building
	
	var all_enemies: Array[Node3D] = area_3d.get_overlapping_bodies()
	
	# Return null if no enemies in range
	if all_enemies.size() == 0:
		return null
	
	# Get closest enemy in all enemies array
	var closest_enemy: Node3D = null
	var closest_dist_sqr: float = INF
	for enemy in all_enemies:
		# If this is the new closest enemy and is in attack range
		var cur_dist_sqr := global_position.distance_squared_to(enemy.global_position)
		if cur_dist_sqr < closest_dist_sqr:
			closest_enemy = enemy
			closest_dist_sqr = cur_dist_sqr
	
	return closest_enemy


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
