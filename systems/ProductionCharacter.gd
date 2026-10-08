extends Node3D
const RAGDOLL := preload("res://scripts/Ragdoll.gd")
## Calibrated Tripo rig for NPCs and Meridian enemies.
## - Prefers *_Animated.glb (retargeted idle/walk/... clips) over *_Rig.glb.
## - When parented to an EnemyBase it drives animation from the AI state (walk/run/shoot,
##   crouched cover-fire sub-range of `shoot`, procedural reload arm offset, ragdoll death)
##   and attaches Meridian gear variants to Head / R_Hand / Spine02.
@export_file("*.glb") var model_path := ""
@export var character_height := 1.8
@export var animated_idle := false
## "", "none", "rifleman", "heavy" or "radio". Empty on an enemy = picked from node name.
@export var gear_variant := ""
## Seconds into `shoot` where the crouched segment lives (TRIPO_DELIVERY_REPORT phase 2).
@export var cover_clip_range := Vector2(2.0, 5.0)
@export var standing_shoot_range := Vector2(0.0, 1.8)
@export var reload_duration := 1.6
@export var shots_per_magazine := 6

const GEAR := {
	"helmet": ["res://assets/models/meridian/lod/mer_tactical_helmet_nvg_LOD0.glb", "Head", 0.30],
	"rifle": ["res://assets/models/meridian/lod/mer_assault_rifle_LOD0.glb", "R_Hand", 0.85],
	"vest": ["res://assets/models/meridian/lod/mer_heavy_armor_vest_LOD0.glb", "Spine02", 0.62],
	"radio": ["res://assets/models/meridian/lod/mer_radio_backpack_LOD0.glb", "Spine02", 0.55],
}
const VARIANTS := {
	"rifleman": ["helmet", "rifle"],
	"heavy": ["helmet", "rifle", "vest"],
	"radio": ["rifle", "radio"],
}
const TINTS := {"rifleman": Color(1, 1, 1), "heavy": Color(0.62, 0.64, 0.6), "radio": Color(0.85, 0.8, 0.68)}

var skeleton: Skeleton3D
var visual: Node3D
var phase := 0.0
var idle_player: AnimationPlayer
var enemy: Node = null
var ragdoll: PhysicalBoneSimulator3D
var _clip_speed := {}
var _anim_range := Vector2(-1, -1)
var _reload_timer := 0.0
var _shots := 0
var _last_cooldown := 0.0
var _last_pos := Vector3.ZERO

func _ready() -> void:
	var effective_path := model_path
	var idle_candidate := model_path.replace("_Rig.glb", "_Idle_Legacy.glb")
	var animated_candidate := model_path.replace("_Rig.glb", "_Animated.glb")
	if animated_candidate != model_path and ResourceLoader.exists(animated_candidate):
		effective_path = animated_candidate
		animated_idle = true
	elif ResourceLoader.exists(idle_candidate):
		effective_path = idle_candidate
		animated_idle = true
	if model_path.ends_with("_Animated.glb"):
		animated_idle = true
	var model := load(effective_path) as PackedScene
	if not model:
		push_error("Character model unavailable: " + model_path)
		return
	visual = model.instantiate() as Node3D
	add_child(visual)
	for stray in visual.find_children("Icosphere*", "MeshInstance3D", true, false):
		stray.visible = false
	var maximum := 0.0
	var minimum := 1000.0
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var box: AABB = mesh.get_aabb()
		maximum = maxf(maximum, box.end.y)
		minimum = minf(minimum, box.position.y)
	var factor := character_height / maxf(maximum - minimum, 0.1)
	visual.scale = Vector3.ONE * factor
	visual.position.y = -minimum * factor
	visual.rotation.y = PI / 2.0
	skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		for candidate in visual.find_children("*", "Skeleton3D", true, false):
			skeleton = candidate
			break
	idle_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var parent := get_parent()
	if parent and parent is EnemyBase:
		enemy = parent
		_last_pos = parent.global_position
	if idle_player:
		_prepare_clips()
	if animated_idle and idle_player and _play("idle"):
		pass
	elif skeleton:
		_relax_arm("L_Upperarm", "L_Forearm")
		_relax_arm("R_Upperarm", "R_Forearm")
	if enemy:
		_attach_gear()
		if idle_player:
			idle_player.mixer_applied.connect(_apply_reload_pose)

