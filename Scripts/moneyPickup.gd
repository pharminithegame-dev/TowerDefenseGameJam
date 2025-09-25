extends Area3D

var value: int = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("money")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func pick_up() -> void:
	print("Total money:", MoneyManager.get_money())
	MoneyManager.add_money(value)
	# clears upon pickup
	queue_free()

# Godot-Generated signal
func _on_input_event(camera: Camera3D, event: InputEvent, pos: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Coin clicked! Value:", value)
		pick_up()
