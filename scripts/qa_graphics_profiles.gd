extends SceneTree
var original_bytes := PackedByteArray()
var original_exists := false
var original_preset := 0
func _initialize() -> void:
 call_deferred("_run")
func _restore() -> void:
 root.get_node("GraphicsSettings").apply_preset(original_preset, false)
 if original_exists:
  var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
  file.store_buffer(original_bytes)
  file.close()
 else:
  DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
func _fail(message: String) -> void:
 _restore()
 push_error(message)
 quit(1)
func _run() -> void:
 var quality = root.get_node("GraphicsSettings")
 original_preset = quality.preset
 original_exists = FileAccess.file_exists("user://settings.cfg")
 if original_exists:
  original_bytes = FileAccess.get_file_as_bytes("user://settings.cfg")
 var scene = Node3D.new()
 scene.name = "QualityFixture"
 root.add_child(scene)
 current_scene = scene
 var mesh = MeshInstance3D.new()
 mesh.mesh = BoxMesh.new()
 scene.add_child(mesh)
 var light = DirectionalLight3D.new()
 light.shadow_enabled = true
 scene.add_child(light)
 var world = WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.ssao_enabled = true
 scene.add_child(world)
 var foliage: Array[Node3D] = []
 for i in range(6):
  var tree = Node3D.new()
  tree.scene_file_path = "res://assets/environment/jungle/jungle_tree.glb"
  scene.add_child(tree)
  foliage.append(tree)
 var water = preload("res://systems/WaterPresentation.gd").new()
 scene.add_child(water)
 var water_height = water.global_position.y
 quality.apply_preset(0, false)
 var low_triangles = water.surface_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
 if Engine.max_fps != 30 or root.msaa_3d != Viewport.MSAA_DISABLED or root.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED or light.shadow_enabled or world.environment.ssao_enabled or not is_equal_approx(mesh.lod_bias, 0.4):
  _fail("Low profile did not reduce frame/AA/shadow/effect/LOD settings")
  return
 var visible_count = 0
 for tree in foliage:
  visible_count += int(tree.visible)
 if visible_count != 2:
  _fail("Low profile foliage density was not one third")
  return
 quality.apply_preset(2, false)
 var high_triangles = water.surface_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
 if Engine.max_fps != 60 or root.msaa_3d != Viewport.MSAA_2X or not light.shadow_enabled or not world.environment.ssao_enabled or not is_equal_approx(mesh.lod_bias, 1.0):
  _fail("High profile did not restore authored shadow/effect settings")
  return
 quality.apply_preset(1, true)
 var balanced_triangles = water.surface_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
 if not (low_triangles < balanced_triangles and balanced_triangles < high_triangles) or water.global_position.y != water_height:
  _fail("Water detail did not reduce geometry while preserving water height")
  return
 print("WATER quality triangles low=", low_triangles, " balanced=", balanced_triangles, " high=", high_triangles)
 var config = ConfigFile.new()
 if config.load("user://settings.cfg") != OK or int(config.get_value("graphics", "preset", -1)) != 1 or world.environment.ssao_enabled or not light.shadow_enabled:
  _fail("Balanced profile settings/persistence failed")
  return
 var loader = preload("res://systems/GraphicsSettings.gd").new()
 root.add_child(loader)
 var expected_loaded = 0 if OS.get_cmdline_user_args().has("--safe-graphics") else 1
 if loader.preset != expected_loaded:
  _fail("Fresh settings instance did not load persisted profile")
  return
 loader.queue_free()
 _restore()
 if original_exists and FileAccess.get_file_as_bytes("user://settings.cfg") != original_bytes:
  push_error("User settings backup restoration changed bytes")
  quit(1)
  return
 print("QA PASS: low reductions, authored high restore, balanced persistence/reload; user settings restored; no other physical GPU claim")
 scene.queue_free()
 await process_frame
 quit(0)
