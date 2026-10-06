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
	var player = get_tree().get_first_node_in_group("player")
	if player:
		bind_player(player)

func bind_player(player: Node) -> void:
	if player.has_signal("health_changed"):
		player.health_changed.connect(update_health)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(update_stamina)
	if player.has_signal("interactable_detected"):
		player.interactable_detected.connect(show_prompt)
	if player.has_signal("interactable_lost"):
		player.interactable_lost.connect(hide_prompt)

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
