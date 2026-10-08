extends Node

## Skill and Progression System Singleton
enum SkillBranch {
	SURVIVOR,
	EXPLORER,
	HUNTER
}

var current_xp: int = 0
var available_skill_points: int = 0

var unlocked_skills: Dictionary = {
	"survivor_resource_awareness": false,
	"survivor_deep_breath": false,
	"explorer_strong_grip": false,
	"explorer_quick_mantle": false,
	"hunter_silent_step": false,
	"hunter_steady_aim": false
}

signal xp_gained(amount: int, total_xp: int)
signal skill_unlocked(skill_id: String)
signal skill_points_changed(points: int)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var previous_threshold = int(current_xp / 100)
	current_xp += amount
	xp_gained.emit(amount, current_xp)
	# Check for point thresholds
	var target_points = int(current_xp / 100)
	if target_points > previous_threshold:
		available_skill_points += target_points - previous_threshold
		skill_points_changed.emit(available_skill_points)
		print("[SKILL] Skill point earned! Total available:", available_skill_points)

func unlock_skill(skill_id: String) -> bool:
	if not unlocked_skills.has(skill_id):
		return false
	if unlocked_skills[skill_id]:
		return true # Already unlocked
	if available_skill_points <= 0:
		print("[SKILL] Insufficient skill points to unlock:", skill_id)
		return false
		
	available_skill_points -= 1
	unlocked_skills[skill_id] = true
	skill_unlocked.emit(skill_id)
	skill_points_changed.emit(available_skill_points)
	print("[SKILL] Unlocked skill:", skill_id)
	return true

func is_skill_unlocked(skill_id: String) -> bool:
	return unlocked_skills.get(skill_id, false)
