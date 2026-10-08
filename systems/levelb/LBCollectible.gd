extends Node3D
## Optional discovery: journal page, Vaelor tablet or Meridian document.
## Interact (E) to read. Registers + completes an optional MissionManager objective,
## persists through SaveManager ("persistent_world" group).

@export var collectible_id := "unnamed"
@export_enum("journal", "tablet", "document") var kind := "journal"
@export var title := ""
@export_multiline var body := ""

var collected := false
var _visual: Node3D
var _glint: OmniLight3D
var _area: Area3D
var _t := 0.0
static var _panel_layer: CanvasLayer

func _ready() -> void:
	add_to_group("persistent_world")
	add_to_group("levelb_collectible")
	set_meta("collision", "none")
	_build_visual()
	_area = preload("res://systems/levelb/LBKit.gd").interaction(self, Vector3(0, 0.6, 0), Vector3(1.6, 1.6, 1.6), "[E] Read: " + title)
	_area.interacted.connect(_on_read)

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var kit := preload("res://systems/levelb/LBKit.gd")
	match kind:
		"journal":
			var cover := BoxMesh.new()
			cover.size = Vector3(0.24, 0.035, 0.32)
			kit.mesh(_visual, cover, global_transform * Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.03, 0)), kit.std_mat(Color(0.32, 0.17, 0.09), 0.75))
			var pages := BoxMesh.new()
			pages.size = Vector3(0.22, 0.03, 0.30)
			kit.mesh(_visual, pages, global_transform * Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.006, 0.035, 0)), kit.std_mat(Color(0.86, 0.80, 0.66), 0.9))
		"tablet":
			var slab := BoxMesh.new()
			slab.size = Vector3(0.55, 0.75, 0.12)
			kit.mesh(_visual, slab, global_transform * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.38, 0)), kit.rock_material(Color(0.5, 0.52, 0.5), 0.2))
			var glyph := BoxMesh.new()
			glyph.size = Vector3(0.38, 0.5, 0.01)
			kit.mesh(_visual, glyph, global_transform * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.40, 0.065)), kit.std_mat(Color(0.2, 0.5, 0.55), 0.4, 0.0, Color(0.25, 0.85, 0.9), 1.6))
		_:
			var folder := BoxMesh.new()
			folder.size = Vector3(0.24, 0.02, 0.31)
			kit.mesh(_visual, folder, global_transform * Transform3D(Basis(Vector3.UP, -0.3), Vector3(0, 0.02, 0)), kit.std_mat(Color(0.18, 0.2, 0.22), 0.6))
			var sheet := BoxMesh.new()
			sheet.size = Vector3(0.21, 0.005, 0.29)
			kit.mesh(_visual, sheet, global_transform * Transform3D(Basis(Vector3.UP, -0.22), Vector3(0.02, 0.033, 0.01)), kit.std_mat(Color(0.9, 0.9, 0.86), 0.9))
			var stripe := BoxMesh.new()
			stripe.size = Vector3(0.21, 0.006, 0.04)
			kit.mesh(_visual, stripe, global_transform * Transform3D(Basis(Vector3.UP, -0.22), Vector3(0.02, 0.036, -0.1)), kit.std_mat(Color(0.75, 0.12, 0.1), 0.6))
	_glint = OmniLight3D.new()
	_glint.light_color = Color(1.0, 0.85, 0.55) if kind != "tablet" else Color(0.4, 0.9, 1.0)
	_glint.light_energy = 0.7
	_glint.omni_range = 2.2
	_glint.position = Vector3(0, 0.5, 0)
	add_child(_glint)

func _process(delta: float) -> void:
	_t += delta
	if _glint and not collected:
		_glint.light_energy = 0.55 + sin(_t * 2.2) * 0.25

func _on_read(_p: Node) -> void:
	_show_panel()
	if collected:
		return
	collected = true
	MissionManager.register_objective("opt_" + collectible_id, "Discovery: " + title)
	MissionManager.complete_objective("opt_" + collectible_id)
	_restore_main_objective()
	if _glint:
		_glint.visible = false
	if AudioManager and AudioManager.has_method("play_story_line"):
		AudioManager.play_story_line("Mara", _mara_reaction(), 3.5)

func _restore_main_objective() -> void:
	await get_tree().create_timer(4.3).timeout
	var keys := MissionManager.active_objectives.keys()
	if not keys.is_empty():
		var k = keys[keys.size() - 1]
		MissionManager.objective_updated.emit(k, MissionManager.active_objectives[k], false)

func _mara_reaction() -> String:
	match kind:
		"tablet":
			return "Vaelor script... another piece of the record."
		"document":
			return "Meridian paperwork. They knew more than they let on."
	return "A journal page. I'll keep this."

func _show_panel() -> void:
	if _panel_layer and is_instance_valid(_panel_layer):
		_panel_layer.queue_free()
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 40
	get_tree().root.add_child(_panel_layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.2
	panel.anchor_bottom = 0.75
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.075, 0.06, 0.93)
	style.border_color = Color(0.75, 0.6, 0.35)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	_panel_layer.add_child(panel)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.text = "[b][color=#e3c48a]%s[/color][/b]\n[i]%s[/i]\n\n%s\n\n[color=#8a7a60](closes automatically)[/color]" % [title, kind.capitalize(), body]
	panel.add_child(text)
	var layer := _panel_layer
	get_tree().create_timer(9.0).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())

func get_persistent_state() -> Dictionary:
	return {"collected": collected}

func restore_persistent_state(data: Dictionary) -> void:
	collected = bool(data.get("collected", false))
	if collected:
		if not MissionManager.completed_objectives.has("opt_" + collectible_id):
			MissionManager.completed_objectives.append("opt_" + collectible_id)
		if _glint:
			_glint.visible = false
