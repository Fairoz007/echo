extends CanvasLayer

## Minimal In-Game HUD for ECHOES BENEATH
@onready var health_bar: ProgressBar = $MarginContainer/VBoxVitals/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxVitals/StaminaBar
@onready var prompt_label: Label = $CenterContainer/PromptLabel
@onready var objective_label: Label = $TopRightMargin/ObjectiveLabel
@onready var subtitle_label: Label = $BottomMargin/SubtitleLabel

func _ready() -> void:
	prompt_label.visible = false
	subtitle_label.visible = false
	if MissionManager:
		MissionManager.objective_updated.connect(_on_objective_updated)

func update_health(val: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = val

func update_stamina(val: float, max_val: float) -> void:
	stamina_bar.max_value = max_val
	stamina_bar.value = val

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false

func show_subtitle(speaker: String, line: String, duration: float = 3.5) -> void:
	subtitle_label.text = "%s: \"%s\"" % [speaker, line]
	subtitle_label.visible = true
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): subtitle_label.visible = false)

func _on_objective_updated(id: String, desc: String, is_comp: bool) -> void:
	if is_comp:
		objective_label.text = "COMPLETED: " + desc
		var timer = get_tree().create_timer(4.0)
		timer.timeout.connect(func(): objective_label.text = "")
	else:
		objective_label.text = "OBJECTIVE: " + desc
