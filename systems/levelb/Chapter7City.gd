extends Node3D
## Chapter 7, City of Echoes: six connected districts inside the city cavern.
##
## Main path: read the plaza mural, recover three Vaelor seals (Scholar's Quarter
## investigation, Echo Gardens resonance hymn, Temple District brazier trial), cut the
## Meridian gate fuse at the Forward Camp, then cross the Royal Causeway.
## Optional: Collapsed Aqueduct traversal + sluice, and three distinct tombs
## (Hall of Weights: counterweights, Sunken Archive: water level, Resonant Chamber:
## linked resonator alignment). All state persists through SaveManager (persistent_world).
##
## Layout (cavern ~45 m wide, spawn at z=35, travel -Z):
##   Hall of Weights (-15,34)   spawn (0,35)   Resonant Chamber (15,38)
##   Scholar's Quarter (-13,20)                Echo Gardens (14,24)
##                     Central Plaza (0,0)     Sunken Archive (16,10)
##   Temple District (-13,-12)  Meridian Camp (0,-17)  Collapsed Aqueduct (16,-4..-20)
##   ---------------- Causeway Gate (z -25.5) ---------------- Royal Causeway (z -27..-45)

const KIT := preload("res://systems/levelb/LBKit.gd")
const PH := "res://assets/polyhaven/models/"
const PILLAR := "res://assets/models/optimized/ruin_pillar_vaelor_LOD0.glb"
const ENEMY := preload("res://scenes/EnemyMercenary.tscn")
const ROCK_ALBEDO := "res://assets/textures/polyhaven/rock_wall_08_diff_1k.jpg"
const ROCK_NORMAL := "res://assets/textures/polyhaven/rock_wall_08_nor_gl_1k.jpg"
const ROCK_ROUGH := "res://assets/textures/polyhaven/rock_wall_08_rough_1k.jpg"

## Hymn order taught by the Scholar's Quarter tablets.
const HYMN := ["mid", "low", "high"]
const BRAZIER_TIME := 30.0

signal gate_opened

var level: Node3D
var stone: StandardMaterial3D
var bronze: StandardMaterial3D
var glow: StandardMaterial3D

# --- persistent state -------------------------------------------------------------
var seals := {"scholar": false, "garden": false, "temple": false}
var fuse_cut := false
var gate_open := false
var sluice_open := false
var garden_progress: Array[String] = []
var garden_fails := 0
var weights := [0, 0, 0, 0] # 0 pedestal, 1 left pan, 2 right pan
var weights_solved := false
var water_level := 0
var archive_solved := false
var resonators := [0, 0, 0, 0] # quarter turns away from facing the crystal
var chamber_solved := false

# --- runtime ----------------------------------------------------------------------
var scholar_tablets: Array[Node] = []
var garden_stones := {}
var braziers: Array[Dictionary] = []
var flames: Array[MeshInstance3D] = []
var temple_door: Node3D
var temple_altar: Area3D
var gate_bar: Node3D
var camp_enemies: Array[Node] = []
var pans: Array[Node3D] = []
var weight_nodes: Array[Node3D] = []
var weights_door: Node3D
var archive_water: Node3D
var archive_crate: Node3D
var resonator_nodes: Array[Node3D] = []
var chamber_crystal: OmniLight3D
var aqueduct_gate: Node3D

func _init() -> void:
	name = "CityOfEchoes"

func build(p_level: Node3D) -> void:
	level = p_level
	add_to_group("persistent_world")
	_materials()
	_plaza()
	_scholars_quarter()
	_echo_gardens()
	_temple_district()
	_aqueduct()
	_meridian_camp()
	_causeway_gate()
	_hall_of_weights()
	_sunken_archive()
	_resonant_chamber()
	_streets()
	for l in [[Vector3(0, 7, 2), 3.0, 26.0], [Vector3(-14, 6, 20), 2.2, 18.0], [Vector3(14, 6, 24), 2.2, 18.0],
			[Vector3(-13, 7, -12), 2.4, 20.0], [Vector3(14, 7, -12), 2.0, 18.0], [Vector3(0, 6, -18), 2.0, 16.0]]:
		KIT.omni(self, l[0], Color(0.62, 0.82, 0.95), l[1], l[2])
	# Keep scatter dressing and relic shards off roofs, walls and plinths.
	for b in find_children("*", "StaticBody3D", true, false):
		b.set_meta("no_dressing", true)

# ==================================================================================
# Shared helpers
# ==================================================================================
func _materials() -> void:
	stone = StandardMaterial3D.new()
	stone.albedo_texture = load(ROCK_ALBEDO)
	stone.albedo_color = Color(0.74, 0.71, 0.64)
	stone.normal_enabled = true
	stone.normal_texture = load(ROCK_NORMAL)
	stone.roughness_texture = load(ROCK_ROUGH)
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.35
	bronze = KIT.std_mat(Color(0.45, 0.32, 0.16), 0.4, 0.85)
	glow = KIT.std_mat(Color(0.2, 0.6, 0.65), 0.3, 0.0, Color(0.3, 0.85, 0.9), 2.2)

func _block(parent: Node, center: Vector3, size: Vector3, yaw := 0.0, mat: Material = null, node_name := "Block") -> StaticBody3D:
	var body := KIT.box_body(parent, center, size, yaw, node_name)
	body.set_meta("collision", "none")
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat if mat else stone
	body.add_child(mi)
	return body

func _ph(parent: Node, id: String, at: Vector3, height: float, yaw := 0.0, fit := true) -> Node3D:
	var n := KIT.place(parent, PH + id + "/" + id + ".gltf", at, height, yaw, Vector3.ONE, fit, id)
	if n:
		n.set_meta("collision", "none")
	return n

func _pillar(parent: Node, at: Vector3, height: float) -> void:
	# The kit pillar is a squat block at height-fit; slim it into a column.
	var p := KIT.place(parent, PILLAR, at, height, 0.0, Vector3(0.45, 1.0, 0.45), true, "Pillar")
	if p:
		p.set_meta("collision", "none")
		KIT.box_body(parent, at + Vector3(0, height * 0.5, 0), Vector3(0.8, height, 0.8), 0.0, "PillarBody")

