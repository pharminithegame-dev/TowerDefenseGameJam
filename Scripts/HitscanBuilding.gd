extends Node3D

### References
@export var rot_target: Node3D
@export var area_3d: Area3D
@export var collision_shape: CollisionShape3D
@export var projectile_tran: Node3D
@export var raycast: RayCast3D
@export var audio_player: AudioStreamPlayer

### Stats
@export var projectile_damage := 20.0
@export var attack_range := 80.0
@export var attack_cooldown := 2.0
@export var sell_value := 150.0

### Private Variables
var attack_timer := 0.0
var attack_range_sqr : float



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
	
	attack_timer -= delta
	if attack_timer <= 0:
		# Start attack
		attack_timer = attack_cooldown
		shoot_raycast()


### Enables the raycast in the direction of the leading enemy 
### 	and applies damage to enemy if hit
func shoot_raycast() -> void:
	
	# Get nearest enemy in range
	var target: Node3D = get_leading_enemy()
	if target == null:
		print("No Targets in Range For Building: ", name)
		return
	
	# Rotate ProjectileSpawnRotation towards target
	rotate_to_target(target.global_position)
	
	
	### Raycast Towards Target
	raycast.enabled = true
	raycast.force_raycast_update()
	
	# Make sure raycast collides with an enemy
	if !raycast.is_colliding():
		print("Got a target in range, but raycast is not colliding with anything")
		raycast.enabled = false
		return
	
	# Make sure colliding object is an enemy
	var collider = raycast.get_collider()
	if !collider.is_in_group("enemies"):
		print("Got a raycast target, but target's collider is not in 'enemies' group")
		return
	
	# TODO - apply damage
	print("Applying hitscan damage to enemy")
	audio_player
	raycast.enabled = false
	
	audio_player.play()   # Play hitscan shoot sfx


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
		if cur_dist_sqr < closest_dist_sqr and cur_dist_sqr < attack_range_sqr:   # NOTE - range check is redundant now, but I will need it when I remove Area3D later
			closest_enemy = enemy
			closest_dist_sqr = cur_dist_sqr
	
	return closest_enemy


### Rotates the ProjectileSpawnRotation node toward target
func rotate_to_target(target_pos: Vector3) -> void:
	
	# Get 2D direction from building to target
	var building_pos_2d := Vector2(global_position.x, global_position.z)
	var target_pos_2d := Vector2(target_pos.x, target_pos.z)
	var direction: Vector2 = target_pos_2d - building_pos_2d
	
	# Rotate on y axis in direction
	rot_target.rotation.y = atan2(direction.x, direction.y)


### Despawns building and returns the sell value
func sell_building() -> float:
	queue_free()   # Despawn building
	return sell_value
