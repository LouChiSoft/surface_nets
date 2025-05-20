class_name TerrainChunk extends MeshInstance3D

# Cube layout
#
#     v2-------v3
#    /|        /|
#   v6+-------v7|
#   | |       | |
#   | v0------+-v1
#   |/        |/
#   v4--------v5
#
# Edge pairs are specifically indexed to have the lower value on the axis in the X component
# and the higher value in the Y componenet. This is so that the for loop for calculating exponents
# is easier
const EDGE_PAIRS = [
	Vector2i(0,1), Vector2i(1,5), Vector2i(4,5), Vector2i(0,4), # Bottom Faces 
	Vector2i(0,2), Vector2i(1,3), Vector2i(5,7), Vector2i(4,6), # Verticals
	Vector2i(2,3), Vector2i(3,7), Vector2i(6,7), Vector2i(2,6), # Top Faces
]

@export var resolution: int
@export var dimension: float
@export var show_debug_points: bool = false

var _scalar_field: Array3D
var _scalar_positions: Vector3Array3D
var _surface_positions: Array[Vector3]
var _indices: Array[int]
var _voxels: VoxelArray3D
var _voxel_size: float


func _ready() -> void:
	_prep_vars()
	_populate_scalar_field()
	_calculate_surface_positions()
	_extract_mesh()
	
	var array_mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(_surface_positions)
	arrays[Mesh.ARRAY_INDEX]  = PackedInt32Array(_indices)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh


func  _prep_vars() -> void:
	_scalar_field = Array3D.new(resolution, resolution, resolution)
	_scalar_positions = Vector3Array3D.new(resolution, resolution, resolution)
	_voxels = VoxelArray3D.new(resolution - 1, resolution - 1, resolution - 1)
	_voxel_size = dimension/(resolution - 1)

func _populate_scalar_field() -> void:
	# Populate vertex array
	var minimum_position: Vector3
	minimum_position.x = -(dimension/2)
	minimum_position.y = -(dimension/2)
	minimum_position.z = -(dimension/2)
	
	for z in range(resolution):
		for y in range(resolution):
			for x in range(resolution):
				var x_pos = minimum_position.x + (x * _voxel_size)
				var y_pos = minimum_position.y + (y * _voxel_size)
				var z_pos = minimum_position.z + (z * _voxel_size)
				var vertex_position = Vector3(x_pos, y_pos, z_pos)
					
				var scalar_value = SDFShapes.get_sphere_value(Vector3.ZERO, 10, vertex_position)
				_scalar_field.write_at_coord(x, y, z, scalar_value)
				_scalar_positions.write_at_coord(x, y, z, vertex_position)

func _calculate_surface_positions() -> void:
	# Get the scalar values for each corner of the voxel
	var corners: PackedFloat32Array
	corners.resize(8)
	var positions: PackedVector3Array
	positions.resize(8)
	
	# Loop over each voxel, calculate if there are any
	# intersecting edges, if so calculate average of all
	# intersecting edges and store the surface value in 
	# in the _surface_values array and store the index of
	# surface value in the array inside the voxel itself
	# for mesh generation later on
	for z in range(resolution - 1):
		for y in range(resolution - 1):
			for x in range(resolution - 1):
				corners[0] = _scalar_field.read_at_coord(x, y, z)
				corners[1] = _scalar_field.read_at_coord(x + 1, y, z)
				corners[2] = _scalar_field.read_at_coord(x, y + 1, z)
				corners[3] = _scalar_field.read_at_coord(x + 1, y + 1, z)
				corners[4] = _scalar_field.read_at_coord(x, y, z + 1)
				corners[5] = _scalar_field.read_at_coord(x + 1, y, z + 1)
				corners[6] = _scalar_field.read_at_coord(x, y + 1, z + 1)
				corners[7] = _scalar_field.read_at_coord(x + 1, y + 1, z + 1)
				
				positions[0] = _scalar_positions.read_at_coord(x, y, z)
				positions[1] = _scalar_positions.read_at_coord(x + 1, y, z)
				positions[2] = _scalar_positions.read_at_coord(x, y + 1, z)
				positions[3] = _scalar_positions.read_at_coord(x + 1, y + 1, z)
				positions[4] = _scalar_positions.read_at_coord(x, y, z + 1)
				positions[5] = _scalar_positions.read_at_coord(x + 1, y, z + 1)
				positions[6] = _scalar_positions.read_at_coord(x, y + 1, z + 1)
				positions[7] = _scalar_positions.read_at_coord(x + 1, y + 1, z + 1)
				
				var intersecting_positions: Array[Vector3]
				for edge in EDGE_PAIRS:
					if corners[edge.x] * corners[edge.y] < 0:
						var p1 = positions[edge.x]
						var p2 = positions[edge.y]
						var t = corners[edge.x] / (corners[edge.x] - corners[edge.y])
						var ps = p1.lerp(p2, t)
						intersecting_positions.append(ps)
						

				var avg_pos := Vector3.ZERO
				var new_voxel: Voxel = Voxel.new()
				if intersecting_positions.size() > 0:
					new_voxel.index = _surface_positions.size()
					for ip in intersecting_positions:
						avg_pos += ip
					avg_pos /= intersecting_positions.size()
				
				# Check the direction of the intersecting edges
				if corners[0] * corners[1] < 0:
					if corners[0] < corners[1]:
						new_voxel.x_intersection = 1
					else:
						new_voxel.x_intersection = -1
				
				if corners[0] * corners[2] < 0:
					if corners[0] < corners[2]:
						new_voxel.y_intersection = 1
					else:
						new_voxel.y_intersection = -1
				
				if corners[0] * corners[4] < 0:
					if corners[0] < corners[4]:
						new_voxel.z_intersection = 1
					else:
						new_voxel.z_intersection = -1
				
				_surface_positions.append(avg_pos)
				_voxels.write_at_coord(x, y, z, new_voxel)

