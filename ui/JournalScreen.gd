extends CanvasLayer

## Field journal / inventory / skills screen. Owned by GameManager; J toggles it in gameplay
## (all levels, including the Prologue), Esc or J closes it. Pauses the tree while open.
## The Journal tab also lists the level's optional archaeology sites (CampaignExploration data).

const GameTheme := preload("res://ui/GameTheme.gd")
const SKILL_INFO := {
	"survivor_resource_awareness": ["Survivor", "Resource Awareness", "Supplies glint when nearby."],
	"survivor_deep_breath": ["Survivor", "Deep Breath", "Hold breath longer underwater."],
	"explorer_strong_grip": ["Explorer", "Strong Grip", "Hang from ledges longer."],
	"explorer_quick_mantle": ["Explorer", "Quick Mantle", "Climb ledges faster."],
	"hunter_silent_step": ["Hunter", "Silent Step", "Quieter footsteps while crouched."],
	"hunter_steady_aim": ["Hunter", "Steady Aim", "Less sway while aiming."],
}

var _root: Control
var tabs: TabContainer
var _journal_text: RichTextLabel
var _inventory_text: RichTextLabel
var _skills_box: VBoxContainer
var _skills_header: Label
var _was_paused := false
var _frame: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	if not InputMap.has_action("journal"):
		InputMap.add_action("journal")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J
		InputMap.action_add_event("journal", key)
	_root = Control.new()
	_root.theme = GameTheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.018, 0.016, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	# Proportional frame so it reads the same at 1280x720 and 1920x1080.
	var margin := MarginContainer.new()
	margin.anchor_left = 0.1
	margin.anchor_right = 0.9
	margin.anchor_top = 0.09
	margin.anchor_bottom = 0.91
	_root.add_child(margin)
	_frame = margin
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(GameTheme.caption("MARA'S EXPEDITION NOTES", GameTheme.FS_SMALL, GameTheme.ECHO))
	titles.add_child(GameTheme.heading("FIELD JOURNAL", 38))
	top.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var hint := Label.new()
	hint.text = "Q / E or arrows switch tabs     J / Esc close"
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.add_theme_font_size_override("font_size", GameTheme.FS_SMALL)
	hint.add_theme_color_override("font_color", GameTheme.MUTED)
	top.add_child(hint)
	column.add_child(top)
	column.add_child(GameTheme.rule())
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_journal_text = _rich(tabs, "Journal")
	_inventory_text = _rich(tabs, "Inventory")
	var skills_scroll := ScrollContainer.new()
	skills_scroll.name = "Skills"
	tabs.add_child(skills_scroll)
	_skills_box = VBoxContainer.new()
	_skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override("separation", 10)
	skills_scroll.add_child(_skills_box)
	visible = false

func _rich(parent: Node, title: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.name = title
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 21)
	parent.add_child(r)
	return r

func is_open() -> bool:
	return visible

func open(tab := 0) -> void:
	_refresh()
	tabs.current_tab = tab
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_set_hud_visible(false)
	GameTheme.wire_sounds(_root)
	GameTheme.play_ui("open")
	GameTheme.fade_in(_root, Vector2.ZERO, 0.18)
	tabs.get_tab_bar().grab_focus()

func close() -> void:
	visible = false
	_set_hud_visible(true)
	GameTheme.play_ui("back")
	get_tree().paused = _was_paused
	if GameManager.current_state == GameManager.GameState.GAMEPLAY:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_Q, KEY_E]:
			tabs.current_tab = wrapi(tabs.current_tab + (1 if event.physical_keycode == KEY_E else -1), 0, tabs.get_tab_count())
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("journal") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") and GameManager.current_state == GameManager.GameState.GAMEPLAY and not get_tree().paused:
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path.begins_with("res://levels/") and get_tree().get_first_node_in_group("player"):
			open()
			# Consume so the level's own legacy journal panel does not open as well.
			get_viewport().set_input_as_handled()

