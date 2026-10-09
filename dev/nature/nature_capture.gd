extends SceneTree
## DEV ONLY: frame sequences of dev/nature/NatureTest.tscn for wind review.
## godot --path D:/new-dev --rendering-method gl_compatibility --rendering-driver opengl3
##   --resolution 1280x720 -s res://dev/nature/nature_capture.gd -- --quality=1 [--only=walk]
## Output: screenshots/nature/q<level>/<case>_fNN.png ; prints "NATURE ..." metric lines.
var scene
var cam: Camera3D
var out := ""
var only := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var q := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			q = int(a.get_slice("=", 1))
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	out = "res://screenshots/nature/q%d/" % q
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	scene = (load("res://dev/nature/NatureTest.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await physics_frame
	cam = Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.make_current()
	print("NATURE detail=", WindSystem.detail, " leaves_gpu=", scene.leaves.using_gpu, " leaves_visible=", scene.leaves.particles.visible, " grass=", scene.grass.stats.get("accepted", 0))
	var wide := [Vector3(2, 3.2, -9), Vector3(14, 3.5, 2)]
	var canopy := [Vector3(8, 6.0, -4), Vector3(15, 7.5, 7)]
	var row := [Vector3(13, 4.0, -26), Vector3(13, 3.5, -15)]
	var vines := [Vector3(12.5, 2.4, 0), Vector3(16.5, 2.2, 0)]
	for preset in ["CALM", "BREEZE", "STRONG", "STORM"]:
		if only != "" and only != preset:
			continue
		WindSystem.set_preset(WindSystem.preset_from_name(preset), 0.0)
		for i in 20:
			await process_frame
		await _seq(preset.to_lower() + "_wide", wide, 8, 5)
		await _seq(preset.to_lower() + "_canopy", canopy, 8, 3)
		await _seq(preset.to_lower() + "_row", row, 6, 6)
		if preset in ["BREEZE", "STORM"]:
			await _seq(preset.to_lower() + "_vines", vines, 6, 4)
	if only == "" or only == "walk":
		await _walk()
	if only == "" or only == "blend":
		WindSystem.set_preset(WindSystem.Preset.CALM, 0.0)
		await process_frame
		var got := []
		WindSystem.driver().wind_changed.connect(func(s, _d, _t, st): got.append([s, st]))
		WindSystem.set_preset(WindSystem.Preset.STORM, 2.0)
		var maxjump := 0.0
		var prev := WindSystem.strength
		for i in 150:
			await process_frame
			maxjump = maxf(maxjump, absf(WindSystem.strength - prev))
			prev = WindSystem.strength
		print("NATURE blend calm->storm final=%.2f storm=%.2f max_step=%.3f signals=%d" % [WindSystem.strength, WindSystem.storm_intensity, maxjump, got.size()])
	quit()

func _seq(name: String, view: Array, n: int, every: int) -> void:
	cam.global_position = view[0]
	cam.look_at(view[1], Vector3.UP)
	for i in n:
		for k in every:
			await process_frame
		await _shot("%s_f%02d" % [name, i])

func _shot(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + name + ".png"))

func _walk() -> void:
	WindSystem.set_preset(WindSystem.Preset.CALM, 0.0)
	var p: Player = scene.player
	p.global_position = Vector3(1.5, 0.05, -0.2)
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	scene.camera_rig.yaw = -PI * 0.5
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	Input.action_press("walk")
	for i in 16:
		for k in 8:
			await physics_frame
		cam.global_position = p.global_position + Vector3(0.6, 1.6, -3.4)
		cam.look_at(p.global_position + Vector3(0.4, 0.3, 0), Vector3.UP)
		await _shot("walk_f%02d" % i)
	Input.action_release("move_forward")
	Input.action_release("walk")
	# Recovery: player stops; grass behind should spring back gradually.
	for i in 8:
		for k in 8:
			await physics_frame
		await _shot("walk_recover_f%02d" % i)
	print("NATURE walk end=", p.global_position)
