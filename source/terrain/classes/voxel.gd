class_name Voxel
# Index to be used with a vertex list 
var index: int = -1 
# Since we only need to check the axes connected to v0 of
# the voxel we can track them with vars. 1 means that there is
# is an intersecting edge going up the axis, -1 means that there
# is an intersecting edge going down the axis and finally 0
# means that there isn't an intersecting edge
var x_intersection: int = 0
var y_intersection: int = 0
var z_intersection: int = 0
