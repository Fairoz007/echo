extends SceneTree
## DEV ONLY: captures frame sequences of Mara's movement states for visual review.
## LOW GRAPHICS ONLY:
## godot --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 960x540 --path . -s res://dev/movement_sequences.gd
## Output: screenshots/movement/seq_<name>/fNN.png plus a contact sheet seq_<name>_sheet.png.

const OUT := "res://screenshots/movement/"
const FRAMES := 12
var course
var p: Player
var cam: CameraController

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gs = root.get_node_or_null("GraphicsSettings")
	if gs and gs.has_method("apply_quality"):
		gs.apply_quality(0, false) # Ultra Low
	paused = false
	course = (load("res://dev/MovementTestCourse.tscn") as PackedScene).instantiate()
	root.add_child(course)
	for i in 10:
		await physics_frame
	p = course.player
	cam = course.camera_rig
	cam.max_arm_length = 2.4
	cam.camera.h_offset = 0.0
	print("RENDERER ", RenderingServer.get_current_rendering_method(), " driver ", RenderingServer.get_current_rendering_driver_name())
	# Side view: camera yaw 0 looks along -Z, so "move_right" walks Mara along +X across frame.
	await _seq("idle", "flat", Vector3(-30, 0, 0), [], 4)
	await _seq("walk", "flat", Vector3(-30, 0, 0), ["move_right", "walk"], 4)
	await _seq("run", "flat", Vector3(-30, 0, 0), ["move_right"], 3)
	await _seq("sprint", "flat", Vector3(-30, 0, 0), ["move_right", "sprint"], 2)
	await _seq("jump_land", "flat", Vector3(-30, 0, 0), ["move_right", "jump"], 5, true)
	await _seq("crouch", "flat", Vector3(-30, 0, 0), ["move_right", "crouch"], 4)
	await _seq("turn", "flat", Vector3(-30, 0, 0), ["move_right"], 3, false, true)
	await _seq_climb()
	await _seq_swim()
	quit()

func _reset(lane: String, offset: Vector3, yaw: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "walk", "dive"]:
		Input.action_release(a)
	p.global_position = course.lane_start(lane) + offset
	p.velocity = Vector3.ZERO
	p.facing_yaw = -PI * 0.5
	p.current_state = Player.State.IDLE
	cam.yaw = yaw
	cam.pitch = deg_to_rad(-6.0)
	cam.snap_to_target()
	for i in 20:
		await physics_frame

func _grab(dir: String, idx: int, frames: Array) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(dir + "f%02d.png" % idx))
	frames.append(img)
	print("  f%02d state=%s anim=%s speed=%.2f y=%.2f scale=%.2f" % [idx, Player.State.keys()[p.current_state], p.anim_state, p.horizontal_speed, p.global_position.y, p.get_animation_playback_scale()])

func _sheet(name: String, frames: Array) -> void:
	if frames.is_empty():
		return
	var w: int = frames[0].get_width() / 3
	var h: int = frames[0].get_height() * 2 / 3
	var cols := 4
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f: Image = frames[i].duplicate()
		f.convert(Image.FORMAT_RGBA8)
		f = f.get_region(Rect2i((f.get_width() - w) / 2, (f.get_height() - h) / 2, w, h))
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(ProjectSettings.globalize_path(OUT + "seq_%s_sheet.png" % name))

## Holds inputs, lets the gait settle, then grabs FRAMES frames every `step` physics frames.
func _seq(name: String, lane: String, offset: Vector3, inputs: Array, step: int, jump_tap := false, reverse := false) -> void:
	print("SEQ ", name)
	await _reset(lane, offset, 0.0)
	var dir := OUT + "seq_%s/" % name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for a in inputs:
		if a != "jump":
			Input.action_press(a)
	for i in 60:
		await physics_frame
	if jump_tap:
		Input.action_press("jump")
	var frames := []
	for i in FRAMES:
		if reverse and i == 3:
			Input.action_release("move_right")
			Input.action_press("move_left")
		await _grab(dir, i, frames)
		for s in step:
			await physics_frame
	for a in ["move_right", "move_left", "jump", "sprint", "crouch", "walk"]:
		Input.action_release(a)
	_sheet(name, frames)

func _seq_climb() -> void:
	print("SEQ climb")
	await _reset("climb_wall", Vector3(3.2, 0, 0), 0.4)
	var dir := OUT + "seq_climb/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	cam.yaw = 0.0
	Input.action_press("move_right")
	for i in 5:
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_press("move_forward") # climb up (forward = up on a wall)
	var frames := []
	for i in FRAMES:
		await _grab(dir, i, frames)
		for s in 25:
			await physics_frame
	Input.action_release("move_forward")
	_sheet("climb", frames)

func _seq_swim() -> void:
	print("SEQ swim")
	await _reset("pool", Vector3(6, 3.5, -1.5), 0.0)
	var dir := OUT + "seq_swim/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in 120:
		await physics_frame
	var frames := []
	Input.action_press("move_right")
	for i in FRAMES:
		if i == 6:
			Input.action_press("dive")
		if i == 9:
			Input.action_release("dive")
		await _grab(dir, i, frames)
		for s in 10:
			await physics_frame
	Input.action_release("move_right")
	_sheet("swim", frames)
