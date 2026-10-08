extends Node3D

## Authored optional archaeology chambers. All visible geometry uses Tripo GLBs.
const FLOOR = "res://assets/environment/cave/cave_floor_sediment.glb"
const WALL = "res://assets/environment/cave/cave_wall_limestone.glb"
const ROOF = "res://assets/environment/cave/cave_ceiling_limestone.glb"
const RELIC = "res://assets/models/optimized/prop_vaelor_key_LOD0.glb"
var chapter := 0
var records: Array = []
var state: Dictionary = {}
var journal: CanvasLayer
var journal_text: RichTextLabel
var panel: PanelContainer
var journal_voice_played := false

func configure(chapter_number: int) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chapter = chapter_number
	name = "CampaignExploration"
	add_to_group("persistent_world")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/exploration.json"))
	records = catalog.get(str(chapter), [])
	var positions := [Vector3(-36, 0, -10), Vector3(36, 0, -10), Vector3(30, 0, 36)]
	for index in records.size():
		var record: Dictionary = records[index]
		record.solution = [int(record.solution[0]), int(record.solution[1]), int(record.solution[2])]
		state[record.id] = {"read": false, "solved": false, "dials": [0, 0, 0]}
		var room := Node3D.new()
		room.name = record.id
		# Room gameplay collision is authored via _solid(); skip the auto collision pass.
		room.set_meta("collision", "none")
		add_child(room)
		room.position = positions[index] + (Vector3.UP * 1.2 if chapter == 6 else Vector3.ZERO)
		_build_room(room, record)
	_build_journal()
	if not InputMap.has_action("journal"):
		InputMap.add_action("journal")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_J
		InputMap.action_add_event("journal", key)

func _place_model(parent: Node3D, path: String, size: Vector3, pos: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("[EXPLORATION] Missing Tripo source: " + path)
		return null
	var model: Node3D = load(path).instantiate()
	parent.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var found := false
	for mesh in meshes:
		var transformed: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(transformed) if found else transformed
		found = true
	if found:
		var dimensions := bounds.size
		var source_axis := dimensions.min_axis_index()
		var target_axis := size.min_axis_index()
		if source_axis != target_axis:
			if source_axis == 0 and target_axis == 1 or source_axis == 1 and target_axis == 0:
				model.rotation.z = PI / 2.0
			elif source_axis == 0 and target_axis == 2 or source_axis == 2 and target_axis == 0:
				model.rotation.y = PI / 2.0
			else:
				model.rotation.x = PI / 2.0
		var local_size := (model.basis.inverse() * size).abs()
		model.scale = Vector3(local_size.x / maxf(dimensions.x, 0.001), local_size.y / maxf(dimensions.y, 0.001), local_size.z / maxf(dimensions.z, 0.001))
		model.position = pos - model.basis * bounds.get_center()
	return model

func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	parent.add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _build_room(room: Node3D, record: Dictionary) -> void:
	_place_model(room, FLOOR, Vector3(12, 0.35, 12), Vector3(0, -0.05, 0))
	_solid(room, Vector3(0, -0.2, 0), Vector3(12, 0.4, 12))
	_place_model(room, ROOF, Vector3(12, 0.6, 12), Vector3(0, 4.5, 0))
	for side in [-1, 1]:
		_place_model(room, WALL, Vector3(0.6, 4, 12), Vector3(side * 6, 2, 0))
		_solid(room, Vector3(side * 6, 2, 0), Vector3(0.5, 4, 12))
	_place_model(room, WALL, Vector3(12, 4, 0.6), Vector3(0, 2, -6))
	_solid(room, Vector3(0, 2, -6), Vector3(12, 4, 0.5))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.74, 0.86, 0.82)
	lamp.light_energy = 1.1
	lamp.omni_range = 9.0
	room.add_child(lamp)
	lamp.position = Vector3(0, 3.2, 0)
	_make_interaction(room, Vector3(0, 1, 3.7), "[E] Read " + record.name, func(_player): _read(record))
	for index in 3:
		var location := Vector3(-3 + index * 3, 0.65, -1)
		var dial := _place_model(room, RELIC, Vector3(0.45, 0.6, 0.45), location)
		if dial:
			dial.name = "Dial_%d" % index
		_make_interaction(room, location, "[E] Adjust %s dial %d" % [record.kind, index + 1], func(_player): _turn(record, index))
	_place_model(room, RELIC, Vector3(0.65, 0.65, 0.65), Vector3(0, 0.8, -4))
	_make_interaction(room, Vector3(0, 0.8, -4), "[E] Test mechanism / Recover archive", func(player): _test(record, player))

