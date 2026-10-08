extends Node

## Save and Persistence System Singleton
const SAVE_PATH_TEMPLATE = "user://save_slot_%d.json"
var restore_pending: bool = false
var save_directory: String = "user://"
const PERSISTENT_MECHANISMS = ["HydraulicPuzzle/Counterweight", "HydraulicPuzzle/WaterFlowMesh", "SanctuaryGate", "FloodedBasin/WaterPlane", "TempleSanctum/SunkenGate"]
const PERSISTENT_LEVEL_FIELDS = ["artifact_acquired", "has_spoken_to_nadiya", "has_spoken_to_elias", "has_examined_map", "has_examined_gate", "has_reported_gate", "is_water_diverted", "has_read_inscription", "has_collapse_triggered", "has_repaired_radio", "enemies_remaining", "has_seen_drake", "is_reservoir_drained", "has_read_mural", "has_visited_tomb", "has_confronted_adrian", "has_tremor_occurred", "active_nodes_disabled", "has_drake_spoken", "is_overload_triggered"]

func _ready() -> void:
	get_tree().scene_changed.connect(apply_pending_state)

var game_data: Dictionary = {
	"version": 1,
	"timestamp": 0,
	"chapter": 0,
	"checkpoint_id": "cp_start",
	"player": {
		"health": 100.0,
		"stamina": 100.0,
		"position": [0.0, 1.0, 0.0],
		"rotation_y": 0.0
	},
	"inventory": [],
	"skills": [],
	"puzzles_solved": [],
	"journal_entries": []
}

func reset_data() -> void:
	restore_pending = false
	game_data["chapter"] = 0
	game_data["checkpoint_id"] = "cp_start"
	game_data["player"]["health"] = 100.0
	game_data["inventory"].clear()
	game_data["skills"].clear()
	game_data["puzzles_solved"].clear()
	game_data["journal_entries"].clear()
	game_data["player"] = {"health": 100.0, "stamina": 100.0, "position": [0.0, 1.0, 0.0], "rotation_y": 0.0}
	game_data.erase("mission")
	game_data.erase("progression")
	game_data.erase("level_state")
	game_data.erase("mechanisms")
	game_data.erase("custom_level_state")
	game_data.erase("enemy_states")
	game_data.erase("persistent_world")
	MissionManager.active_objectives.clear()
	MissionManager.completed_objectives.clear()
	MissionManager.current_checkpoint_id = "cp_start"
	MissionManager.current_checkpoint_transform = Transform3D.IDENTITY
	SkillManager.current_xp = 0
	SkillManager.available_skill_points = 0
	for skill in SkillManager.unlocked_skills:
		SkillManager.unlocked_skills[skill] = false

func save_game(slot: int = 0) -> bool:
	if not capture_live_state():
		return false
	game_data["timestamp"] = Time.get_unix_time_from_system()
	game_data["chapter"] = GameManager.current_chapter
	game_data["checkpoint_id"] = MissionManager.current_checkpoint_id
	
	var path = save_path(slot)
	var pending_path = path + ".tmp"
	var file = FileAccess.open(pending_path, FileAccess.WRITE)
	if not file:
		push_error("[SAVE] Failed to open file for writing: " + path)
		return false
		
	var json_string = JSON.stringify(game_data, "\t")
	file.store_string(json_string)
	file.flush()
	file.close()
	var absolute_path = ProjectSettings.globalize_path(path)
	var backup_path = absolute_path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(absolute_path, backup_path) != OK:
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path), absolute_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		return false
	print("[SAVE] Successfully saved game slot", slot, "to", path)
	return true

func load_game(slot: int = 0) -> bool:
	var path = save_path(slot)
	if not FileAccess.file_exists(path):
		print("[SAVE] No save file found at:", path)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
		
	var content = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SAVE] Corrupt save file format")
		return false
		
	if not _valid_save(parsed):
		push_error("[SAVE] Invalid required save fields")
		return false
	game_data = parsed
	restore_pending = true
	print("[SAVE] Loaded game slot", slot)
	return true

func save_path(slot: int) -> String:
	return save_directory.path_join("save_slot_%d.json" % slot)

