extends Node
func _ready():
	var bad := 0
	var stack := ["res://"]
	while stack.size() > 0:
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			if sub.begins_with(".") or sub == "addons": continue
			stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var p := d.path_join(f)
				if p.contains("/screenshots/") or p.contains("/qa_reports/"): continue
				print("CHK ", p)
				var s = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
				if s == null or not (s as GDScript).can_instantiate() and not (s as GDScript).is_abstract():
					print("PARSE_FAIL ", p); bad += 1
	print("PARSE_DONE bad=", bad)
	get_tree().quit()
