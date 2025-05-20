class_name Array3D

var values: PackedFloat32Array
var count: int
var width: int
var height: int
var depth: int

func _init(w: int, h: int, d: int) -> void:
	count = w * h * d
	width = w
	height = h
	depth = d
	values.resize(count)

# Scalar value Getters/Setters
func read_at_coord(x: int, y: int, z: int) -> float:
	return values[x + (y * width) + (z * width * height)]
func read_at_index(index:int) -> float:
	return values[index]
func write_at_coord(x: int, y: int, z: int, scalar: float) -> void:
	values[x + (y * width) + (z * width * height)] = scalar
func write_at_index(index:int, scalar: float) -> void:
	values[index] = scalar
