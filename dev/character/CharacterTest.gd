extends "res://dev/MovementTestCourse.gd"
## DEV ONLY character test scene: reuses the movement course (flat ground, rocks, slopes,
## stairs, climbable wall, pool) and adds a waist-high lever for the interact reach.

var lever: Interactable3D

func _ready() -> void:
	super._ready()
	var z: float = LANE.flat + 3.0
	_box("LeverPost", Vector3(0.3, 1.0, 0.3), _at(Vector3(1.2, 0.5, z)), Color(0.6, 0.5, 0.3))
	lever = Interactable3D.new()
	lever.name = "Lever"
	lever.prompt_message = "Pull lever"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	lever.add_child(shape)
	lever.position = Vector3(1.2, 1.05, z)
	add_child(lever)
	_label("lever", Vector3(1.2, 2.0, z))
