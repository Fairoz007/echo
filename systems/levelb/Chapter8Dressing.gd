extends Node3D
## Chapter 8 "The Betrayal": inner-sanctum refuge where the survivors regroup, Adrian's
## abandoned transmitter, the Harmonic Key altar (empty cradle) as the landmark, cinematic
## staging marks, and escalating Meridian waves after Elias reveals the betrayal.
## Routes: central nave (primary) and the raised east gallery (secondary).

const KIT := preload("res://systems/levelb/LBKit.gd")
const TERRAIN := preload("res://systems/levelb/LBTerrain.gd")
const ENEMY := "res://scenes/EnemyMercenary.tscn"
const TENT := "res://assets/models/optimized/prop_expedition_tent_LOD0.glb"
const CRATE := "res://assets/models/optimized/prop_meridian_crate_LOD0.glb"
const RADIO := "res://assets/models/optimized/prop_expedition_radio_station_LOD0.glb"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"
const WALL := "res://assets/models/optimized/arch_wall_vaelor_LOD0.glb"
const PORTAL := "res://assets/models/optimized/ruin_arch_portal_LOD0.glb"
const KEY := "res://assets/models/optimized/prop_vaelor_key_LOD0.glb"
const CLIFF := "res://assets/environment/cave/cave_wall_limestone.glb"
const CEIL := "res://assets/environment/cave/cave_ceiling_limestone.glb"
const GALLERY_Y := 3.0

var terrain: TERRAIN
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var level: Node3D
var wave := 0
var alive := 0
var _glow: Array[OmniLight3D] = []
var _t := 0.0

func _init() -> void:
	name = "LevelBDressing"

func build(p_level: Node3D) -> void:
	level = p_level
	rng.seed = 808
	noise.seed = 88
	noise.frequency = 0.04
	var ground := level.get_node_or_null("SanctuaryGround")
	if ground:
		for c in ground.get_children():
			if c is CollisionShape3D:
				c.disabled = true
			elif c is GeometryInstance3D:
				c.visible = false
	terrain = TERRAIN.new()
	terrain.name = "SanctumFloor"
	add_child(terrain)
	terrain.build(Vector2(-45, -70), Vector2(90, 110), 1.0, _height, _mask)
	var m := terrain.material
	m.set_shader_parameter("grass_a", Vector3(0.24, 0.22, 0.19))
	m.set_shader_parameter("grass_b", Vector3(0.3, 0.27, 0.23))
	m.set_shader_parameter("soil_a", Vector3(0.2, 0.18, 0.15))
	m.set_shader_parameter("soil_b", Vector3(0.27, 0.24, 0.2))
	m.set_shader_parameter("litter", Vector3(0.18, 0.16, 0.13))
	m.set_shader_parameter("rock_tint", Vector3(0.45, 0.42, 0.38))
	_shell()
	_refuge()
	_gallery()
	_altar()
	_staging()
	_discoveries()
	_lighting()
	_hero_props()

