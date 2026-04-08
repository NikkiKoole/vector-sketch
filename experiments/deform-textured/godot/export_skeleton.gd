@tool
extends Node2D

## Exports Polygon2D mesh + Skeleton2D bones + weights to JSON for LÖVE2D.
## Attach to root Node2D, then run the scene or call export_to_json() from editor.

@export var output_path: String = "res://skeleton_export.json"

func _ready():
	export_to_json()
	print("Export complete: ", output_path)

func export_to_json():
	var skeleton: Skeleton2D = _find_child_of_type("Skeleton2D")
	var polygon: Polygon2D = _find_child_of_type("Polygon2D")

	if not skeleton or not polygon:
		push_error("Need both Skeleton2D and Polygon2D nodes as children")
		return

	var data = {}

	# Export bones
	var bones_data = []
	for i in skeleton.get_bone_count():
		var bone = skeleton.get_bone(i)
		var rest = bone.rest
		var parent_idx = -1
		if bone.get_parent() is Bone2D:
			for j in skeleton.get_bone_count():
				if skeleton.get_bone(j) == bone.get_parent():
					parent_idx = j
					break
		bones_data.append({
			"name": bone.name,
			"index": i,
			"parent": parent_idx,
			"rest_position": {"x": rest.origin.x, "y": rest.origin.y},
			"rest_rotation": rest.get_rotation(),
			"length": bone.get_length(),
		})
	data["bones"] = bones_data

	# Export mesh vertices and UVs
	var vertices = []
	var polygon_points = polygon.polygon  # PackedVector2Array
	for p in polygon_points:
		vertices.append({"x": p.x, "y": p.y})
	data["vertices"] = vertices

	var uvs = []
	var uv_points = polygon.uv  # PackedVector2Array
	for p in uv_points:
		uvs.append({"u": p.x, "v": p.y})
	data["uvs"] = uvs

	# Export triangles (polygon indices)
	# Polygon2D uses internal_vertices + polygons for triangulation
	var polygons_arr = polygon.polygons  # Array of PackedInt32Array
	var triangles = []
	if polygons_arr.size() > 0:
		for poly in polygons_arr:
			for idx in poly:
				triangles.append(idx)
	else:
		# Fallback: use the polygon points as a fan
		for i in range(1, polygon_points.size() - 1):
			triangles.append(0)
			triangles.append(i)
			triangles.append(i + 1)
	data["triangles"] = triangles

	# Export bone weights
	# Polygon2D stores weights per bone in the bones property
	var bone_weights = []
	var bone_count = polygon.get_bone_count()
	for bi in bone_count:
		var bone_path = polygon.get_bone_path(bi)
		var weights = polygon.get_bone_weights(bi)  # PackedFloat32Array
		var bone_name = polygon.get_node(bone_path).name if polygon.has_node(bone_path) else str(bone_path)
		# Find the skeleton bone index
		var skel_idx = -1
		for si in skeleton.get_bone_count():
			if skeleton.get_bone(si).name == bone_name:
				skel_idx = si
				break
		var w_arr = []
		for w in weights:
			w_arr.append(w)
		bone_weights.append({
			"bone_name": bone_name,
			"bone_index": skel_idx,
			"weights": w_arr,
		})
	data["bone_weights"] = bone_weights

	# Export texture info
	if polygon.texture:
		data["texture"] = {
			"path": polygon.texture.resource_path,
			"width": polygon.texture.get_width(),
			"height": polygon.texture.get_height(),
		}

	# Export polygon transform
	data["polygon_offset"] = {"x": polygon.offset.x, "y": polygon.offset.y}
	data["polygon_position"] = {"x": polygon.position.x, "y": polygon.position.y}

	# Write JSON
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

func _find_child_of_type(type_name: String):
	for child in get_children():
		if child.get_class() == type_name:
			return child
		# Also check by script/type name
		if type_name == "Skeleton2D" and child is Skeleton2D:
			return child
		if type_name == "Polygon2D" and child is Polygon2D:
			return child
	return null