func _refresh() -> void:
	var names := ["Prologue", "Chapter 1", "Chapter 2", "Chapter 3", "Chapter 4", "Chapter 5", "Chapter 6", "Chapter 7", "Chapter 8", "Chapter 9", "Chapter 10", "Finale", "Epilogue"]
	var t := "[b][color=#dbb370]%s[/color][/b]\n\n" % names[clampi(GameManager.current_chapter, 0, 12)]
	t += "[b][color=#61dbe6]CURRENT OBJECTIVES[/color][/b]\n"
	if MissionManager.active_objectives.is_empty():
		t += "  [color=#999]None[/color]\n"
	for id in MissionManager.active_objectives:
		t += "  •  %s\n" % MissionManager.active_objectives[id]
	t += "\n[b][color=#61dbe6]COMPLETED[/color][/b]\n"
	if MissionManager.completed_objectives.is_empty():
		t += "  [color=#999]Nothing yet[/color]\n"
	for id in MissionManager.completed_objectives:
		t += "  [color=#8a8]✓[/color]  %s\n" % str(id).replace("obj_", "").replace("_", " ").capitalize()
	var exploration := _find_exploration()
	if exploration:
		t += "\n[b][color=#61dbe6]OPTIONAL ARCHAEOLOGY SITES[/color][/b]\n"
		for record in exploration.get("records"):
			var entry: Dictionary = exploration.get("state").get(record.id, {})
			t += "  •  %s — %s\n" % [record.name, "[color=#8a8]Recovered[/color]" if entry.get("solved", false) else "[color=#999]Unexplored[/color]"]
			if entry.get("read", false) and record.get("clue"):
				t += "      [i]%s[/i]\n" % record.clue
	var entries: Array = SaveManager.game_data.get("journal_entries", [])
	if not entries.is_empty():
		t += "\n[b][color=#61dbe6]NOTES[/color][/b]\n"
		for e in entries:
			t += "  •  %s\n" % str(e)
	_journal_text.text = t
	var inv := "[b][color=#61dbe6]EQUIPMENT[/color][/b]\n"
	var player := get_tree().get_first_node_in_group("player")
	if player:
		inv += "  •  Flashlight\n"
		if player.get("ammunition") != null:
			inv += "  •  Sidearm — %d loaded / %d reserve\n" % [int(player.ammunition), int(player.reserve_ammunition)]
		inv += "  •  Health %d / %d   •   Stamina %d / %d\n" % [int(player.current_health), int(player.max_health), int(player.current_stamina), int(player.max_stamina)]
	inv += "\n[b][color=#61dbe6]COLLECTED ITEMS[/color][/b]\n"
	var items: Array = SaveManager.game_data.get("inventory", [])
	if items.is_empty():
		inv += "  [color=#999]No artifacts collected yet.[/color]\n"
	for item in items:
		inv += "  •  %s\n" % str(item).replace("_", " ").capitalize()
	_inventory_text.text = inv
	_build_skills()

func _find_exploration() -> Node:
	var scene := get_tree().current_scene
	if not scene:
		return null
	for child in scene.get_children():
		var s: Script = child.get_script()
		if s and s.resource_path == "res://systems/CampaignExploration.gd":
			return child
	return null

func _build_skills() -> void:
	for c in _skills_box.get_children():
		c.queue_free()
	_skills_header = Label.new()
	_skills_header.add_theme_color_override("font_color", GameTheme.ACCENT)
	_skills_header.text = "XP %d   •   Skill points available: %d   (1 point per 100 XP)" % [SkillManager.current_xp, SkillManager.available_skill_points]
	_skills_box.add_child(_skills_header)
	for id in SkillManager.unlocked_skills:
		var info: Array = SKILL_INFO.get(id, ["", id, ""])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", GameTheme.box(Color(1, 1, 1, 0.035), Color(GameTheme.ACCENT, 0.18), 1, 8, 14))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var text := Label.new()
		text.text = "%s  ·  %s\n%s" % [str(info[0]).to_upper(), info[1], info[2]]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var button := Button.new()
		button.custom_minimum_size = Vector2(160, 44)
		if SkillManager.is_skill_unlocked(id):
			button.text = "Unlocked"
			button.disabled = true
		else:
			button.text = "Unlock (1 pt)"
			button.disabled = SkillManager.available_skill_points <= 0
			button.pressed.connect(func():
				SkillManager.unlock_skill(id)
				_build_skills())
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
		_skills_box.add_child(card)
	GameTheme.wire_sounds(_skills_box)

## Hide the gameplay HUD behind the journal so the two layers never overlap.
func _set_hud_visible(on: bool) -> void:
	var scene := get_tree().current_scene
	var hud = scene.get_node_or_null("HUD") if scene else null
	if hud is CanvasLayer:
		hud.visible = on
