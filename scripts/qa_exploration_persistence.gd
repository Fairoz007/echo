extends SceneTree

## Authored puzzle behavior/state fixture, not a physical optional-tomb route.
func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("QA FAILED: " + message)
	quit(1)

func _run() -> void:
	var gm = root.get_node("GameManager")
	var sm = root.get_node("SaveManager")
	sm.save_directory = "user://qa_exploration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sm.save_directory))
	gm.load_chapter(1, "res://levels/Chapter1.tscn")
	await create_timer(0.6).timeout
	var exploration = current_scene.get_node_or_null("CampaignExploration")
	if not exploration or exploration.records.size() != 3:
		_fail("Chapter 1 did not construct three archaeology chambers")
		return
	var record: Dictionary = exploration.records[0]
	var player = get_first_node_in_group("player")
	var skills = root.get_node("SkillManager")
	var initial_xp: int = skills.current_xp
	exploration._test(record, player)
	if exploration.state[record.id].solved:
		_fail("Unread inscription permitted puzzle solution")
		return
	exploration._close_journal()
	exploration._read(record)
	exploration._close_journal()
	for dial in range(3):
		for turn in range(int(record.solution[dial])):
			exploration._turn(record, dial)
	print("QA puzzle fixture state=", exploration.state[record.id], " solution=", record.solution, " equality=", exploration.state[record.id].dials == record.solution)
	exploration._test(record, player)
	exploration._close_journal()
	if not exploration.state[record.id].solved or skills.current_xp != initial_xp + 120:
		_fail("Authored dial solution did not recover archive exactly once")
		return
	exploration._test(record, player)
	exploration._close_journal()
	if skills.current_xp != initial_xp + 120:
		_fail("Recovered archive granted repeated XP")
		return
	if not sm.save_game(96) or not gm.continue_saved_game(96):
		_fail("Archaeology state save/load failed")
		return
	await create_timer(0.3).timeout
	exploration = current_scene.get_node("CampaignExploration")
	if not exploration.state[record.id].solved or exploration.state[record.id].dials != record.solution:
		_fail("Persistent-world group failed to restore archaeology state")
		return
	print("QA PASS: authored inscription/dial puzzle, single XP award and persistent-world restore")
	gm.return_to_menu()
	await create_timer(15.0).timeout
	quit(0)
