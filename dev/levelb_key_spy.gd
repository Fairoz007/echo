extends Node
## QA-only: logs physical key presses that trigger GameManager save/load/pause shortcuts,
## so a campaign log shows whether a mid-route reload came from a real keypress. The key is
## consumed (GameManager reads these in _unhandled_input) so a stray press can't derail QA.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F5, KEY_F9, KEY_ESCAPE]:
		print("QA KEY SPY: physical key ", OS.get_keycode_string(event.keycode), " at t=", Time.get_ticks_msec(), " (blocked)")
		get_viewport().set_input_as_handled()