func _interact(parent: Node3D, pos: Vector3, prompt: String, cb: Callable, size := Vector3(1.8, 2.0, 1.8), holder_name := "") -> Area3D:
	var holder := Node3D.new()
	if holder_name != "":
		holder.name = holder_name
	parent.add_child(holder)
	holder.global_position = pos
	var a := KIT.interaction(holder, Vector3(0, 0.9, 0), size, prompt)
	a.interacted.connect(func(_p): cb.call())
	return a

func _say(who: String, line: String, seconds := 4.0) -> void:
	print("[CITY] ", who, ": ", line)
	AudioManager.play_story_line(who, line, seconds)

func _brazier_visual(parent: Node3D, pos: Vector3, lit: bool) -> Dictionary:
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.55
	bowl.bottom_radius = 0.3
	bowl.height = 0.5
	KIT.mesh(parent, bowl, Transform3D(Basis(), pos + Vector3(0, 1.15, 0)), bronze)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.12
	stem.bottom_radius = 0.22
	stem.height = 0.95
	KIT.mesh(parent, stem, Transform3D(Basis(), pos + Vector3(0, 0.47, 0)), bronze)
	KIT.box_body(parent, pos + Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 0.9), 0.0, "BrazierBody")
	var flame := CylinderMesh.new()
	flame.top_radius = 0.02
	flame.bottom_radius = 0.24
	flame.height = 0.75
	var fmat := KIT.std_mat(Color(1.0, 0.55, 0.15), 0.9, 0.0, Color(1.0, 0.5, 0.12), 5.0)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color.a = 0.85
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fm := KIT.mesh(parent, flame, Transform3D(Basis(), pos + Vector3(0, 1.75, 0)), fmat)
	flames.append(fm)
	fm.set_meta("collision", "none")
	var light := KIT.omni(parent, pos + Vector3(0, 2.0, 0), Color(1.0, 0.6, 0.3), 2.2, 9.0)
	fm.visible = lit
	light.visible = lit
	return {"flame": fm, "light": light, "lit_at": -1000.0, "pos": pos}

# ==================================================================================
# Central Plaza: navigation hub, paved circle, braziers, colonnade around the mural
# ==================================================================================
func _plaza() -> void:
	var root := Node3D.new()
	root.name = "PlazaDistrict"
	add_child(root)
	# Paving: a low stone disc so the plaza reads as built ground, with four radial avenues.
	var paving := CylinderMesh.new()
	paving.top_radius = 12.0
	paving.bottom_radius = 12.2
	paving.height = 0.12
	KIT.mesh(root, paving, Transform3D(Basis(), Vector3(0, 0.06, 0)), stone, "PlazaPaving").set_meta("collision", "none")
	for a in 8:
		var ang := (a + 0.5) * TAU / 8.0 # offset so the four avenues stay clear
		_pillar(root, Vector3(cos(ang) * 13.5, 0, sin(ang) * 13.5), 5.5)
	for p in [Vector3(-4.5, 0, -5.5), Vector3(4.5, 0, -5.5)]:
		var b := _brazier_visual(root, p, true)
		b["flame"].visible = true
	# Wayfinding steles: each faces its district with a carved glyph colour.
	var steles := [[Vector3(-7, 0, 9), "Scholar's Quarter", Color(0.8, 0.7, 0.4)], [Vector3(7, 0, 9), "Echo Gardens", Color(0.4, 0.8, 0.5)],
		[Vector3(-8, 0, -9), "Temple District", Color(0.9, 0.5, 0.3)], [Vector3(8, 0, -9), "Collapsed Aqueduct", Color(0.4, 0.7, 0.9)]]
	for s in steles:
		_block(root, s[0] + Vector3(0, 1.1, 0), Vector3(0.6, 2.2, 0.3), atan2(-s[0].x, -s[0].z), stone, "Stele")
		var g := BoxMesh.new()
		g.size = Vector3(0.35, 0.35, 0.05)
		KIT.mesh(root, g, Transform3D(Basis(Vector3.UP, atan2(-s[0].x, -s[0].z)), s[0] + Vector3(0, 1.7, 0) + (Vector3(-s[0].x, 0, -s[0].z).normalized() * 0.17)),
			KIT.std_mat(s[2], 0.5, 0.0, s[2], 1.5)).set_meta("collision", "none")

# ==================================================================================
# Scholar's Quarter: archive alcoves, three clue tablets, archivist's lectern -> seal
# ==================================================================================
func _scholars_quarter() -> void:
	var root := Node3D.new()
	root.name = "ScholarsQuarter"
	add_child(root)
	# Archive stacks: three roofless alcoves of shelving walls around a reading court.
	for alcove in [[Vector3(-18, 0, 25), 0.0], [Vector3(-9, 0, 27), 0.0], [Vector3(-19, 0, 14), -PI * 0.5]]:
		var c: Vector3 = alcove[0]
		var yaw: float = alcove[1]
		var basis := Basis(Vector3.UP, yaw)
		_block(root, c + basis * Vector3(0, 1.4, 1.6), Vector3(4.2, 2.8, 0.5), yaw, stone, "ArchiveWall")
		_block(root, c + basis * Vector3(-2.0, 1.4, 0.2), Vector3(0.5, 2.8, 3.2), yaw, stone, "ArchiveWall")
		_block(root, c + basis * Vector3(2.0, 1.4, 0.2), Vector3(0.5, 2.8, 3.2), yaw, stone, "ArchiveWall")
		for shelf in 3:
			_block(root, c + basis * Vector3(0, 0.6 + shelf * 0.8, 1.2), Vector3(3.4, 0.08, 0.5), yaw, bronze, "Shelf")
	var clues := [
		["c07_scholar_1", "Archive Tablet: The Hymn I", "Every hymn of opening begins with the voice of the middle, so that the stone is neither startled nor lulled.", Vector3(-18, 0, 24.2)],
		["c07_scholar_2", "Archive Tablet: The Hymn II", "The deep voice never opens the hymn. It answers the first voice, as the mountain answers the city.", Vector3(-9, 0, 26.2)],
		["c07_scholar_3", "Archive Tablet: The Hymn III", "The bright voice is always last. Sing it early and the garden stones will fall silent and wait to be begun again.", Vector3(-18.2, 0, 14)],
	]
	for c in clues:
		scholar_tablets.append(KIT.collectible(root, c[0], "tablet", c[1], c[2], c[3] + Vector3(0, 0.05, 0)))
	_block(root, Vector3(-12, 0.55, 19), Vector3(1.1, 1.1, 0.7), 0.3, bronze, "Lectern")
	KIT.omni(root, Vector3(-13, 3.2, 20), Color(1.0, 0.8, 0.55), 1.4, 11.0)
	_interact(root, Vector3(-12, 0, 19.9), "[E] Study the archivist's lectern", _on_lectern, Vector3(1.8, 2.0, 1.8), "LecternUse")