func _height(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := noise.get_noise_2d(x * 4.0, z * 4.0) * 0.05
	h = maxf(h, smoothstep(17.0, 24.0, absf(x) + n * 3.0) * (12.0 + 5.0 * n))
	h = maxf(h, smoothstep(28.0, 33.0, z) * 12.0)
	h = maxf(h, smoothstep(-52.0, -58.0, z) * 12.0)
	# East gallery: raised shelf x 10..16, z -34..10, ramp down at its south end.
	var gx := 1.0 - smoothstep(3.0, 4.2, absf(x - 13.0))
	if z > -36.0 and z < 12.0:
		var gy := GALLERY_Y
		if z > 4.0:
			gy = lerpf(GALLERY_Y, 0.0, (z - 4.0) / 8.0)
		h = maxf(h, gy * gx)
	# Altar dais.
	var dais := 1.0 - smoothstep(4.0, 5.0, Vector2(x, z + 42.0).length())
	h = maxf(h, dais * 0.6)
	return h

func _mask(x: float, z: float) -> Color:
	var nave := (1.0 - smoothstep(2.5, 4.5, absf(x))) * 0.7
	return Color(nave, 0.0, 0.15, 0.3)

func _shell() -> void:
	var root := Node3D.new()
	root.name = "SanctumShell"
	add_child(root)
	var rock := KIT.rock_material(Color(0.46, 0.44, 0.4), 0.15)
	var carved := KIT.rock_material(Color(0.78, 0.74, 0.68), 0.1)
	for side in [-1.0, 1.0]:
		var z := 28.0
		var i := 0
		while z > -58.0:
			var x: float = side * rng.randf_range(20.0, 23.0)
			var c := KIT.place(root, CLIFF, Vector3(x, terrain.height_at(x, z) - 2.0, z), rng.randf_range(14.0, 20.0), rng.randf_range(-0.5, 0.5), Vector3(1, 1, rng.randf_range(0.9, 1.3)), true, "Rock%s%02d" % ["W" if side < 0 else "E", i])
			if c:
				KIT.override_material(c, rock)
			z -= rng.randf_range(8.0, 11.0)
			i += 1
	# Carved Vaelor wall panels lining the nave (long axis Z in the model).
	for z in [-6.0, -16.0, -26.0]:
		var w := KIT.place(root, WALL, Vector3(-9.5, 0.0, z), 8.0, 0.0, Vector3(1, 2.4, 1), false, "NaveWallW%d" % int(-z))
		if w:
			KIT.override_material(w, carved)
	for k in 10:
		var c := KIT.place(root, CEIL, Vector3(rng.randf_range(-18, 18), rng.randf_range(15.0, 18.0), rng.randf_range(-55, 25)), rng.randf_range(16, 22), rng.randf() * TAU, Vector3.ONE, false, "Ceil%02d" % k)
		if c:
			KIT.override_material(c, rock)
			c.set_meta("collision", "none")
	# Colonnade along the nave.
	for z in [8.0, -2.0, -12.0, -22.0, -32.0]:
		for side in [-1.0, 1.0]:
			if side > 0 and z < 6.0 and z > -36.0:
				continue # gallery side is open
			var p := KIT.place(root, PILLAR, Vector3(side * 7.0, 0, z), 7.5, 0.0, Vector3.ONE, true, "Nave%s%d" % ["W" if side < 0 else "E", int(z)])
			if p:
				KIT.override_material(p, carved)

func _refuge() -> void:
	var root := Node3D.new()
	root.name = "SurvivorRefuge"
	add_child(root)
	KIT.place(root, TENT, Vector3(-4.5, 0, 4.5), 2.4, 0.6, Vector3.ONE, true, "RefugeTent")
	KIT.place(root, CRATE, Vector3(3.2, 0, 3.0), 0.8, 0.4, Vector3.ONE, true, "SupplyCrateA")
	KIT.place(root, CRATE, Vector3(3.8, 0, 1.6), 0.7, -0.3, Vector3.ONE, true, "SupplyCrateB")
	# Bedroll where Elias was laid down + medical kit.
	var roll := BoxMesh.new()
	roll.size = Vector3(0.9, 0.12, 2.0)
	KIT.mesh(root, roll, Transform3D(Basis(Vector3.UP, 0.2), Vector3(-1.4, 0.06, 0.6)), KIT.std_mat(Color(0.25, 0.3, 0.22), 0.95), "Bedroll").set_meta("collision", "none")
	var kit_box := BoxMesh.new()
	kit_box.size = Vector3(0.45, 0.22, 0.3)
	KIT.mesh(root, kit_box, Transform3D(Basis(Vector3.UP, 0.7), Vector3(-0.6, 0.11, -0.6)), KIT.std_mat(Color(0.8, 0.1, 0.1), 0.6), "MedKit").set_meta("collision", "none")
	# Lantern on the crate.
	var lamp := SphereMesh.new()
	lamp.radius = 0.1
	lamp.height = 0.2
	KIT.mesh(root, lamp, Transform3D(Basis(), Vector3(3.2, 0.95, 3.0)), KIT.std_mat(Color(1, 0.8, 0.5), 0.3, 0.0, Color(1, 0.75, 0.4), 4.0)).set_meta("collision", "none")
	var l := KIT.omni(root, Vector3(3.2, 1.2, 3.0), Color(1.0, 0.72, 0.42), 1.8, 10.0, true)
	_glow.append(l)
	# Survivors: Nadiya tending Elias, Tomas on watch facing the passage.
	KIT.npc(root, "NadiyaRefuge", "res://assets/characters/nadiya/source/CHR_Nadiya_Rig.glb", Vector3(-1.6, 0, -0.9), 0.4, 1.67)
	var tomas := KIT.npc(root, "TomasRefuge", "res://assets/characters/tomas/source/CHR_Tomas_Rig.glb", Vector3(4.6, 0, -3.5), PI, 1.84, "[E] Talk to Tomas")
	var area := tomas.get_node("Interactable3D") as Area3D
	area.interacted.connect(func(_p): AudioManager.play_story_line("Tomas", "Adrian walked out with the case an hour ago. Said he was checking the east gallery.", 4.5))

func _gallery() -> void:
	var root := Node3D.new()
	root.name = "EastGallery"
	add_child(root)
	var stone := KIT.rock_material(Color(0.58, 0.56, 0.52), 0.1)
	# Balustrade blocks along the gallery lip = cover for the secondary route.
	var block := BoxMesh.new()
	block.size = Vector3(0.6, 1.0, 2.2)
	for z in [2.0, -4.0, -10.0, -16.0, -22.0, -28.0]:
		var p := Vector3(9.4, GALLERY_Y + 0.5, z)
		KIT.mesh(root, block, Transform3D(Basis(), p), stone, "Balustrade").set_meta("collision", "none")
		KIT.box_body(root, p, Vector3(0.6, 1.0, 2.2), 0.0, "BalustradeBody")
	# Gallery drops back down to the passage via a ramp at its north end.
	var ramp := BoxMesh.new()
	var len := 8.0
	ramp.size = Vector3(3.0, 0.3, sqrt(len * len + GALLERY_Y * GALLERY_Y))
	var basis := Basis(Vector3.RIGHT, -atan2(GALLERY_Y, len))
	var c := Vector3(13.0, GALLERY_Y * 0.5 - 0.1, -36.0 - len * 0.5)
	KIT.mesh(root, ramp, Transform3D(basis, c), stone, "GalleryRamp").set_meta("collision", "none")
	var body := StaticBody3D.new()
	body.name = "GalleryRampBody"
	body.collision_layer = 3
	root.add_child(body)
	body.global_transform = Transform3D(basis, c)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ramp.size
	cs.shape = bs
	body.add_child(cs)

func _altar() -> void:
	var root := Node3D.new()
	root.name = "HarmonicAltar"
	add_child(root)
	var carved := KIT.rock_material(Color(0.6, 0.58, 0.55), 0.05)
	var dais := CylinderMesh.new()
	dais.top_radius = 1.2
	dais.bottom_radius = 1.5
	dais.height = 1.1
	KIT.mesh(root, dais, Transform3D(Basis(), Vector3(0, 1.15, -42)), carved, "AltarPedestal")
	KIT.box_body(root, Vector3(0, 1.15, -42), Vector3(2.4, 1.1, 2.4), 0.0, "AltarBody")
	var cradle := TorusMesh.new()
	cradle.inner_radius = 0.35
	cradle.outer_radius = 0.55
	KIT.mesh(root, cradle, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 2.2, -42)), KIT.std_mat(Color(0.2, 0.45, 0.5), 0.3, 0.2, Color(0.3, 0.9, 1.0), 1.5), "EmptyCradle").set_meta("collision", "none")
	var glow := KIT.omni(root, Vector3(0, 2.6, -42), Color(0.35, 0.85, 1.0), 2.2, 14.0)
	_glow.append(glow)
	var portal := KIT.place(root, PORTAL, Vector3(0, 0.55, -48.5), 10.0, PI / 2, Vector3.ONE, true, "SanctumArch")
	if portal:
		KIT.override_material(portal, carved)
	for a in 6:
		var ang := TAU * a / 6.0 + 0.3
		var p := Vector3(cos(ang) * 7.0, 0, -42 + sin(ang) * 7.0)
		if absf(p.x) < 3.0 and p.z > -42:
			continue
		KIT.place(root, PILLAR, p, 5.5, -ang, Vector3.ONE, true, "RingPillar%d" % a)

