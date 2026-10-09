extends RefCounted
## Builds a PhysicalBoneSimulator3D ragdoll at runtime for the shared 41-bone Tripo biped
## and starts simulating it (death stand-in: Tripo has no death clip).

const CHAIN := {
	# bone: [child bone that defines its length, radius (m), joint]
	"Hip": ["Spine01", 0.13, PhysicalBone3D.JOINT_TYPE_NONE],
	"Spine01": ["Spine02", 0.12, PhysicalBone3D.JOINT_TYPE_CONE],
	"Spine02": ["Head", 0.14, PhysicalBone3D.JOINT_TYPE_CONE],
	"Head": ["", 0.11, PhysicalBone3D.JOINT_TYPE_CONE],
	"L_Thigh": ["L_Calf", 0.08, PhysicalBone3D.JOINT_TYPE_CONE],
	"L_Calf": ["L_Foot", 0.06, PhysicalBone3D.JOINT_TYPE_HINGE],
	"R_Thigh": ["R_Calf", 0.08, PhysicalBone3D.JOINT_TYPE_CONE],
	"R_Calf": ["R_Foot", 0.06, PhysicalBone3D.JOINT_TYPE_HINGE],
	"L_Upperarm": ["L_Forearm", 0.05, PhysicalBone3D.JOINT_TYPE_CONE],
	"L_Forearm": ["L_Hand", 0.045, PhysicalBone3D.JOINT_TYPE_HINGE],
	"R_Upperarm": ["R_Forearm", 0.05, PhysicalBone3D.JOINT_TYPE_CONE],
	"R_Forearm": ["R_Hand", 0.045, PhysicalBone3D.JOINT_TYPE_HINGE],
}

## Returns the simulator (or null). `impulse` is applied to the hips in world space.
static func start(skeleton: Skeleton3D, impulse := Vector3.ZERO, world_mask := 2) -> PhysicalBoneSimulator3D:
	if not skeleton:
		return null
	var existing := skeleton.get_node_or_null("Ragdoll") as PhysicalBoneSimulator3D
	if existing:
		return existing
	# Bodies are created in skeleton space; physics engines need a uniform scale there.
	var world_scale := skeleton.global_basis.get_scale().x
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skeleton.add_child(sim)
	var hips: PhysicalBone3D = null
	for bone_name in CHAIN:
		var idx := skeleton.find_bone(bone_name)
		if idx < 0:
			continue
		var spec: Array = CHAIN[bone_name]
		var pose := skeleton.get_bone_global_pose(idx)
		var tip := pose.origin + pose.basis.y.normalized() * 0.12 / world_scale
		if spec[0] != "" and skeleton.find_bone(spec[0]) >= 0:
			tip = skeleton.get_bone_global_pose(skeleton.find_bone(spec[0])).origin
		var axis := tip - pose.origin
		var length := maxf(axis.length(), 0.02)
		var y := axis.normalized() if axis.length() > 0.0001 else Vector3.UP
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var body_xform := Transform3D(Basis(x, y, x.cross(y)).orthonormalized(), (pose.origin + tip) * 0.5)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.joint_type = spec[2]
		pb.collision_layer = 0
		pb.collision_mask = world_mask
		pb.mass = 4.0 if bone_name in ["Hip", "Spine01", "Spine02"] else 1.5
		pb.linear_damp = 0.3
		pb.angular_damp = 2.0
		pb.body_offset = pose.affine_inverse() * body_xform
		_limit_joint(pb, bone_name, y)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		var radius: float = spec[1] / world_scale
		capsule.radius = radius
		capsule.height = maxf(length, radius * 2.05)
		shape.shape = capsule
		pb.add_child(shape)
		sim.add_child(pb)
		if bone_name == "Hip":
			hips = pb
	sim.physical_bones_start_simulation()
	if hips and impulse != Vector3.ZERO:
		hips.apply_central_impulse(impulse)
	return sim

## Joint limits (radians). Cones: swing/twist span. Hinges: knees and elbows only bend one way.
## Hinge axis = joint frame Z = body z (lateral for legs). T-pose arms lie along the lateral
## axis, so the elbow frame is rotated to hinge around the vertical axis instead.
const LIMITS := {
	"Spine01": [0.35, 0.25], "Spine02": [0.35, 0.25], "Head": [0.6, 0.6],
	"L_Thigh": [1.1, 0.3], "R_Thigh": [1.1, 0.3],
	"L_Upperarm": [1.4, 0.6], "R_Upperarm": [1.4, 0.6],
}
const HINGES := {"L_Calf": [-2.3, 0.0], "R_Calf": [-2.3, 0.0], "L_Forearm": [0.0, 2.2], "R_Forearm": [0.0, -2.2]}

static func _limit_joint(pb: PhysicalBone3D, bone_name: String, bone_axis: Vector3) -> void:
	if LIMITS.has(bone_name):
		pb.set("joint_constraints/swing_span", rad_to_deg(LIMITS[bone_name][0]))
		pb.set("joint_constraints/twist_span", rad_to_deg(LIMITS[bone_name][1]))
		pb.set("joint_constraints/softness", 0.8)
		pb.set("joint_constraints/relaxation", 1.0)
	elif HINGES.has(bone_name):
		var lim: Array = HINGES[bone_name]
		if bone_name.ends_with("Forearm") and absf(bone_axis.y) < 0.6:
			pb.joint_rotation = Vector3(0, PI * 0.5, 0)
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_lower", rad_to_deg(minf(lim[0], lim[1])))
		pb.set("joint_constraints/angular_limit_upper", rad_to_deg(maxf(lim[0], lim[1])))
		pb.set("joint_constraints/angular_limit_softness", 0.9)
		pb.set("joint_constraints/angular_limit_relaxation", 1.0)