func _on_lectern() -> void:
	if seals.scholar:
		_say("Mara", "The Scholar's seal is already mine.", 2.5)
		return
	var read := scholar_tablets.filter(func(t): return is_instance_valid(t) and t.collected).size()
	if read < scholar_tablets.size():
		_say("Mara", "The lectern's index points to %d tablets in these stacks. I've read %d." % [scholar_tablets.size(), read], 4.0)
		return
	_grant_seal("scholar", "Middle, deep, bright. The hymn is written into the seal itself.")

# ==================================================================================
# Echo Gardens: overgrown terraces, three tuned stones, sing the hymn -> seal
# ==================================================================================
func _echo_gardens() -> void:
	var root := Node3D.new()
	root.name = "EchoGardens"
	add_child(root)
	# Planting beds and a broken pergola of pillars, reclaimed by ferns and young trees.
	for bed in [Vector3(11, 0.25, 20), Vector3(18, 0.25, 19), Vector3(20, 0.25, 28)]:
		_block(root, bed, Vector3(4.0, 0.5, 2.6), 0.2, stone, "PlanterBed")
		for k in 3:
			_ph(root, "fern_02" if k % 2 == 0 else "calathea_orbifolia_01", bed + Vector3(-1.2 + k * 1.2, 0.25, 0.1), 0.9 + k * 0.15, k * 1.7)
	_ph(root, "pachira_aquatica_01", Vector3(21, 0, 22), 3.4, 0.6)
	_ph(root, "pachira_aquatica_01", Vector3(8, 0, 31), 2.8, 2.2)
	for p in [Vector3(9, 0, 22), Vector3(9, 0, 30), Vector3(19, 0, 31)]:
		_pillar(root, p, 4.0 if p.z < 30 else 2.2)
	_ph(root, "root_cluster_01", Vector3(19.5, -0.05, 31), 1.3, 0.4, false)
	# The three tuned stones: their size tells their voice.
	var stones := {"low": [Vector3(17, 0, 26), Vector3(1.4, 3.2, 1.4)], "mid": [Vector3(13.5, 0, 28.5), Vector3(1.0, 2.4, 1.0)], "high": [Vector3(10, 0, 26), Vector3(0.6, 1.8, 0.6)]}
	for voice in stones:
		var pos: Vector3 = stones[voice][0]
		var size: Vector3 = stones[voice][1]
		var body := _block(root, pos + Vector3(0, size.y * 0.5, 0), size, 0.15, stone, "Stone_" + voice)
		var band := BoxMesh.new()
		band.size = Vector3(size.x + 0.05, 0.12, size.z + 0.05)
		var bm := KIT.mesh(root, band, Transform3D(Basis(Vector3.UP, 0.15), pos + Vector3(0, size.y * 0.7, 0)), KIT.std_mat(Color(0.1, 0.12, 0.12), 0.4))
		bm.set_meta("collision", "none")
		var light := KIT.omni(root, pos + Vector3(0, size.y + 0.5, 0), Color(0.4, 0.9, 1.0), 0.0, 5.0)
		garden_stones[voice] = {"band": bm, "light": light, "body": body}
		var v: String = voice
		_interact(root, pos + Vector3(0, 0, -(size.z * 0.5 + 0.7)), "[E] Strike the %s stone" % {"low": "deep", "mid": "middle", "high": "bright"}[voice], func(): _strike(v), Vector3(1.8, 2.0, 1.8), "Strike_" + v)
	KIT.omni(root, Vector3(14, 4.0, 25), Color(0.6, 0.95, 0.8), 1.2, 14.0)

func _strike(voice: String) -> void:
	if seals.garden:
		return
	_flash_stone(voice, 1.6)
	garden_progress.append(voice)
	var expected: String = HYMN[garden_progress.size() - 1]
	if voice != expected:
		garden_progress.clear()
		garden_fails += 1
		for v in garden_stones:
			_flash_stone(v, 0.0)
		_say("Mara", "Dissonance. The stones went dead." if garden_fails < 2 else "Wrong again. The Scholar's Quarter tablets talked about voices... the order must be written there.", 4.0)
		return
	if garden_progress.size() == HYMN.size():
		_grant_seal("garden", "The whole garden is humming. A seal rose out of the deep stone.")

func _flash_stone(voice: String, energy: float) -> void:
	var s: Dictionary = garden_stones[voice]
	s.light.light_energy = energy