func _staging() -> void:
	# Cinematic staging marks (group "cinematic_mark"; meta "role") for the betrayal scene.
	var root := Node3D.new()
	root.name = "CinematicMarks"
	add_child(root)
	var marks := {
		"Mara_EliasTalk": [Vector3(0.0, 0, 1.6), PI],
		"Elias_Injured": [Vector3(-1.4, 0, 0.6), 0.0],
		"Nadiya_Tending": [Vector3(-1.6, 0, -0.9), 0.4],
		"Tomas_Watch": [Vector3(4.6, 0, -3.5), PI],
		"Mara_Confront": [Vector3(0.0, 0, -28.0), PI],
		"Adrian_Radio": [Vector3(1.5, 0, -30.0), 0.0],
		"Drake_Altar": [Vector3(0.0, 0.6, -40.0), 0.0],
		"Camera_Wide": [Vector3(8.0, 4.0, -18.0), 2.6],
		"Camera_Close": [Vector3(1.5, 1.6, -26.0), 2.9],
	}
	for key in marks:
		var mk := Marker3D.new()
		mk.name = key
		mk.add_to_group("cinematic_mark")
		mk.set_meta("role", key.get_slice("_", 0))
		root.add_child(mk)
		mk.global_transform = Transform3D(Basis(Vector3.UP, marks[key][1]), marks[key][0])