# ------------------------------------------------------------------ clips

func _prepare_clips() -> void:
	for clip in idle_player.get_animation_list():
		var anim := idle_player.get_animation(clip)
		if clip in ["idle", "walk", "run", "shoot"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		# Strip Hip/Root ground travel (movement belongs to the CharacterBody), keep bob.
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var path := String(anim.track_get_path(track))
			if not (path.ends_with(":Hip") or path.ends_with(":Root")):
				continue
			var n := anim.track_get_key_count(track)
			if n < 2:
				continue
			var first: Vector3 = anim.track_get_key_value(track, 0)
			var last: Vector3 = anim.track_get_key_value(track, n - 1)
			var travel := Vector2(last.x - first.x, last.y - first.y).length()
			if travel > 0.05 and anim.length > 0.0:
				_clip_speed[clip] = travel * visual.scale.x / anim.length
			for k in n:
				var v: Vector3 = anim.track_get_key_value(track, k)
				v.x = 0.0
				v.y = 0.0
				anim.track_set_key_value(track, k, v)

func _play(clip: String, speed := 1.0, clip_range := Vector2(-1, -1)) -> bool:
	if not idle_player or not idle_player.has_animation(clip):
		return false
	if idle_player.current_animation != clip or _anim_range != clip_range:
		idle_player.play(clip, 0.25)
		if clip_range.x >= 0.0:
			idle_player.seek(clip_range.x, true)
	_anim_range = clip_range
	idle_player.speed_scale = speed
	return true

# ------------------------------------------------------------------ gear

func _attach_gear() -> void:
	if not skeleton:
		return
	var variant := gear_variant
	if variant == "":
		variant = VARIANTS.keys()[abs(hash(String(enemy.name))) % VARIANTS.size()]
	if not VARIANTS.has(variant):
		return
	var world_scale := visual.scale.x
	for item in VARIANTS[variant]:
		var spec: Array = GEAR[item]
		var bone := skeleton.find_bone(spec[1])
		if bone < 0 or not ResourceLoader.exists(spec[0]):
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "Gear_" + item
		attachment.bone_name = spec[1]
		skeleton.add_child(attachment)
		var gear: Node3D = (load(spec[0]) as PackedScene).instantiate()
		var holder := Node3D.new()
		attachment.add_child(holder)
		holder.add_child(gear)
		var bounds := AABB()
		var found := false
		for mesh in gear.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.transform * mesh.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
		if not found:
			continue
		var s: float = spec[2] / world_scale / maxf(bounds.size[bounds.size.max_axis_index()], 0.001)
		gear.scale = Vector3.ONE * s
		gear.position = -bounds.get_center() * s
		# Desired placement in skeleton space (model faces +X, up +Y), converted into the
		# bone's rest frame so gear does not inherit arbitrary bone axes.
		var rest := skeleton.get_bone_global_rest(bone)
		var offset := Vector3.ZERO
		match item:
			"helmet": offset = Vector3(0.0, 0.10, 0.0)
			"rifle": offset = Vector3(0.25, 0.0, 0.0)
			"vest": offset = Vector3(0.0, -0.05, 0.0)
			"radio": offset = Vector3(-0.2, -0.05, 0.0)
		var desired := Transform3D(Basis.IDENTITY, rest.origin + offset / world_scale)
		holder.transform = rest.affine_inverse() * desired
		if TINTS.has(variant):
			for mesh: MeshInstance3D in gear.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.get_surface_override_material_count():
					var source := mesh.get_active_material(surface) as BaseMaterial3D
					if source:
						var tinted := source.duplicate() as BaseMaterial3D
						tinted.albedo_color = source.albedo_color * TINTS[variant]
						mesh.set_surface_override_material(surface, tinted)
	set_meta("gear_variant", variant)

# ------------------------------------------------------------------ enemy driver

func play_reload(duration := -1.0) -> void:
	_reload_timer = reload_duration if duration < 0.0 else duration

func is_reloading() -> bool:
	return _reload_timer > 0.0

func _physics_process(delta: float) -> void:
	if not enemy or not is_instance_valid(enemy) or not idle_player:
		return
	var state: int = enemy.current_state
	if state == EnemyBase.AIState.DEAD:
		_die()
		return
	var flat: Vector3 = enemy.global_position - _last_pos
	flat.y = 0.0
	var speed: float = flat.length() / maxf(delta, 0.0001)
	_last_pos = enemy.global_position
	_reload_timer = maxf(0.0, _reload_timer - delta)
	# Count shots from the AI's cooldown resetting; reload after a magazine.
	var cooldown: float = enemy.attack_cooldown
	if cooldown > _last_cooldown + 0.1:
		_shots += 1
		if _shots >= shots_per_magazine:
			_shots = 0
			play_reload()
	_last_cooldown = cooldown
	match state:
		EnemyBase.AIState.TAKE_COVER:
			_play("shoot", 1.0, cover_clip_range)
		EnemyBase.AIState.COMBAT:
			if speed > 0.5:
				_play("run", clampf(speed / _clip_speed.get("run", 4.0), 0.5, 2.5))
			else:
				_play("shoot", 1.0, standing_shoot_range)
		_:
			if speed > 0.2:
				_play("walk", clampf(speed / _clip_speed.get("walk", 1.2), 0.5, 2.5))
			else:
				_play("idle")
	# Keep looping inside a sub-range of a long clip.
	if _anim_range.x >= 0.0 and idle_player.current_animation_position > _anim_range.y:
		idle_player.seek(_anim_range.x, true)

## Procedural reload: right arm folds to the chest, left hand meets it (no Tripo clip).
func _apply_reload_pose() -> void:
	if _reload_timer <= 0.0 or not skeleton:
		return
	var t := _reload_timer / reload_duration
	var k := sin(clampf(1.0 - t, 0.0, 1.0) * PI) # ease in, hold, ease out
	var axis := Vector3(0, 0, 1)
	for spec in [["R_Upperarm", -0.6], ["R_Forearm", -1.1], ["L_Upperarm", -0.4], ["L_Forearm", -0.9]]:
		var bone := skeleton.find_bone(spec[0])
		if bone < 0:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(axis, spec[1] * k) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)

