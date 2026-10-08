extends SceneTree
var audited: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://audio/dialogue_manifest.json"))
	if not manifest is Dictionary or manifest.size() < 4:
		printerr("QA FAILED: required dialogue manifest missing")
		quit(1)
		return
	var count = 0
	for id in manifest:
		var path: String = manifest[id].get("path", "")
		if not ResourceLoader.exists(path):
			printerr("QA FAILED: missing dialogue ", id, " ", path)
			quit(1)
			return
		var stream = load(path)
		if not stream is AudioStream or stream.get_length() <= 0.0:
			quit(1)
			return
		count += 1
		audited[path] = true
	for path in ["res://audio/ambience/cave/AMB_PRO_CAVE_ROOMTONE.wav", "res://audio/ambience/cave/AMB_PRO_CAVE_WATER.wav", "res://audio/movement/FOL_PRO_BREATH_RECOVERY.wav", "res://audio/water/SFX_PRO_CAVE_DRIP.wav", "res://audio/destruction/SFX_PRO_ROCK_SHIFT.wav", "res://audio/vaelor/SFX_PRO_VAELOR_KEY_ACTIVATE.wav", "res://audio/ui/SFX_PRO_UI_OBJECTIVE.wav", "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_01.wav", "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_02.wav", "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_03.wav", "res://audio/footsteps/rock/FOL_PRO_WET_ROCK_STEP_04.wav"]:
		if not ResourceLoader.exists(path) or not load(path) is AudioStream:
			printerr("QA FAILED: missing soundscape asset ", path)
			quit(1)
			return
		count += 1
		audited[path] = true
	if not _audit_directory("res://audio"):
		quit(1)
		return
	print("QA PASS: ", audited.size(), " Godot-imported runtime audio resources; listening/mix QA remains required")
	quit(0)

func _audit_directory(directory: String) -> bool:
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".wav"):
			var path = directory.path_join(file)
			var stream = load(path)
			if not stream is AudioStream or stream.get_length() <= 0.0:
				printerr("QA FAILED: unusable runtime audio ", path)
				return false
			audited[path] = true
	for child in DirAccess.get_directories_at(directory):
		if not _audit_directory(directory.path_join(child)):
			return false
	return true