# ==================================================================================
# Temple District: courtyard with four braziers that burn for 30 s; light all four
# together to open the sanctum, take the seal from the altar.
# ==================================================================================
func _temple_district() -> void:
	var root := Node3D.new()
	root.name = "TempleDistrict"
	add_child(root)
	# Sanctum: walled cella with a heavy door facing the plaza (east).
	var c := Vector3(-14, 0, -12)
	# Low slab: a 0.3 m lip at the doorway was a marginal step for Mara.
	_block(root, c + Vector3(0, 0.05, 0), Vector3(9, 0.1, 9), 0.0, stone, "SanctumFloor")
	_block(root, c + Vector3(0, 2.2, -4.25), Vector3(8, 4.4, 0.5), 0.0, stone, "SanctumWall")
	_block(root, c + Vector3(0, 2.2, 4.25), Vector3(8, 4.4, 0.5), 0.0, stone, "SanctumWall")
	_block(root, c + Vector3(-4.25, 2.2, 0), Vector3(0.5, 4.4, 9), 0.0, stone, "SanctumWall")
	_block(root, c + Vector3(4.25, 2.2, -2.75), Vector3(0.5, 4.4, 3.5), 0.0, stone, "SanctumWall")
	_block(root, c + Vector3(4.25, 2.2, 2.75), Vector3(0.5, 4.4, 3.5), 0.0, stone, "SanctumWall")
	_block(root, c + Vector3(0, 4.6, 0), Vector3(9, 0.4, 9), 0.0, stone, "SanctumRoof")
	temple_door = _block(root, c + Vector3(4.25, 1.7, 0), Vector3(0.6, 3.4, 2.0), 0.0, bronze, "SanctumDoor")
	_block(root, c + Vector3(-1.5, 0.6, 0), Vector3(1.2, 0.9, 1.6), 0.0, stone, "Altar")
	KIT.omni(root, c + Vector3(-1, 3.0, 0), Color(0.9, 0.6, 0.35), 1.0, 7.0)
	temple_altar = _interact(root, c + Vector3(-0.3, 0, 0), "[E] Take the Temple seal", _on_altar, Vector3(1.8, 2.0, 1.8), "AltarUse")
	temple_altar.monitorable = false
	# Courtyard braziers: far enough apart that lighting all four in 30 s is a real run.
	for p in [Vector3(-20, 0, -3), Vector3(-6.5, 0, -3), Vector3(-6.5, 0, -20.5), Vector3(-20, 0, -20.5)]:
		var b := _brazier_visual(root, p, false)
		braziers.append(b)
		var idx := braziers.size() - 1
		_interact(root, p + Vector3(0.9, 0, 0), "[E] Light the brazier", func(): _light_brazier(idx), Vector3(2.2, 2.0, 2.2), "Brazier%d" % idx)
	for p in [c + Vector3(6, 0, -5), c + Vector3(6, 0, 5)]:
		_pillar(root, p, 5.0)

func _light_brazier(i: int) -> void:
	print("[CITY] brazier %d lit at %.1f" % [i, game_time])
	if seals.temple or _temple_open():
		return
	braziers[i].lit_at = game_time
	braziers[i].flame.visible = true
	braziers[i].light.visible = true
	var lit := braziers.filter(func(b): return _brazier_burning(b)).size()
	if lit == braziers.size():
		_open_temple()
	elif lit == 1:
		_say("Mara", "It's burning, but it won't last. All four, before the first goes out.", 3.5)

func _brazier_burning(b: Dictionary) -> bool:
	return game_time - float(b.lit_at) < BRAZIER_TIME

func _temple_open() -> bool:
	return not is_instance_valid(temple_door) or temple_door.is_queued_for_deletion()

func _open_temple() -> void:
	if is_instance_valid(temple_door):
		temple_door.queue_free() # free it: a disabled body can keep its collision
	temple_altar.monitorable = true
	for b in braziers:
		b.lit_at = 1.0e9 # stay lit for good
	_say("Mara", "All four. The sanctum door just slid into the floor.", 3.5)

func _on_altar() -> void:
	if not seals.temple and _temple_open():
		_grant_seal("temple", "The Temple seal. Warm, like it was waiting for fire.")

