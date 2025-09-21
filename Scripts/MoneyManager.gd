extends Node

# Signal for when any form of money change is done
signal money_altered(new_money: int)

var money: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	money_altered.emit(money)

func add_money(num: int) -> void:
	money += num
	money_altered.emit(money)

func subtract_money(num: int) -> void:
	money -= num
	money_altered.emit(money)

func set_money(num: int) -> void:
	money = num
	money_altered.emit(money)

func get_money() -> int:
	return money

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
