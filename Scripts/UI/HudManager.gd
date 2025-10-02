extends CanvasLayer

# References
@export var health_label: Label
@export var score_label: Label
@export var money_label: Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# Initialize label text
	set_health_label_text(100)  # Temp
	set_score_label_text(0)     # Temp
	# TODO - initialize health and score from game manager
	set_money_label_text(MoneyManager.get_money())
	
	# Connect signals
	# TODO - connect health and score signals game manager
	MoneyManager.money_altered.connect(set_money_label_text)


# Update the health label text to new health value
func set_health_label_text(new_health: int) -> void:
	health_label.text = str(new_health)


# Update the score label text to new score value
func set_score_label_text(new_score: int) -> void:
	score_label.text = str(new_score)


# Update the money label text to new money count
func set_money_label_text(new_money: int) -> void:
	money_label.text = str(new_money)