func _discoveries() -> void:
	var d := Node3D.new()
	d.name = "Discoveries"
	add_child(d)
	# Adrian's transmitter on the east gallery.
	KIT.place(d, RADIO, Vector3(14.0, GALLERY_Y, -20.0), 1.1, -PI / 2, Vector3.ONE, true, "AdrianTransmitter")
	KIT.collectible(d, "c08_transmission_log", "document", "Transmission Log (A. Kell)",
		"04:10 COORDS SENT - portal, ridge camp.\n06:55 COORDS SENT - aqueduct, temple drain.\n09:30 'Asset confirms Key location. Extraction window 2h.' - MERIDIAN/DRAKE\n\nThe last entry is Adrian's own handwriting: 'Not like this.'",
		Vector3(14.6, GALLERY_Y + 0.02, -18.6), -0.3)
	KIT.collectible(d, "c08_elias_journal", "journal", "Elias's Field Journal",
		"\"If the Key can be lifted, the Vault can be opened. If the Vault can be opened, it can be sold. I keep writing that sentence and crossing it out.\"",
		Vector3(-6.0, 0.02, 3.4), 1.0)

func _lighting() -> void:
	var env_node := level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.3, 0.31, 0.34)
		env.ambient_light_energy = 1.6
		env.fog_light_color = Color(0.09, 0.1, 0.12)
		env.fog_density = 0.012
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env_node.environment = env
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.7, 0.8, 0.95)
	key.light_energy = 0.7
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	add_child(key)
	key.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-25), 0)
	for p in [Vector3(-7, 5, -12), Vector3(-7, 5, -32), Vector3(13, GALLERY_Y + 2.5, -10)]:
		KIT.omni(self, p, Color(1.0, 0.62, 0.32), 1.2, 10.0)

func _process(delta: float) -> void:
	_t += delta
	for g in _glow:
		g.light_energy = 1.9 + sin(_t * 1.3) * 0.35

# ------------------------------------------------------------------ combat escalation

## Called by Chapter8.gd once Elias reveals the betrayal.
func start_escalation() -> void:
	if wave > 0:
		return
	MissionManager.register_objective("obj_c08_hold_refuge", "Meridian is breaching the sanctum. Hold them off or push through to Adrian")
	await get_tree().create_timer(6.0).timeout
	_spawn_wave([Vector3(-12, 0, -24), Vector3(12, GALLERY_Y, -28)])

