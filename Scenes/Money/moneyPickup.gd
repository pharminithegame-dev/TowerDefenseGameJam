extends Area3D

var value: int = 10

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("money")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func pick_up() -> void:
	MoneyManager.add_money(value)
