extends Control

var next_unit := 0
var unit_names := ["Unit A", "Unit B", "Unit C", "Unit D"]

@onready var summon_button: Button = $TopBar/TopRow/SummonButton
@onready var status_label: Label = $StatusLabel
@onready var unit_a_label: Label = $Board/BoardMargin/Units/UnitA/UnitALabel
@onready var unit_b_label: Label = $Board/BoardMargin/Units/UnitB/UnitBLabel
@onready var wave_label: Label = $TopBar/TopRow/WaveLabel

func _ready() -> void:
	summon_button.pressed.connect(_on_summon_pressed)
	status_label.text = "Prototype loaded. Ready to summon."

func _on_summon_pressed() -> void:
	var summoned := unit_names[next_unit]
	next_unit = (next_unit + 1) % unit_names.size()
	unit_a_label.text = summoned
	unit_b_label.text = unit_names[next_unit]
	wave_label.text = "Wave: %d" % (1 + next_unit)
	status_label.text = "Summoned %s (placeholder)." % summoned
