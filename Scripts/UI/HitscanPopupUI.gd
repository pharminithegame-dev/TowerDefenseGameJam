class_name HitscanPopupUI extends BuildingPopupUI

### On Ready Variables
@onready var attack_range_label := $PanelContainer/VBoxContainer/AttackRangeHBox/StatValueLabel
@onready var damage_label := $PanelContainer/VBoxContainer/DamageHBox/StatValueLabel
@onready var attack_rate_label := $PanelContainer/VBoxContainer/AttackRateHBox/StatValueLabel
@onready var sell_value_label := $PanelContainer/VBoxContainer/SellValueHBox/StatValueLabel

### Sets the stat values for building popup ui
func set_popup_ui_stats(stats: Dictionary) -> void:
	attack_range_label.text = str(stats.get("attack_range", 0))
	damage_label.text = str(stats.get("damage", 0))
	attack_rate_label.text = str(stats.get("attack_rate", 0))
	sell_value_label.text = str(stats.get("sell_value", 0))
