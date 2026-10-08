extends CanvasLayer

## Minimal In-Game HUD for ECHOES BENEATH
@onready var health_bar: ProgressBar = $MarginContainer/VBoxVitals/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxVitals/StaminaBar
@onready var prompt_label: Label = $CenterContainer/PromptLabel
@onready var objective_label: Label = $TopRightMargin/ObjectiveLabel
@onready var subtitle_label: Label = $BottomMargin/SubtitleLabel
var subtitle_revision: int = 0
var objective_revision: int = 0
var ammo_label: Label
var oxygen_label: Label
var reticle: Label

func _ready() -> void:
	ammo_label = Label.new()
	ammo_label.position = Vector2(32, 32)
	ammo_label.add_theme_font_size_override("font_size", 18)
	add_child(ammo_label)
	oxygen_label = Label.new()
	oxygen_label.position = Vector2(32, 60)
	add_child(oxygen_label)
	var controls := Label.new()
	controls.text = "WASD Move • Shift Sprint • Space Jump • C Crouch/Dive • F Light • E Interact • J Journal • Esc Pause"
	controls.position = Vector2(32, 88)
	controls.add_theme_font_size_override("font_size", 15)
	add_child(controls)
	reticle = Label.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.text = "+"
	reticle.add_theme_font_size_override("font_size", 24)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(reticle)
	_position_reticle()
	get_viewport().size_changed.connect(_position_reticle)
	prompt_label.visible = false
	subtitle_label.visible = false
	if MissionManager:
		MissionManager.objective_updated.connect(_on_objective_updated)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		bind_player(player)

func _position_reticle() -> void:
	if is_instance_valid(reticle):
		reticle.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(8, 16)

func bind_player(player: Node) -> void:
	if player.has_signal("ammunition_changed"):
		player.ammunition_changed.connect(func(loaded, reserve): ammo_label.text = "SIDEARM  %d / %d   •   R Reload   Q Melee" % [loaded, reserve])
		ammo_label.text = "SIDEARM  %d / %d   •   R Reload   Q Melee" % [player.ammunition, player.reserve_ammunition]
	if player.has_signal("oxygen_changed"):
		player.oxygen_changed.connect(func(value, maximum):
			oxygen_label.text = "AIR  %ds   •   Space Ascend / C Dive" % int(value)
			oxygen_label.visible = value < maximum)
	oxygen_label.visible = false
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
	if not is_inside_tree():
		return
	subtitle_revision += 1
	var revision = subtitle_revision
	subtitle_label.text = "%s: \"%s\"" % [speaker, line]
	subtitle_label.visible = true
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if revision == subtitle_revision:
			subtitle_label.visible = false)

func _on_objective_updated(id: String, desc: String, is_comp: bool) -> void:
	objective_revision += 1
	var revision = objective_revision
	if is_comp:
		objective_label.text = "COMPLETED: " + desc
		var timer = get_tree().create_timer(4.0)
		timer.timeout.connect(func():
			if revision == objective_revision:
				objective_label.text = "")
	else:
		objective_label.text = "OBJECTIVE: " + desc

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		reticle.visible = player.is_aiming
	reticle.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(8, 16)
