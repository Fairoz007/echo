extends RefCounted
class_name ChapterRecap

## Chapter-transition recaps for transition screens (narrated by Mara, field-journal voice).
## Key = the chapter that just ENDED (PRO, C01..C10, FIN). Text source of truth: COMPLETE_SCREENPLAY.md
## "CHAPTER TRANSITION RECAPS"; audio/subtitles come from audio/dialogue_manifest.json (REC_<KEY>).
##
##   var r := ChapterRecap.get_recap("C03")   # {id, text, path, duration, cues:[{start,end,text}]} or {}
##   var secs := ChapterRecap.play("C03", transition_screen)  # plays on Dialogue bus; returns duration
##   # transition_screen may implement show_subtitle(speaker, text, duration) (optional, else pass null)
##   ChapterRecap.stop()
static func get_recap(chapter_key: String) -> Dictionary:
	var id := "REC_%s" % chapter_key
	var entry: Dictionary = AudioManager.dialogue_catalog.get(id, {})
	if entry.is_empty():
		return {}
	var out := entry.duplicate()
	out["id"] = id
	return out

static func play(chapter_key: String, hud: Node = null) -> float:
	var r := get_recap(chapter_key)
	if r.is_empty():
		return 0.0
	return AudioManager.play_dialogue(r["id"], hud, "Mara", r.get("text", ""), float(r.get("duration", 6.0)))

static func stop() -> void:
	AudioManager.stop_dialogue()