# ==================================================================================
# Collapsed Aqueduct (optional): stair to a broken deck with jump gaps, sluice lever
# re-opens a shortcut gate between the aqueduct and the Meridian camp.
# ==================================================================================
func _aqueduct() -> void:
	var root := Node3D.new()
	root.name = "CollapsedAqueduct"
	add_child(root)
	# Stair: 10 risers of 0.3 m from the plaza side up to the deck at 3.0 m.
	for i in 10:
		_block(root, Vector3(16, 0.15 + i * 0.3, -0.5 - i * 0.55), Vector3(3.0, 0.3 + i * 0.6, 0.6), 0.0, stone, "AqueductStair")
	# Deck segments with two 1 m collapses to jump; arches below carry it.
	for seg in [[-6.8, -11.0], [-12.0, -15.5], [-16.5, -21.0]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		var mid := (z0 + z1) * 0.5
		var length := absf(z1 - z0)
		_block(root, Vector3(16, 2.85, mid), Vector3(3.0, 0.3, length), 0.0, stone, "AqueductDeck")
		for side in [-1.0, 1.0]:
			_block(root, Vector3(16 + side * 1.35, 3.25, mid), Vector3(0.3, 0.5, length), 0.0, stone, "AqueductParapet")
		_block(root, Vector3(16, 1.35, mid), Vector3(1.2, 2.7, 1.2), 0.0, stone, "AqueductPier")
	_ph(root, "dry_branches_medium_01", Vector3(16.4, 3.0, -9.0), 1.0, 0.7, false)
	_block(root, Vector3(16, 3.6, -20.4), Vector3(0.5, 1.2, 0.5), 0.0, bronze, "SluiceLever")
	KIT.omni(root, Vector3(16, 5.0, -18), Color(0.55, 0.75, 1.0), 1.1, 9.0)
	_interact(root, Vector3(16, 3.0, -19.6), "[E] Open the aqueduct sluice", _on_sluice)
	# Shortcut gate at the aqueduct foot, opened by the sluice (drops you behind the camp).
	aqueduct_gate = _block(root, Vector3(11.5, 1.5, -21), Vector3(0.5, 3.0, 3.0), 0.0, bronze, "ShortcutGate")
	_block(root, Vector3(11.5, 1.5, -18.5), Vector3(0.5, 3.0, 2.0), 0.0, stone, "ShortcutWall")
	_block(root, Vector3(11.5, 1.5, -23.5), Vector3(0.5, 3.0, 2.0), 0.0, stone, "ShortcutWall")

func _on_sluice() -> void:
	if sluice_open:
		return
	sluice_open = true
	_apply_sluice()
	SkillManager.add_xp(150)
	MissionManager.register_objective("opt_c07_aqueduct", "Collapsed Aqueduct: restore the sluice")
	MissionManager.complete_objective("opt_c07_aqueduct")
	_say("Mara", "Water's running again. And that lowered the old gate below; a way round behind Meridian's camp.", 4.5)

func _apply_sluice() -> void:
	if is_instance_valid(aqueduct_gate):
		aqueduct_gate.queue_free() # free it: a disabled body can keep its collision

# ==================================================================================
# Meridian Forward Camp: three mercenaries, cover, supplies, the gate fuse box.
# ==================================================================================
func _meridian_camp() -> void:
	var root := Node3D.new()
	root.name = "MeridianForwardCamp"
	add_child(root)
	for c in [[Vector3(-3.5, 0, -15), 0.3], [Vector3(3.0, 0, -18.5), -0.5], [Vector3(-1.0, 0, -21.5), 1.2]]:
		_ph(root, "wooden_crate_01", c[0], 0.75, c[1])
		_ph(root, "wooden_crate_01", c[0] + Vector3(0.8, 0, 0.3), 0.75, c[1] + 0.4)
		KIT.box_body(root, c[0] + Vector3(0.4, 0.4, 0.15), Vector3(1.8, 0.8, 1.0), c[1], "CampCover")
	_ph(root, "portable_generator", Vector3(5.5, 0, -22.5), 0.62, 0.8)
	_ph(root, "portable_searchlight", Vector3(-5.5, 0, -22), 1.1, 2.6)
	_ph(root, "Barrel_01", Vector3(6.5, 0, -16), 0.95, 0.2)
	_ph(root, "barrel_03", Vector3(7.2, 0, -16.8), 0.95, 1.1)
	_ph(root, "old_military_compressor", Vector3(-6.5, 0, -17.5), 0.9, 1.6)
	KIT.omni(root, Vector3(0, 3.5, -18), Color(1.0, 0.85, 0.65), 1.8, 14.0)
	_block(root, Vector3(6.5, 0.8, -23.6), Vector3(0.9, 1.6, 0.4), 0.0, KIT.std_mat(Color(0.25, 0.3, 0.22), 0.6, 0.4), "FuseBox")
	_interact(root, Vector3(6.5, 0, -22.7), "[E] Pull the gate fuse", _on_fuse, Vector3(1.8, 2.0, 1.8), "FuseUse")
	var patrols := [[Vector3(-4, 0, -14), Vector3(4, 0, -14)], [Vector3(4, 0, -20), Vector3(-2, 0, -20)], [Vector3(0, 0, -23), Vector3(0, 0, -16)]]
	for i in patrols.size():
		var e := ENEMY.instantiate()
		e.name = "CampMercenary%d" % (i + 1)
		root.add_child(e)
		e.global_position = patrols[i][0]
		# Dim camp: shorter sight so patrols can be picked off or slipped past one at a time.
		e.sight_range = 15.0
		if "patrol_points" in e:
			var pts: Array[Vector3] = [patrols[i][0], patrols[i][1]]
			e.patrol_points = pts
		camp_enemies.append(e)

func _on_fuse() -> void:
	if fuse_cut:
		return
	fuse_cut = true
	MissionManager.complete_objective("obj_c07_cut_fuse")
	_say("Mara", "Fuse is out. Their gate lock's dead.", 3.0)
	_check_gate()

# ==================================================================================
# Causeway gate: a full-width Meridian barricade with a Vaelor portcullis in the middle.
# Opens when all three seals are set and the fuse is cut.
# ==================================================================================
func _causeway_gate() -> void:
	var root := Node3D.new()
	root.name = "CausewayGate"
	add_child(root)
	_block(root, Vector3(-14, 2.5, -25.5), Vector3(22, 5.0, 1.0), 0.0, stone, "GateWall")
	_block(root, Vector3(14, 2.5, -25.5), Vector3(22, 5.0, 1.0), 0.0, stone, "GateWall")
	_block(root, Vector3(0, 4.6, -25.5), Vector3(6, 0.8, 1.2), 0.0, stone, "GateLintel")
	gate_bar = _block(root, Vector3(0, 2.1, -25.5), Vector3(6, 4.2, 0.4), 0.0, bronze, "Portcullis")
	for i in 3:
		var socket := CylinderMesh.new()
		socket.top_radius = 0.28
		socket.bottom_radius = 0.28
		socket.height = 0.1
		var mi := KIT.mesh(root, socket, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.2 + i * 1.2, 4.6, -24.85)), KIT.std_mat(Color(0.2, 0.2, 0.2), 0.5))
		mi.set_meta("collision", "none")
		mi.name = "SealSocket%d" % i
	KIT.omni(root, Vector3(0, 4.0, -23.5), Color(0.5, 0.8, 0.9), 1.2, 8.0)

func _check_gate() -> void:
	var count := seals.values().filter(func(v): return v).size()
	for i in 3:
		var s := get_node_or_null("CausewayGate/SealSocket%d" % i) as MeshInstance3D
		if s:
			s.material_override = glow if i < count else KIT.std_mat(Color(0.2, 0.2, 0.2), 0.5)
	if count == 3 and fuse_cut and not gate_open:
		gate_open = true
		_apply_gate()
		MissionManager.register_objective("obj_c07_cross_causeway", "Cross the Royal Causeway toward the Heart Vault road")
		_say("Mara", "Three seals and no power to the lock. The portcullis is going up.", 4.0)
		gate_opened.emit()

func _apply_gate() -> void:
	if is_instance_valid(gate_bar):
		gate_bar.queue_free() # free it: a disabled body can keep its collision

