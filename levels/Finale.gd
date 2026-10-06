extends Node3D

## Finale: The Mountain Breaks - High-Speed Escape & Epilogue Sequence
@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD

@onready var daylight_exit_trigger: Area3D = $DaylightRidge/DaylightExitTrigger

func _ready() -> void:
	MissionManager.register_objective("obj_finale_escape", "Sprint through the collapsing shafts toward daylight")
	
	if daylight_exit_trigger:
		daylight_exit_trigger.body_entered.connect(_on_daylight_reached)
		
	await get_tree().create_timer(1.0).timeout
	if hud:
		hud.show_subtitle("Mara", "I see daylight! Tomas, Nadiya, I'm almost through the eastern fissure!", 4.0)

func _on_daylight_reached(body: Node) -> void:
	if body is Player:
		print("[FINALE] Daylight reached! Mountain sealed behind Mara. Transitioning to Epilogue & Credits.")
		MissionManager.complete_objective("obj_finale_escape")
		if hud:
			hud.show_subtitle("Tomas", "\"Tomas: Mara! Grab my hand! I've got you!\"", 3.5)
			await get_tree().create_timer(3.5).timeout
			hud.show_subtitle("Mara", "\"Never again...\"", 3.0)
			
		await get_tree().create_timer(4.0).timeout
		GameManager.load_chapter(12, "res://levels/Epilogue.tscn")