func manual_save() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	var scene = get_tree().current_scene
	if not player or player.get("current_health") == null or player.current_health <= 0.0 or not player.is_on_floor():
		return false
	if player.current_state in [player.State.SWIM, player.State.MANTLE, player.State.LEDGE_HANG, player.State.DEAD]:
		return false
	for tween in get_tree().get_processed_tweens():
		if tween.is_running():
			return false
	if scene:
		for field in ["transition_started", "chapter_transition_pending"]:
			for property in scene.get_property_list():
				if property.name == field and scene.get(field):
					return false
	return save_game(0)

func _valid_save(data: Dictionary) -> bool:
	var chapter = data.get("chapter")
	if not (chapter is int or chapter is float) or chapter < 0 or chapter > 12 or int(chapter) != chapter:
		return false
	var player = data.get("player")
	if not player is Dictionary:
		return false
	var pos = player.get("position")
	if not pos is Array or pos.size() != 3:
		return false
	for coordinate in pos:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
			return false
	for field in ["mission", "progression", "level_state", "mechanisms", "custom_level_state", "enemy_states", "persistent_world"]:
		if data.has(field) and not data[field] is Dictionary:
			return false
	for field in ["health", "stamina", "rotation_y"]:
		var value = player.get(field, 0.0)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	for field in ["current_oxygen", "ammunition", "reserve_ammunition"]:
		if player.has(field):
			var value = player[field]
			if not (value is int or value is float) or value < 0 or not is_finite(float(value)):
				return false
	var mission: Dictionary = data.get("mission", {})
	if not mission.get("active", {}) is Dictionary or not mission.get("completed", []) is Array:
		return false
	var progression: Dictionary = data.get("progression", {})
	if not progression.get("unlocked", {}) is Dictionary:
		return false
	for field in ["xp", "points"]:
		var value = progression.get(field, 0)
		if not (value is int or value is float) or value < 0 or not is_finite(float(value)):
			return false
	var mechanisms: Dictionary = data.get("mechanisms", {})
	for path in mechanisms:
		if not mechanisms[path] is Dictionary:
			return false
		var position = mechanisms[path].get("position")
		if not position is Array or position.size() != 3:
			return false
		for coordinate in position:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
				return false
	var enemies: Dictionary = data.get("enemy_states", {})
	for path in enemies:
		if not enemies[path] is Dictionary:
			return false
		var enemy: Dictionary = enemies[path]
		var health = enemy.get("health")
		var enemy_pos = enemy.get("position")
		if not (health is int or health is float) or not is_finite(float(health)) or not enemy_pos is Array or enemy_pos.size() != 3:
			return false
		for coordinate in enemy_pos:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
				return false
	return true

func capture_live_state() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.get("current_health") == null:
			return false
		var pos: Vector3 = player.global_position
		game_data["player"] = {"health": player.current_health, "stamina": player.current_stamina, "position": [pos.x, pos.y, pos.z], "rotation_y": player.rotation.y}
		for field in ["current_oxygen", "ammunition", "reserve_ammunition"]:
			if player.get(field) != null:
				game_data["player"][field] = player.get(field)
	game_data["mission"] = {"active": MissionManager.active_objectives.duplicate(true), "completed": MissionManager.completed_objectives.duplicate(), "checkpoint": MissionManager.current_checkpoint_id}
	game_data["progression"] = {"xp": SkillManager.current_xp, "points": SkillManager.available_skill_points, "unlocked": SkillManager.unlocked_skills.duplicate()}
	var scene = get_tree().current_scene
	var level_state: Dictionary = {}
	if scene and scene.get_script():
		for property in scene.get_property_list():
			if property.name in PERSISTENT_LEVEL_FIELDS:
				level_state[property.name] = scene.get(property.name)
	game_data["level_state"] = level_state
	var mechanisms: Dictionary = {}
	if scene:
		for path in PERSISTENT_MECHANISMS:
			var mechanism = scene.get_node_or_null(path)
			if mechanism is Node3D:
				mechanisms[path] = {"position": [mechanism.position.x, mechanism.position.y, mechanism.position.z], "visible": mechanism.visible}
	game_data["mechanisms"] = mechanisms
	game_data["custom_level_state"] = scene.get_persistent_state() if scene and scene.has_method("get_persistent_state") else {}
	var enemies: Dictionary = {}
	if scene:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if scene.is_ancestor_of(enemy):
				var pos: Vector3 = enemy.global_position
				enemies[str(scene.get_path_to(enemy))] = {"health": enemy.current_health, "position": [pos.x, pos.y, pos.z], "rotation_y": enemy.rotation.y}
	game_data["enemy_states"] = enemies
	var world_state: Dictionary = {}
	if scene:
		for node in get_tree().get_nodes_in_group("persistent_world"):
			if scene.is_ancestor_of(node) and node.has_method("get_persistent_state"):
				world_state[str(scene.get_path_to(node))] = node.get_persistent_state()
	game_data["persistent_world"] = world_state
	return true

