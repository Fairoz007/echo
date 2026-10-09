extends SceneTree
## Ch5 teardown bisect: frees top-level nodes one at a time, printing each name, so the
## gles3 'Parameter "material" is null' errors can be attributed to a subtree.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var gm := root.get_node("GameManager")
	root.get_node("SaveManager").save_directory = "user://qa_levelb_load"
	change_scene_to_file(gm.chapter_scene(5))
	await create_timer(3.0).timeout
	paused = true
	var groups: Array = []
	var d := current_scene.get_node_or_null("LevelBDressing")
	if d:
		groups.append_array(d.get_children())
	for c in current_scene.get_children():
		if c != d:
			groups.append(c)
	for e in current_scene.get_node("Enemies").get_children():
		for ba in e.find_children("Gear_*", "BoneAttachment3D", true, false):
			print("FREEING gear ", ba.get_path())
			ba.get_parent().remove_child(ba)
			ba.free()
			RenderingServer.force_draw(false)
		print("CLEARING overrides ", e.name)
		for mi in e.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = null
		RenderingServer.force_draw(false)
		for c in e.get_children():
			print("FREEING enemy child ", c.get_path(), " ", c.get_class())
			e.remove_child(c)
			c.free()
			RenderingServer.force_draw(false)
	for n in groups:
		if not is_instance_valid(n):
			continue
		print("FREEING ", n.get_path())
		var nm := String(n.name)
		n.get_parent().remove_child(n)
		n.free()
		RenderingServer.force_draw(false)
		print("FREED ", nm)
	print("PROBE DONE")
	quit(0)
