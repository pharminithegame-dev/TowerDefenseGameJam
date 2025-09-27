extends Node3D

### References
@export var rot_node: Node3D
@export var area_3d: Area3D
@export var collision_shape: CollisionShape3D
@export var raycast: RayCast3D
@export var audio_player: AudioStreamPlayer

### Stats
@export var attack_damage := 20.0
@export var attack_range := 80.0
@export var attack_cooldown := 2.0
@export var sell_value := 150.0

### Private Variables
var attack_timer := 0.0
var attack_range_sqr : float
var is_active := true   # Enabled when building can target/shoot


### Initialize Node
func _ready() -> void:
	
	# Initialize collision radius
	if collision_shape.shape != null:
		collision_shape.shape.radius = attack_range
	else:
		push_warning("HitscanBuilding.Area3D.CollisionShape3D.Shape is null!")

	# Initialize raycast range
	raycast.target_position = Vector3(0, 0, attack_range)

	# Initialize Variables
	attack_timer = attack_cooldown
	attack_range_sqr = pow(attack_range, 2)


### Starts attack on interval
func _process(delta: float) -> void:
	
	if is_active:   # Only target/shoot when active
		attack_timer -= delta
		
		if attack_timer <= 0:   # Check to attack
			attack_timer = attack_cooldown
			shoot()


### Enables the raycast in the direction of the leading enemy 
### 	and applies damage to enemy if hit
func shoot() -> void:
	
	# Get nearest enemy in range
	var target: Node3D = get_leading_enemy()
	if target == null:
		print("No Targets in Range For Building: ", name)
		return
	else:
		print("Found target with name: ", name)
	
	# Rotate ProjectileSpawnRotation towards target
	rotate_to_target(target.global_position)
	
	
	### Raycast Towards Target
	# Adjust raycast target height in case of a height difference between building and enemy
	raycast.target_position.y = target.global_position.y - raycast.global_position.y
	
	#raycast.enabled = true
	raycast.force_raycast_update()
	
	#print("----------")
	#print("Enemy position: ", target.global_position)
	#print("Raycast position: ", raycast.global_position)
	#print("Raycast target position: ", raycast.target_position)
	#print("Raycast forward vector: ", -raycast.global_transform.basis.z)
	#print("Rotation Node forward vector: ", -rot_node.global_transform.basis.z)
	#print("----------")
	
	# Make sure raycast collides with an enemy
	if !raycast.is_colliding():
		print("Got a target in range, but raycast is not colliding with anything")
		#raycast.enabled = false
		return
	
	# Make sure colliding object is an enemy
	var collider = raycast.get_collider()
	if !collider.is_in_group("enemies"):
		print("Got a raycast target, but target's collider is not in 'enemies' group")
		return
	
	# Apply damage to enemy
	if collider.has_method("take_damage"):
		audio_player.play()   # Play hitscan shoot sfx
		collider.take_damage(attack_damage)
		print("Applied ", attack_damage, " damage to enemy")
		
	#raycast.enabled = false


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
	
	target_pos.y = rot_node.global_position.y  # Ignore target y pos
	rot_node.look_at(target_pos, Vector3.UP)


### Despawns building and returns the sell value
func sell_building() -> float:
	queue_free()   # Despawn building
	return sell_value


### Allows building to start targeting and shooting
func activate_building() -> void:
	attack_timer = attack_cooldown   # Reset attack timer
	is_active = true


### Stops building from targeting and shooting
func deactivate_building() -> void:
	is_active = false
