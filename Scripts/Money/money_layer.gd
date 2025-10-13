extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MoneyLabel.text = "Money: %d" % MoneyManager.get_money()
	MoneyManager.money_altered.connect(_on_money_altered)

func _on_money_altered(new_money: int) -> void:
	$MoneyLabel.text = "Money: %d" % new_money
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
