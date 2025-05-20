class_name SDFShapes

static func get_sphere_value(position: Vector3, radius: float, sample_location: Vector3i) -> float:
	var distance_value = position.distance_to(sample_location)
	distance_value -= radius
	return distance_value