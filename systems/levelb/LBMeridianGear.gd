extends Node
## Equips a Meridian mercenary (scenes/EnemyMercenary.tscn) with phase-2 gear on
## BoneAttachment3D nodes: helmet -> Head, rifle -> R_Hand, vest / radio pack -> Spine02.
## Variants: "rifleman", "heavy", "radio". Add as a child of the enemy; it waits for
## ProductionCharacter to build the skeleton.

const M := "res://assets/models/meridian/lod/"
const HELMET := M + "mer_tactical_helmet_nvg_LOD0.glb"
const RIFLE := M + "mer_assault_rifle_LOD0.glb"
const VEST := M + "mer_heavy_armor_vest_LOD0.glb"
const RADIO := M + "mer_radio_backpack_LOD0.glb"
const KIT := preload("res://systems/levelb/LBKit.gd")

@export_enum("rifleman", "heavy", "radio") var variant := "rifleman"

static func equip(enemy: Node, p_variant: String) -> void:
	var g := new()
	g.name = "MeridianGear"
	g.variant = p_variant
	enemy.add_child(g)

func _ready() -> void:
	var enemy := get_parent()
	var skel: Skeleton3D = null
	for i in 30:
		await get_tree().process_frame
		var found := enemy.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skel = found[0]
			break
	if skel == null:
		return
	# ProductionCharacter now equips its own gear variants (Gear_helmet / Gear_rifle / ...).
	# Adding ours on top doubled every helmet and rifle, so defer to it when present.
	await get_tree().process_frame
	if not skel.find_children("Gear_*", "BoneAttachment3D", false, false).is_empty():
		return
	# Sizes in metres at character scale (character ~1.82 m).
	var s := skel.global_transform.basis.get_scale().x
	_attach(skel, "Head", HELMET, 0.3, Vector3(0, 0.08, 0.01), Vector3.ZERO, s)
	_attach(skel, "R_Hand", RIFLE, 0.95, Vector3(0.02, -0.04, 0.2), Vector3(0, -PI / 2, 0), s)
	if variant == "heavy":
		_attach(skel, "Spine02", VEST, 0.62, Vector3(0, -0.12, 0.0), Vector3.ZERO, s)
	elif variant == "radio":
		_attach(skel, "Spine02", RADIO, 0.55, Vector3(0, -0.05, -0.17), Vector3.ZERO, s)
	# Fabric tint per variant (one base mesh, three silhouettes).
	var tint: Color = {"rifleman": Color(0.85, 0.85, 0.85), "heavy": Color(0.55, 0.58, 0.55), "radio": Color(0.8, 0.75, 0.62)}[variant]
	for mi in enemy.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() is BoneAttachment3D or mi.get_meta("gear", false):
			continue
		var src := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if src:
			var m := src.duplicate() as StandardMaterial3D
			m.albedo_color = src.albedo_color * tint
			(mi as MeshInstance3D).material_override = m

func _attach(skel: Skeleton3D, bone: String, path: String, size: float, offset: Vector3, rot: Vector3, skel_scale: float) -> void:
	if skel.find_bone(bone) < 0 or not ResourceLoader.exists(path):
		return
	var ba := BoneAttachment3D.new()
	ba.name = "Gear_" + bone
	ba.bone_name = bone
	skel.add_child(ba)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / maxf(skel_scale, 0.001)
	holder.position = offset / maxf(skel_scale, 0.001)
	holder.rotation = rot
	ba.add_child(holder)
	var piece := KIT.place(holder, path, Vector3.ZERO, size, 0.0, Vector3.ONE, false)
	if piece:
		var b := KIT.model_bounds(path)
		piece.position -= piece.basis * Vector3(0, b.size.y * 0.5, 0) # centre on the bone
		piece.set_meta("collision", "none")
		for mi in piece.find_children("*", "MeshInstance3D", true, false):
			mi.set_meta("gear", true)
			mi.set_meta("collision", "none")