func _make_interaction(parent: Node3D, pos: Vector3, prompt: String, callback: Callable) -> void:
	var interaction := Interactable3D.new()
	interaction.prompt_message = prompt
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	shape.shape = sphere
	interaction.add_child(shape)
	parent.add_child(interaction)
	interaction.position = pos
	interaction.interacted.connect(callback)

func _read(record: Dictionary) -> void:
	state[record.id].read = true
	_show(record.name + "\n\n" + record.lore + "\n\n" + record.clue)
	var voice = get_parent().get_node_or_null("CampaignDialogue")
	if voice and not journal_voice_played:
		journal_voice_played = true
		voice.play_event("journal")

func _turn(record: Dictionary, dial: int) -> void:
	var entry: Dictionary = state[record.id]
	if entry.solved:
		return
	entry.dials[dial] = (int(entry.dials[dial]) + 1) % 4
	var mechanism := get_node_or_null("%s/Dial_%d" % [record.id, dial]) as Node3D
	if mechanism:
		mechanism.rotation.y = float(entry.dials[dial]) * PI / 2.0
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.show_subtitle("Mechanism", "%s • %s" % [record.name, _positions(entry.dials)], 2.5)

func _positions(values: Array) -> String:
	return "%d / %d / %d" % [values[0] + 1, values[1] + 1, values[2] + 1]

func _test(record: Dictionary, player: Player) -> void:
	var entry: Dictionary = state[record.id]
	if entry.solved:
		_show("Archive recovered\n\n" + record.lore)
		return
	if not entry.read:
		_show("The lock has no markings. Examine the entrance inscription first.")
		return
	if entry.dials != record.solution:
		_show("The mechanism shudders, then settles.\n\nCurrent positions: " + _positions(entry.dials) + "\n\n" + record.clue)
		return
	entry.solved = true
	SkillManager.add_xp(120)
	player.current_health = minf(player.max_health, player.current_health + 25)
	player.reserve_ammunition += 12
	player.health_changed.emit(player.current_health, player.max_health)
	player.ammunition_changed.emit(player.ammunition, player.reserve_ammunition)
	_show("Archive recovered: " + record.name + "\n\n" + record.lore + "\n\nField supplies recovered. +120 archaeology XP.")
	SaveManager.save_game(0)

func _build_journal() -> void:
	journal = CanvasLayer.new()
	journal.layer = 8
	add_child(journal)
	panel = PanelContainer.new()
	panel.position = Vector2(160, 120)
	panel.size = Vector2(800, 600)
	journal.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	journal_text = RichTextLabel.new()
	journal_text.custom_minimum_size = Vector2(800, 520)
	journal_text.add_theme_font_size_override("normal_font_size", 22)
	column.add_child(journal_text)
	var close := Button.new()
	close.text = "Return to exploration [J]"
	close.pressed.connect(_close_journal)
	column.add_child(close)
	panel.hide()

func _show(text: String) -> void:
	journal_text.text = text
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_journal() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		if panel.visible:
			_close_journal()
		else:
			var text := "FIELD JOURNAL • CHAPTER %d\n\nOptional archaeology sites:\n" % chapter
			for record in records:
				var entry: Dictionary = state[record.id]
				var room: Node3D = get_node(record.id)
				text += "\n%s — %s\nSite coordinates: %.0f / %.0f\n" % [record.name, "Recovered" if entry.solved else "Unexplored", room.position.x, room.position.z]
				if entry.read:
					text += record.clue + "\n"
			_show(text)
		get_viewport().set_input_as_handled()

func get_persistent_state() -> Dictionary:
	return state.duplicate(true)

func restore_persistent_state(data: Dictionary) -> void:
	for key in state:
		if data.has(key) and data[key] is Dictionary:
			state[key] = data[key].duplicate(true)
			var values: Array = state[key].get("dials", [0, 0, 0])
			if values.size() != 3:
				values = [0, 0, 0]
			state[key].dials = [int(values[0]), int(values[1]), int(values[2])]
			for dial in 3:
				var mechanism := get_node_or_null("%s/Dial_%d" % [key, dial]) as Node3D
				if mechanism:
					mechanism.rotation.y = float(state[key].dials[dial]) * PI / 2.0
