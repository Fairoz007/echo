extends "res://systems/FoliageWind.gd"
## Level B foliage wind: the same tiered wind shader (shaders/foliage_wind.gdshader,
## driven by WindSystem) as FoliageWind, but
##  - accepts Tripo materials without a normal/ORM map (phase-2 jungle set),
##  - uses a stronger amplitude so motion reads at gameplay distance.
## (Base FoliageWind now also animates on every preset; quality = wind_detail uniform.)

const BOOST := {"tree": 2.2, "fern": 2.6}

func configure(plant: Node3D, height: float, base_y: float, profile := "") -> void:
	if profile == "":
		profile = "tree" if height > 2.0 else "fern"
	amplitude = BOOST.get(profile, 2.0)
	super.configure(plant, height, base_y, profile)

func _accepts(original: StandardMaterial3D) -> bool:
	return original != null and original.albedo_texture != null and original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
