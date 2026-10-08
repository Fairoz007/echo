extends SceneTree
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var gm = root.get_node("GameManager")
 root.get_node("SaveManager").save_directory = "user://qa_performance"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_performance"))
 for chapter in range(12):
  gm.load_chapter(chapter, gm.chapter_scene(chapter))
  await create_timer(2.0).timeout
  var samples: Array[float] = []
  var start = Time.get_ticks_msec()
  while Time.get_ticks_msec() - start < 3000:
   await process_frame
   samples.append(Performance.get_monitor(Performance.TIME_FPS))
  var total = 0.0
  var minimum = INF
  for sample in samples:
   total += sample
   minimum = minf(minimum, sample)
  print("RENDER FPS chapter=%d avg=%.1f min=%.1f samples=%d" % [chapter,total / max(1,samples.size()),minimum,samples.size()])
 root.get_node("AudioManager").stop_dialogue()
 gm.return_to_menu()
 await create_timer(16.0).timeout
 print("QA PASS: rendered stationary frame rate samples; navigation stress and ten-hour endurance unverified")
 quit(0)