func _die() -> void:
	if ragdoll:
		return
	if idle_player:
		idle_player.stop()
	# EnemyBase.die() tweens the body's rotation; detach so the ragdoll is not rotated twice.
	var keep := global_transform
	top_level = true
	global_transform = keep
	ragdoll = RAGDOLL.start(skeleton, -global_basis.z * 30.0, 2)

# ------------------------------------------------------------------ legacy NPC idle

func _relax_arm(arm_name: String, child_name: String) -> void:
	var index := skeleton.find_bone(arm_name)
	var child := skeleton.find_bone(child_name)
	if index < 0 or child < 0:
		return
	var rest := skeleton.get_bone_global_rest(index)
	var child_rest := skeleton.get_bone_global_rest(child)
	var direction := (child_rest.origin - rest.origin).normalized()
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	var target := (Vector3.DOWN + horizontal * 0.14).normalized()
	var corrected := Basis(Quaternion(direction, target)) * rest.basis
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	var local_basis := parent_basis.inverse() * corrected
	var pose_basis := skeleton.get_bone_rest(index).basis.inverse() * local_basis
	skeleton.set_bone_pose_rotation(index, pose_basis.get_rotation_quaternion())

func _process(delta: float) -> void:
	phase += delta
	if visual and not animated_idle:
		visual.position.y += (sin(phase * 1.5) - sin((phase - delta) * 1.5)) * 0.003