func _grant_seal(id: String, line: String) -> void:
	seals[id] = true
	var n := seals.values().filter(func(v): return v).size()
	SkillManager.add_xp(120)
	MissionManager.complete_objective("obj_c07_seal_" + id)
	_say("Mara", line + " (%d of 3 seals)" % n, 4.5)
	var player := level.get_node_or_null("Player") as Node3D
	if player:
		MissionManager.set_checkpoint("c07_seal_" + id, player.global_transform)
	_check_gate()

## Called by Chapter7 when the mural is read: the city's objectives open up.
func begin_main_objectives() -> void:
	var names := {"scholar": "Scholar's Quarter: learn the hymn and claim the seal", "garden": "Echo Gardens: sing the hymn on the tuned stones", "temple": "Temple District: light the four braziers together"}
	for id in seals:
		if not seals[id]:
			MissionManager.register_objective("obj_c07_seal_" + id, names[id])
	if not fuse_cut:
		MissionManager.register_objective("obj_c07_cut_fuse", "Meridian Forward Camp: pull the causeway gate fuse")
	_check_gate()

# ==================================================================================
# Tomb 1, Hall of Weights: balance two pans with four weights (1-4); equal and heavy
# enough lifts the inner gate. Reset lever returns every weight.
# ==================================================================================
func _hall_of_weights() -> void:
	var root := Node3D.new()
	root.name = "HallOfWeights"
	add_child(root)
	var c := Vector3(-15, 0, 34)
	_tomb_room(root, c, Vector3(10, 4.5, 8), "e")
	for i in 2:
		var pan := Node3D.new()
		pan.name = "Pan%d" % i
		root.add_child(pan)
		pan.global_position = c + Vector3(-2.5 + i * 5.0, 1.0, -1.5)
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.12
		KIT.mesh(pan, disc, pan.global_transform, bronze).set_meta("collision", "none")
		_block(root, pan.global_position + Vector3(0, -0.5, 0), Vector3(0.25, 1.0, 0.25), 0.0, bronze, "PanPost")
		pans.append(pan)
	for i in 4:
		var w := Node3D.new()
		w.name = "Weight%d" % (i + 1)
		root.add_child(w)
		var cube := BoxMesh.new()
		var s := 0.28 + 0.1 * i
		cube.size = Vector3(s, s, s)
		KIT.mesh(w, cube, Transform3D(Basis(), Vector3(0, s * 0.5, 0)), stone).set_meta("collision", "none")
		weight_nodes.append(w)
		var idx := i
		_interact(root, c + Vector3(-3 + i * 2.0, 0, 1.8), "[E] Move the %d-talent weight" % (i + 1), func(): _cycle_weight(idx), Vector3(1.4, 2.0, 1.4))
		_block(root, c + Vector3(-3 + i * 2.0, 0.4, 2.6), Vector3(0.7, 0.8, 0.7), 0.0, stone, "WeightPedestal")
	weights_door = _block(root, c + Vector3(0, 1.6, -3.6), Vector3(2.4, 3.2, 0.4), 0.0, bronze, "InnerGate")
	_block(root, c + Vector3(0, 0.5, -3.9 - 0.6), Vector3(1.2, 1.0, 0.8), 0.0, stone, "RewardPlinth")
	_interact(root, c + Vector3(4.2, 0, 2.5), "[E] Pull the reset lever", _reset_weights, Vector3(1.4, 2.0, 1.4))
	KIT.collectible(root, "c07_weights_hint", "tablet", "Hall of Weights", "Equal hearts lift the stone. The light hand alone cannot: the scale must carry at least five talents a side.", c + Vector3(-4.2, 0.05, 2.8))
	_apply_weights()

func _cycle_weight(i: int) -> void:
	if weights_solved:
		return
	weights[i] = (weights[i] + 1) % 3
	_apply_weights()
	var l := 0
	var r := 0
	for k in 4:
		if weights[k] == 1:
			l += k + 1
		elif weights[k] == 2:
			r += k + 1
	if l == r and l >= 5:
		weights_solved = true
		_apply_weights()
		_tomb_reward("weights", "Hall of Weights", "Perfect balance. The inner gate is rising.")

func _reset_weights() -> void:
	if weights_solved:
		return
	weights = [0, 0, 0, 0]
	_apply_weights()
	_say("Mara", "Back to the pedestals.", 2.0)

func _apply_weights() -> void:
	if pans.size() < 2:
		return
	var c := Vector3(-15, 0, 34)
	var load_lr := [0, 0]
	var stacked := [0, 0]
	for k in 4:
		var w := weight_nodes[k]
		if weights[k] == 0:
			w.global_position = c + Vector3(-3 + k * 2.0, 0.8, 2.6)
		else:
			var side: int = weights[k] - 1
			load_lr[side] += k + 1
			w.global_position = pans[side].global_position + Vector3(-0.45 + stacked[side] * 0.3, 0.06, 0)
			stacked[side] += 1
	var tilt := clampf((load_lr[0] - load_lr[1]) * 0.08, -0.5, 0.5)
	pans[0].position.y = 1.0 - tilt
	pans[1].position.y = 1.0 + tilt
	if weights_solved and is_instance_valid(weights_door):
		weights_door.queue_free() # free it: a disabled body can keep its collision