func _extract_mesh() -> void:
	var max_i := resolution - 1  # voxels go 0 .. max_i-1
	
	for z in range(max_i):
		for y in range(max_i):
			for x in range(max_i):
				var v := _voxels.read_at_coord(x, y, z)

				# ——— X-edge (v0→v1) ———
				# these four voxels share that grid‐edge:
				#    (x,  y,  z)
				#    (x,  y-1,z)
				#    (x,  y-1,z-1)
				#    (x,  y,  z-1)
				if v.x_intersection != 0 and y > 0 and z > 0:
					_add_quad(
						Vector3i(x,   y,   z),
						Vector3i(x,   y-1, z),
						Vector3i(x,   y-1, z-1),
						Vector3i(x,   y,   z-1),
						v.x_intersection
					)

				# ——— Y-edge (v0→v2) ———
				# four voxels:
				#    (x,  y,  z)
				#    (x-1,y,  z)
				#    (x-1,y,  z-1)
				#    (x,  y,  z-1)
				if v.y_intersection != 0 and x > 0 and z > 0:
					_add_quad(
						Vector3i(x-1, y,   z),
						Vector3i(x,   y,   z),
						Vector3i(x,   y,   z-1),
						Vector3i(x-1, y,   z-1),
						v.y_intersection
					)

				# ——— Z-edge (v0→v4) ———
				# four voxels:
				#    (x,  y,  z)
				#    (x-1,y,  z)
				#    (x-1,y-1,z)
				#    (x,  y-1,z)
				if v.z_intersection != 0 and x > 0 and y > 0:
					_add_quad(
						Vector3i(x-1, y-1, z),
						Vector3i(x,   y-1, z),
						Vector3i(x,   y,   z),
						Vector3i(x-1, y,   z),
						v.z_intersection
					)
	pass
	
func _add_quad(c0: Vector3i, c1: Vector3i, c2: Vector3i, c3: Vector3i, dir: int) -> void:
	# look up each cell’s precomputed vertex index
	var i0 = _voxels.read_at_coord(c0.x, c0.y, c0.z).index
	var i1 = _voxels.read_at_coord(c1.x, c1.y, c1.z).index
	var i2 = _voxels.read_at_coord(c2.x, c2.y, c2.z).index
	var i3 = _voxels.read_at_coord(c3.x, c3.y, c3.z).index

	if dir < 0:
		# standard winding
		_indices.append_array([i0, i1, i2,   i0, i2, i3])
	else:
		# flip two verts to flip normal
		_indices.append_array([i0, i2, i1,   i0, i3, i2])



func _process(_delta: float) -> void:
	if show_debug_points:
		_draw_debug_points()

func _draw_debug_points():
	var minimum_position: Vector3
	minimum_position.x = -(dimension/2)
	minimum_position.y = -(dimension/2)
	minimum_position.z = -(dimension/2)
	
	for z in range(resolution):
		for y in range(resolution):
			for x in range(resolution):
				var x_pos = minimum_position.x + (x * _voxel_size)
				var y_pos = minimum_position.y + (y * _voxel_size)
				var z_pos = minimum_position.z + (z * _voxel_size)
				var vertex_position = Vector3(x_pos, y_pos, z_pos)
				
				var surface_value = _scalar_field.read_at_coord(x, y, z)
				
				if surface_value <= 0:
					DebugDraw3D.draw_sphere(vertex_position, 0.05, Color.GREEN)
				else:
					DebugDraw3D.draw_sphere(vertex_position, 0.05, Color.RED)
