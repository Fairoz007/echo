extends RefCounted
## Replaces blockout/white surfaces with production triplanar materials.
## Targets visible CSG / MeshInstance3D geometry (not imported GLBs) whose material is
## missing or a flat untextured StandardMaterial3D. Flat/horizontal pieces get the
## blended ground material, upright pieces the limestone rock material.
## Skips emissive, transparent, player/NPC, water and anything with meta "keep_material".

const ROCK_SHADER := preload("res://materials/cave_rock.gdshader")
const GROUND_SHADER := preload("res://materials/cave_ground.gdshader")
const WALL_TEX := "res://assets/environment/cave/cave_wall_limestone_Color_e63e799a-2e6c-41d4-966d-f77e80cd4719.jpg"
const FLOOR_TEX := "res://assets/environment/cave/cave_floor_sediment_Color_9ebda37d-24d2-422f-b7e2-13565bd3ab05.jpg"
const FLOOR_NRM := "res://assets/environment/cave/cave_floor_sediment_NormalGL_9ebda37d-24d2-422f-b7e2-13565bd3ab05.png"
const SKIP_WORDS := ["water", "basin", "glow", "light", "beam", "trigger", "player", "mara", "elias", "nadiya", "adrian", "drake", "enemy", "mercenary", "npc"]

static var _rock: ShaderMaterial
static var _ground: ShaderMaterial

static func materials() -> Array:
	if _rock == null:
		var noise := NoiseTexture2D.new()
		var n := FastNoiseLite.new()
		n.seed = 911
		n.frequency = 0.012
		n.fractal_octaves = 5
		noise.noise = n
		noise.seamless = true
		var normal := NoiseTexture2D.new()
		var n2 := FastNoiseLite.new()
		n2.seed = 913
		n2.frequency = 0.03
		n2.fractal_octaves = 4
		normal.noise = n2
		normal.seamless = true
		normal.as_normal_map = true
		normal.bump_strength = 6.0
		_rock = ShaderMaterial.new()
		_rock.shader = ROCK_SHADER
		_rock.set_shader_parameter("albedo_tex", load(WALL_TEX))
		_rock.set_shader_parameter("normal_tex", normal)
		_rock.set_shader_parameter("noise_tex", noise)
		_rock.set_shader_parameter("vertex_color_mix", 0.0)
		_ground = ShaderMaterial.new()
		_ground.shader = GROUND_SHADER
		_ground.set_shader_parameter("sediment_tex", load(FLOOR_TEX))
		_ground.set_shader_parameter("sediment_normal", load(FLOOR_NRM))
		_ground.set_shader_parameter("rock_tex", load(WALL_TEX))
		_ground.set_shader_parameter("noise_tex", noise)
		_ground.set_shader_parameter("vertex_color_mix", 0.0)
	return [_rock, _ground]

static func is_blockout(node: GeometryInstance3D) -> bool:
	var mat: Material = node.material_override
	if mat == null and node is CSGShape3D and "material" in node:
		mat = node.material
	if mat == null and node is MeshInstance3D:
		if node.mesh == null or node.get_parent().scene_file_path != "" or node.owner and node.owner.scene_file_path.ends_with(".glb"):
			return false
		mat = node.get_active_material(0)
	if mat == null:
		return true
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		if sm.emission_enabled or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		return sm.albedo_texture == null and sm.normal_texture == null and not sm.uv1_triplanar
	return false

static func apply(level: Node) -> Array[String]:
	var changed: Array[String] = []
	var mats := materials()
	for node in level.find_children("*", "GeometryInstance3D", true, false):
		if not (node is CSGShape3D or node is MeshInstance3D):
			continue
		if node is CSGShape3D and node.get_parent() is CSGShape3D:
			continue
		if node.has_meta("keep_material"):
			continue
		var label := (String(node.name) + " " + String(node.get_parent().name)).to_lower()
		if SKIP_WORDS.any(func(w): return label.contains(w)):
			continue
		var p := node.get_parent()
		var skip := false
		while p and p != level:
			if p is CharacterBody3D or p.is_in_group("player"):
				skip = true
			p = p.get_parent()
		if skip or not is_blockout(node):
			continue
		var box: AABB = node.get_aabb()
		var b: Basis = node.global_transform.basis
		var size := Vector3(box.size.x * b.x.length(), box.size.y * b.y.length(), box.size.z * b.z.length())
		var flat := size.y < 0.35 * maxf(size.x, size.z) and size.x > 3.0 and size.z > 3.0
		node.material_override = mats[1] if flat else mats[0]
		changed.append(str(level.get_path_to(node)))
	return changed