# ==================================================================================
# Tomb 2, Sunken Archive: three valves (+3, +2, -1) set the water level; at mark 7 the
# floating archive chest meets the shelf. Overfill past 9 drains everything (recovery).
# ==================================================================================
func _sunken_archive() -> void:
	var root := Node3D.new()
	root.name = "SunkenArchive"
	add_child(root)
	var c := Vector3(16, 0, 10)
	_tomb_room(root, c, Vector3(8, 4.5, 6), "w")
	# Basin: sunken floor, water plane that rises 0.2 m per mark, notches on the far wall.
	archive_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.6, 4.6)
	archive_water.mesh = plane
	archive_water.material_override = KIT.std_mat(Color(0.1, 0.25, 0.3, 0.75), 0.05, 0.0, Color(0.05, 0.2, 0.25), 0.4)
	(archive_water.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	archive_water.set_meta("collision", "none")
	root.add_child(archive_water)
	archive_crate = Node3D.new()
	root.add_child(archive_crate)
	_ph(archive_crate, "wooden_crate_01", Vector3.ZERO, 0.6, 0.3)
	for mark in range(1, 10):
		var notch := BoxMesh.new()
		notch.size = Vector3(0.5 if mark != 7 else 1.1, 0.04, 0.05)
		KIT.mesh(root, notch, Transform3D(Basis(), c + Vector3(0, 0.05 + mark * 0.2, -2.7)), KIT.std_mat(Color(0.9, 0.75, 0.3) if mark == 7 else Color(0.5, 0.5, 0.45), 0.5, 0.0,
			Color(0.9, 0.7, 0.2) if mark == 7 else Color.BLACK, 1.5 if mark == 7 else 0.0)).set_meta("collision", "none")
	_block(root, c + Vector3(2.2, 0.05 + 7 * 0.2 - 0.1, -2.4), Vector3(1.6, 0.2, 0.6), 0.0, stone, "ArchiveShelf")
	var valves := [[3, Vector3(-3.4, 0, 0.0)], [2, Vector3(-3.4, 0, 1.6)], [-1, Vector3(-3.4, 0, -1.6)]]
	for v in valves:
		var amount: int = v[0]
		var at: Vector3 = c + v[1]
		_block(root, at + Vector3(0, 0.9, 0), Vector3(0.3, 0.6, 0.6), 0.0, bronze, "Valve")
		_interact(root, at + Vector3(0.7, 0, 0), "[E] Turn the valve (%s%d)" % ["+" if amount > 0 else "", amount], func(): _valve(amount), Vector3(1.2, 2.0, 1.2))
	KIT.collectible(root, "c07_archive_hint", "tablet", "Sunken Archive", "The archive floats on the seventh mark. Too much water and the old drains open and the hall empties itself.", c + Vector3(3.0, 0.05, 2.2))
	KIT.omni(root, c + Vector3(0, 3.2, 0), Color(0.5, 0.8, 0.9), 1.2, 8.0)
	_apply_water()

func _valve(amount: int) -> void:
	if archive_solved:
		return
	water_level = maxi(0, water_level + amount)
	if water_level > 9:
		water_level = 0
		_say("Mara", "Too much. The drains opened and it's all gone. Start again.", 3.5)
	_apply_water()
	if water_level == 7:
		archive_solved = true
		_tomb_reward("archive", "Sunken Archive", "The chest floated right up onto the shelf. Seventh mark.")

func _apply_water() -> void:
	if not is_instance_valid(archive_water):
		return
	var c := Vector3(16, 0, 10)
	var y := 0.05 + water_level * 0.2
	archive_water.global_position = c + Vector3(0, y, 0)
	archive_water.visible = water_level > 0
	archive_crate.global_position = c + (Vector3(2.2, y + 0.1, -2.4) if archive_solved else Vector3(1.0, y, -0.5))

# ==================================================================================
# Tomb 3, Resonant Chamber: four resonators around a crystal; turning one also turns
# its clockwise neighbour. All four must face the crystal.
# ==================================================================================
func _resonant_chamber() -> void:
	var root := Node3D.new()
	root.name = "ResonantChamber"
	add_child(root)
	var c := Vector3(15, 0, 38)
	_tomb_room(root, c, Vector3(9, 5.0, 7), "s")
	var crystal := KIT.place(root, "res://assets/models/cave/lod/cav_resonant_crystal_cluster_a_LOD0.glb", c, 1.6, 0.0, Vector3.ONE, true, "Crystal")
	if crystal:
		crystal.set_meta("collision", "none")
	chamber_crystal = KIT.omni(root, c + Vector3(0, 1.4, 0), Color(0.4, 0.9, 1.0), 0.3, 6.0)
	if resonators == [0, 0, 0, 0]:
		resonators = [1, 0, 2, 3] # solvable: reached from solved by a fixed sequence of linked turns
	var offsets := [Vector3(0, 0, -2.4), Vector3(2.8, 0, 0), Vector3(0, 0, 2.4), Vector3(-2.8, 0, 0)]
	for i in 4:
		var r := Node3D.new()
		r.name = "Resonator%d" % i
		root.add_child(r)
		r.global_position = c + offsets[i]
		var col := BoxMesh.new()
		col.size = Vector3(0.6, 1.8, 0.6)
		KIT.mesh(r, col, r.global_transform * Transform3D(Basis(), Vector3(0, 0.9, 0)), stone).set_meta("collision", "none")
		var face := BoxMesh.new()
		face.size = Vector3(0.4, 0.4, 0.06)
		KIT.mesh(r, face, r.global_transform * Transform3D(Basis(), Vector3(0, 1.3, -0.33)), glow).set_meta("collision", "none")
		resonator_nodes.append(r)
		var idx := i
		_interact(root, r.global_position + offsets[i].normalized() * 0.9, "[E] Turn the resonator", func(): _turn_resonator(idx), Vector3(1.2, 2.0, 1.2))
	KIT.collectible(root, "c07_chamber_hint", "tablet", "Resonant Chamber", "Each voice drags its neighbour round with it. All four must sing to the heart at once.", c + Vector3(-3.6, 0.05, 2.6))
	_apply_resonators()

func _turn_resonator(i: int) -> void:
	if chamber_solved:
		return
	resonators[i] = (resonators[i] + 1) % 4
	var n := (i + 1) % 4
	resonators[n] = (resonators[n] + 1) % 4
	_apply_resonators()
	if resonators == [0, 0, 0, 0]:
		chamber_solved = true
		_apply_resonators()
		_tomb_reward("chamber", "Resonant Chamber", "All four are facing the heart. Listen to that...")

func _apply_resonators() -> void:
	var c := Vector3(15, 0, 38)
	for i in resonator_nodes.size():
		var r := resonator_nodes[i]
		var to_center := c - r.global_position
		var facing := atan2(-to_center.x, -to_center.z)
		r.rotation.y = facing + resonators[i] * PI * 0.5
	if is_instance_valid(chamber_crystal):
		chamber_crystal.light_energy = 3.5 if chamber_solved else 0.3

# ==================================================================================
# Shared tomb construction and rewards
# ==================================================================================
## Walled room centred at c with a 2.4 m doorway on side n/e/s/w.
func _tomb_room(root: Node3D, c: Vector3, size: Vector3, door: String) -> void:
	_block(root, c + Vector3(0, -0.1, 0), Vector3(size.x, 0.2, size.z), 0.0, stone, "TombFloor")
	_block(root, c + Vector3(0, size.y + 0.2, 0), Vector3(size.x + 1, 0.4, size.z + 1), 0.0, stone, "TombRoof")
	var sides := {"n": [Vector3(0, 0, -size.z * 0.5), true], "s": [Vector3(0, 0, size.z * 0.5), true], "e": [Vector3(size.x * 0.5, 0, 0), false], "w": [Vector3(-size.x * 0.5, 0, 0), false]}
	for k in sides:
		var off: Vector3 = sides[k][0]
		var along_x: bool = sides[k][1]
		var length := size.x if along_x else size.z
		if k != door:
			_block(root, c + off + Vector3(0, size.y * 0.5, 0), Vector3(length, size.y, 0.5) if along_x else Vector3(0.5, size.y, length), 0.0, stone, "TombWall")
		else:
			var seg := (length - 2.4) * 0.5
			for s in [-1.0, 1.0]:
				var shift: float = (1.2 + seg * 0.5) * s
				var p: Vector3 = c + off + (Vector3(shift, size.y * 0.5, 0) if along_x else Vector3(0, size.y * 0.5, shift))
				_block(root, p, Vector3(seg, size.y, 0.5) if along_x else Vector3(0.5, size.y, seg), 0.0, stone, "TombWall")
			var lp := c + off + Vector3(0, 3.0 + (size.y - 3.0) * 0.5, 0)
			_block(root, lp, Vector3(2.4, size.y - 3.0, 0.5) if along_x else Vector3(0.5, size.y - 3.0, 2.4), 0.0, stone, "TombLintel")
	KIT.omni(root, c + Vector3(0, size.y - 0.8, 0), Color(1.0, 0.75, 0.5), 1.0, maxf(size.x, size.z))

func _tomb_reward(id: String, title: String, line: String) -> void:
	SkillManager.add_xp(300)
	MissionManager.register_objective("opt_c07_tomb_" + id, "Optional tomb: " + title)
	MissionManager.complete_objective("opt_c07_tomb_" + id)
	_say("Mara", line, 4.0)

# ==================================================================================
# Streets: rubble-lined lanes and low walls that guide between districts.
# ==================================================================================
func _streets() -> void:
	var root := Node3D.new()
	root.name = "Streets"
	add_child(root)
	for w in [[Vector3(-6, 0.4, 16), Vector3(0.6, 0.8, 6), 0.3], [Vector3(6, 0.4, 16), Vector3(0.6, 0.8, 6), -0.3],
			[Vector3(-9, 0.4, -24), Vector3(0.6, 0.8, 2.5), 0.0], [Vector3(10, 0.4, 2), Vector3(4, 0.8, 0.6), 0.0]]:
		_block(root, w[0], w[1], w[2], stone, "LowWall")
	for r in [Vector3(-21, 0, 3), Vector3(21, 0, 34), Vector3(-21, 0, -24), Vector3(21, 0, -8)]:
		_ph(root, "rock_moss_set_02", r, 2.6, r.x, false)

# ==================================================================================
# Persistence
# ==================================================================================
func get_persistent_state() -> Dictionary:
	return {"seals": seals.duplicate(), "fuse_cut": fuse_cut, "gate_open": gate_open, "sluice_open": sluice_open,
		"temple_open": _temple_open(), "weights": weights.duplicate(), "weights_solved": weights_solved,
		"water_level": water_level, "archive_solved": archive_solved, "resonators": resonators.duplicate(), "chamber_solved": chamber_solved}

func restore_persistent_state(d: Dictionary) -> void:
	for k in seals:
		seals[k] = bool(d.get("seals", {}).get(k, false))
	fuse_cut = bool(d.get("fuse_cut", false))
	sluice_open = bool(d.get("sluice_open", false))
	weights = Array(d.get("weights", weights)).map(func(v): return int(v))
	weights_solved = bool(d.get("weights_solved", false))
	water_level = int(d.get("water_level", 0))
	archive_solved = bool(d.get("archive_solved", false))
	resonators = Array(d.get("resonators", resonators)).map(func(v): return int(v))
	chamber_solved = bool(d.get("chamber_solved", false))
	if d.get("temple_open", false):
		_open_temple()
	if sluice_open:
		_apply_sluice()
	_apply_weights()
	_apply_water()
	_apply_resonators()
	gate_open = false
	_check_gate()
	if bool(d.get("gate_open", false)) and not gate_open:
		gate_open = true
		_apply_gate()

## Game time (pauses and slow frames don't eat the brazier window).
var game_time := 0.0

func _process(d: float) -> void:
	game_time += d
	for i in flames.size():
		var f := flames[i]
		if is_instance_valid(f) and f.visible:
			var k := 1.0 + sin(game_time * 13.0 + i * 1.7) * 0.08 + sin(game_time * 7.3 + i) * 0.06
			f.scale = Vector3(1.0 / sqrt(k), k, 1.0 / sqrt(k))
	# Braziers burn out unless the sanctum has opened.
	if _temple_open():
		return
	for b in braziers:
		if b.lit_at > 0.0 and not _brazier_burning(b) and b.flame.visible:
			b.flame.visible = false
			b.light.visible = false