func apply_pending_state() -> void:
	if not restore_pending:
		return
	restore_pending = false
	var mission: Dictionary = game_data.get("mission", {})
	MissionManager.active_objectives = mission.get("active", {}).duplicate(true)
	MissionManager.completed_objectives = mission.get("completed", []).duplicate()
	MissionManager.current_checkpoint_id = mission.get("checkpoint", game_data.get("checkpoint_id", "cp_start"))
	var progression: Dictionary = game_data.get("progression", {})
	SkillManager.current_xp = int(progression.get("xp", 0))
	SkillManager.available_skill_points = int(progression.get("points", 0))
	for skill in SkillManager.unlocked_skills:
		SkillManager.unlocked_skills[skill] = bool(progression.get("unlocked", {}).get(skill, false))
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var saved: Dictionary = game_data["player"]
		var pos: Array = saved["position"]
		player.global_position = Vector3(pos[0], pos[1], pos[2])
		player.rotation.y = saved.get("rotation_y", 0.0)
		player.current_health = clampf(saved.get("health", player.max_health), 0.0, player.max_health)
		player.current_stamina = clampf(saved.get("stamina", player.max_stamina), 0.0, player.max_stamina)
		for field in ["current_oxygen", "ammunition", "reserve_ammunition"]:
			if saved.has(field) and player.get(field) != null:
				player.set(field, saved[field])
		player.health_changed.emit(player.current_health, player.max_health)
		player.stamina_changed.emit(player.current_stamina, player.max_stamina)
		if player.has_signal("oxygen_changed"):
			player.oxygen_changed.emit(player.current_oxygen, player.max_oxygen)
		if player.has_signal("ammunition_changed"):
			player.ammunition_changed.emit(player.ammunition, player.reserve_ammunition)
	var scene = get_tree().current_scene
	if scene:
		if game_data.has("enemy_states"):
			var enemies: Dictionary = game_data["enemy_states"]
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not scene.is_ancestor_of(enemy):
					continue
				var path = str(scene.get_path_to(enemy))
				if not enemies.has(path) or enemies[path].get("health", 0.0) <= 0.0:
					enemy.queue_free()
				else:
					var saved_enemy: Dictionary = enemies[path]
					enemy.current_health = saved_enemy["health"]
					var position: Array = saved_enemy["position"]
					enemy.global_position = Vector3(position[0], position[1], position[2])
					enemy.rotation.y = saved_enemy.get("rotation_y", 0.0)
		var state: Dictionary = game_data.get("level_state", {})
		for property in scene.get_property_list():
			if property.name in PERSISTENT_LEVEL_FIELDS and state.has(property.name):
				scene.set(property.name, state[property.name])
		var mechanisms: Dictionary = game_data.get("mechanisms", {})
		for path in PERSISTENT_MECHANISMS:
			var mechanism = scene.get_node_or_null(path)
			if mechanism is Node3D and mechanisms.has(path):
				var mechanism_state: Dictionary = mechanisms[path]
				var pos: Array = mechanism_state.get("position", [])
				if pos.size() == 3:
					mechanism.position = Vector3(pos[0], pos[1], pos[2])
				mechanism.visible = mechanism_state.get("visible", true)
		if scene.has_method("on_save_restored"):
			scene.call_deferred("on_save_restored")
		if scene.has_method("restore_persistent_state"):
			scene.restore_persistent_state(game_data.get("custom_level_state", {}))
		var world_state: Dictionary = game_data.get("persistent_world", {})
		for path in world_state:
			var node = scene.get_node_or_null(path)
			if node and node.has_method("restore_persistent_state") and world_state[path] is Dictionary:
				node.restore_persistent_state(world_state[path])
	for objective in MissionManager.active_objectives:
		MissionManager.objective_updated.emit(objective, MissionManager.active_objectives[objective], false)
