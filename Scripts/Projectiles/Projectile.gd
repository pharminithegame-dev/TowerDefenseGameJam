extends Node3D

### Private Variables
var damage: float
var speed: float
var is_moving: bool = false



### Updates position
func _process(delta):
	if is_moving == false:   # Don't move until projectile is setup
		return
	
	# Move in forward direction
	var forward: Vector3 = global_transform.basis.z.normalized()
	global_position += forward * speed * delta


### Sets projectile stats and starts movement
func setup_and_move(_damage: float, _speed: float) -> void:
	damage = _damage
	speed = _speed
	is_moving = true


### Enemy Collision Check
func _on_area_3d_body_entered(body):

	if !body.is_in_group("enemies"):   # Only collide with enemies
		return
	
	# Apply damage to enemy
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	queue_free()   # Despawn projectile


### Despawn when off-screen
func _on_visible_on_screen_notifier_3d_screen_exited():
	queue_free()   # Despawn projectile