func _spawn_wave(points: Array) -> void:
	wave += 1
	var enemies := level.get_node_or_null("Enemies")
	if enemies == null:
		enemies = Node3D.new()
		enemies.name = "Enemies"
		level.add_child(enemies)
	for i in points.size():
		var e := (load(ENEMY) as PackedScene).instantiate()
		e.name = "Wave%dMerc%d" % [wave, i]
		enemies.add_child(e)
		e.global_position = points[i]
		e.rotation.y = 0.0
		if "sight_range" in e:
			e.sight_range = 16.0 + wave * 3.0
		alive += 1
		preload("res://systems/levelb/LBMeridianGear.gd").equip(e, ["rifleman", "heavy", "radio"][(i + wave) % 3])
		if e.has_signal("enemy_died"):
			e.enemy_died.connect(_on_enemy_died)
	if level.get_node_or_null("CampaignDialogue") and AudioManager:
		AudioManager.play_story_line("Meridian", "Contact in the sanctum! Push in!" if wave == 1 else "Second team, flank the gallery!", 3.0)

func _on_enemy_died(_e: Node) -> void:
	alive -= 1
	if alive > 0:
		return
	if wave == 1:
		await get_tree().create_timer(3.0).timeout
		_spawn_wave([Vector3(-4, 0.6, -45), Vector3(4, 0.6, -45), Vector3(13, GALLERY_Y, -33)])
	elif wave == 2:
		MissionManager.complete_objective("obj_c08_hold_refuge")

func hook_audio(sc: Node) -> void:
	if sc == null:
		return
	sc.add_emitter("res://audio/ambience/heart_vault/AMB_HEART_VAULT_RESONANCE.wav", Vector3(0, 2, -42), -6.0, 30.0)
	sc.add_emitter("res://audio/ambience/ruins/AMB_RUIN_DRAFT.wav", Vector3(0, 6, -10), -2.0, 40.0)
	sc.add_reverb_zone(Vector3(0, 6, -15), Vector3(40, 18, 80), "ruin")
	sc.add_reverb_zone(Vector3(0, 4, -42), Vector3(16, 10, 14), "vault")

# ------------------------------------------------------------------ phase-2 hero assets
const H8 := "res://assets/models/hero/ch8/lod/"
const CAVE8 := "res://assets/models/cave/lod/"

func _hero_props() -> void:
	var root := Node3D.new()
	root.name = "SanctumHeroProps"
	add_child(root)
	if ResourceLoader.exists(H8 + "ch8_harmonic_key_altar_LOD0.glb"):
		var ped := get_node_or_null("HarmonicAltar/AltarPedestal")
		if ped:
			ped.visible = false
		var altar := KIT.place(root, H8 + "ch8_harmonic_key_altar_LOD0.glb", Vector3(0, 0.6, -42.0), 3.6, 0.0, Vector3.ONE, false, "HeroKeyAltar")
		if altar:
			altar.set_meta("collision", "none") # AltarBody box already blocks
	var lab := KIT.place(root, H8 + "ch8_syndicate_field_lab_LOD0.glb", Vector3(14.2, GALLERY_Y, -26.0), 3.4, -PI / 2, Vector3.ONE, false, "SyndicateFieldLab")
	if lab:
		lab.set_meta("collision", "box")
	var stair := KIT.place(root, H8 + "ch8_grand_collapsed_stairway_LOD0.glb", Vector3(-13.0, 0, -40.0), 10.0, PI / 2, Vector3.ONE, false, "CollapsedStair")
	if stair:
		stair.set_meta("collision", "trimesh")
	for k in 6:
		var a := TAU * k / 6.0
		var p := Vector3(cos(a) * 10.0, 0, -42.0 + sin(a) * 6.0)
		if absf(p.x) < 4.0 and p.z > -42.0:
			continue
		var c := KIT.place(root, CAVE8 + ("cav_resonant_crystal_cluster_a_LOD0.glb" if k % 2 == 0 else "cav_resonant_crystal_vein_b_LOD0.glb"), Vector3(p.x, terrain.height_at(p.x, p.z) - 0.1, p.z), rng.randf_range(1.6, 2.8), rng.randf() * TAU, Vector3.ONE, true, "Crystal%d" % k)
	for k in 8:
		var s := KIT.place(root, CAVE8 + "cav_stalactite_ceiling_cluster_LOD0.glb", Vector3(rng.randf_range(-16, 16), 12.5, rng.randf_range(-50, 20)), rng.randf_range(5.0, 7.0), rng.randf() * TAU, Vector3.ONE, false, "Stalactites%d" % k)
		if s:
			s.set_meta("collision", "none")