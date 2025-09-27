extends Node3D

### References
@export var rot_node: Node3D
@export var area_3d: Area3D
@export var collision_shape: CollisionShape3D
@export var projectile_tran: Node3D
@export var projectile: PackedScene
@export var audio_player: AudioStreamPlayer

### Stats
@export var projectile_damage := 5.0
@export var projectile_speed := 20.0
@export var attack_range := 30.0
@export var attack_cooldown := 1.0
@export var sell_value := 100.0

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
		push_warning("ProjectileBuilding.Area3D.CollisionShape3D.Shape is null!")

	# Initialize Variables
	attack_timer = attack_cooldown
	attack_range_sqr = pow(attack_range, 2)


### Starts attack on interval
func _process(delta: float) -> void:
	
	if is_active: # Only target/shoot when active
		attack_timer -= delta
		if attack_timer <= 0:
			# Start attack
			attack_timer = attack_cooldown
			shoot()


### Spawns a projectile in the direction of the closest enemy
func shoot() -> void:
	
	# Get nearest enemy in range
	var target: Node3D = get_nearest_enemy()
	if target == null:
		return
	
	# Rotate ProjectileSpawnRotation towards target
	rotate_to_target(target.global_position)
	
	# Spawn projetile and setup transform and stats
	var projectile_instance = projectile.instantiate()
	get_tree().root.add_child(projectile_instance)
	projectile_instance.global_position = projectile_tran.global_position
	projectile_instance.global_rotation = projectile_tran.global_rotation
	projectile_instance.setup_and_move(projectile_damage, projectile_speed)
	
	audio_player.play()   # Play projectile shoot sfx


### Returns the closest enemy in attack range.
func get_nearest_enemy() -> Node3D:
	
	# Get all enemies in range
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
	var direction: Vector3 = target_pos - global_position    # Direction to target
	rot_node.rotation.y = atan2(direction.x, direction.z)  # Rotate on y axis in direction


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
