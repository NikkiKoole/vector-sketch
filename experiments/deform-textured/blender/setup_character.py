"""
Blender Setup Script — creates a textured plane + armature for 2D skeletal mesh deformation.

Usage:
  1. Open Blender 4.x
  2. Open this script in the Scripting workspace (or Text Editor)
  3. Click "Run Script"
  4. Switch to the 3D Viewport — you'll see the character on a subdivided plane with bones

After running:
  - Select the plane, go to Weight Paint mode (Ctrl+Tab) to paint bone weights
  - Select a bone from the vertex group list to paint its influence
  - When done: File > Export > Lua Scene (.lua) using the RNavega exporter

Install the exporter first:
  Edit > Preferences > Add-ons > Install > select io_scene_lua.py
"""

import bpy
import os

# ─── Config ──────────────────────────────────────────────────────────────────
IMAGE_PATH = os.path.join(os.path.dirname(bpy.data.filepath) if bpy.data.filepath else os.path.expanduser("~/Desktop"), "oldman.png")
# Try a few locations for the image
for candidate in [
    IMAGE_PATH,
    os.path.expanduser("~/Desktop/oldman.png"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "oldman.png") if "__file__" in dir() else "",
    os.path.expanduser("~/Projects/love/vector-sketch/experiments/deform-textured/oldman.png"),
]:
    if candidate and os.path.exists(candidate):
        IMAGE_PATH = candidate
        break

SUBDIVISIONS = 20  # grid subdivisions for the mesh (more = smoother deformation)

# Image dimensions (will be read from file if possible)
IMG_W, IMG_H = 700, 679

# ─── Clear scene ─────────────────────────────────────────────────────────────
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# Clean up orphan data
for block in bpy.data.meshes:
    if block.users == 0:
        bpy.data.meshes.remove(block)
for block in bpy.data.materials:
    if block.users == 0:
        bpy.data.materials.remove(block)
for block in bpy.data.images:
    if block.users == 0:
        bpy.data.images.remove(block)

# ─── Load image ──────────────────────────────────────────────────────────────
if os.path.exists(IMAGE_PATH):
    img = bpy.data.images.load(IMAGE_PATH)
    IMG_W, IMG_H = img.size[0], img.size[1]
    print(f"Loaded image: {IMAGE_PATH} ({IMG_W}x{IMG_H})")
else:
    img = None
    print(f"WARNING: Image not found at {IMAGE_PATH}")
    print("  You can set the image manually on the material after the script runs.")

# Scale to reasonable Blender units (1 pixel = 0.01 Blender units)
SCALE = 0.01
W = IMG_W * SCALE
H = IMG_H * SCALE

# ─── Create subdivided plane ─────────────────────────────────────────────────
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
plane = bpy.context.active_object
plane.name = "CharacterMesh"

# Scale to image proportions
plane.scale = (W, H, 1)
bpy.ops.object.transform_apply(scale=True)

# Subdivide for smooth deformation
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.subdivide(number_cuts=SUBDIVISIONS)
bpy.ops.object.mode_set(mode='OBJECT')

# ─── UV unwrap (project from view, top-down) ────────────────────────────────
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.project_from_view(
    camera_bounds=False,
    correct_aspect=True,
    scale_to_bounds=True
)
bpy.ops.object.mode_set(mode='OBJECT')

# ─── Material with image texture ────────────────────────────────────────────
mat = bpy.data.materials.new(name="CharacterMat")
mat.use_nodes = True
plane.data.materials.append(mat)

nodes = mat.node_tree.nodes
links = mat.node_tree.links
nodes.clear()

# Output node
output_node = nodes.new('ShaderNodeOutputMaterial')
output_node.location = (300, 0)

# Principled BSDF
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.location = (0, 0)
links.new(bsdf.outputs['BSDF'], output_node.inputs['Surface'])

# Image texture
if img:
    tex_node = nodes.new('ShaderNodeTexImage')
    tex_node.image = img
    tex_node.location = (-300, 0)
    links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(tex_node.outputs['Alpha'], bsdf.inputs['Alpha'])
    mat.blend_method = 'CLIP' if hasattr(mat, 'blend_method') else None

# ─── Create armature ────────────────────────────────────────────────────────
# All positions in Blender units (pixels * SCALE), relative to plane center.
# The plane center is at origin, so image coords need to be offset by -W/2, -H/2.
# Also: Blender Y is depth, Z is up in 3D. For 2D work on XY plane:
#   image X → Blender X
#   image Y → Blender -Z (Y goes down in image, Z goes up in Blender)
# But since we're working flat on the XY plane viewed from top:
#   image X → Blender X
#   image Y → Blender -Y (flip vertical)

def img_to_blender(ix, iy):
    """Convert image pixel coords to Blender world coords on the XY plane."""
    return ((ix - IMG_W/2) * SCALE, (IMG_H/2 - iy) * SCALE, 0)

bpy.ops.object.armature_add(location=(0, 0, 0))
armature_obj = bpy.context.active_object
armature_obj.name = "CharacterArmature"
armature = armature_obj.data
armature.name = "CharacterArmatureData"

# Switch to edit mode to add bones
bpy.ops.object.mode_set(mode='EDIT')

# Remove the default bone
armature.edit_bones.remove(armature.edit_bones[0])

# Bone definitions: (name, head_img_xy, tail_img_xy, parent_name)
# Positions estimated for the oldman T-pose image (700x679)
bone_defs = [
    ("Torso",      (350, 340), (350, 170), None),
    ("Head",       (350, 170), (350, 40),  "Torso"),
    ("LUpperArm",  (265, 178), (130, 178), "Torso"),
    ("LLowerArm",  (130, 178), (20,  178), "LUpperArm"),
    ("RUpperArm",  (435, 178), (570, 178), "Torso"),
    ("RLowerArm",  (570, 178), (680, 178), "RUpperArm"),
    ("LUpperLeg",  (305, 385), (290, 520), "Torso"),
    ("LLowerLeg",  (290, 520), (275, 640), "LUpperLeg"),
    ("RUpperLeg",  (395, 385), (410, 520), "Torso"),
    ("RLowerLeg",  (410, 520), (425, 640), "RUpperLeg"),
]

for name, head_px, tail_px, parent_name in bone_defs:
    bone = armature.edit_bones.new(name)
    bone.head = img_to_blender(*head_px)
    bone.tail = img_to_blender(*tail_px)
    bone.use_deform = True
    if parent_name:
        bone.parent = armature.edit_bones[parent_name]
        bone.use_connect = False  # don't force-connect to parent tail

bpy.ops.object.mode_set(mode='OBJECT')

# ─── Parent mesh to armature with automatic weights ─────────────────────────
# Select plane first, then armature, and parent with auto weights
plane.select_set(True)
armature_obj.select_set(True)
bpy.context.view_layer.objects.active = armature_obj
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

# ─── Set up viewport ────────────────────────────────────────────────────────
# Switch to top-down view for 2D work
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.region_3d.view_perspective = 'ORTHO'
                space.region_3d.view_rotation = (1, 0, 0, 0)  # top-down
                space.shading.type = 'MATERIAL'  # show texture
        break

print("=" * 60)
print("Setup complete!")
print(f"  Mesh: {plane.name} ({len(plane.data.vertices)} vertices)")
print(f"  Armature: {armature_obj.name} ({len(bone_defs)} bones)")
print(f"  Auto-weights applied.")
print()
print("Next steps:")
print("  1. Numpad 7 for top-down view, Numpad 5 for orthographic")
print("  2. Select CharacterMesh, Ctrl+Tab for Weight Paint mode")
print("  3. Select bones from vertex group list to paint weights")
print("  4. Install io_scene_lua.py: Edit > Preferences > Add-ons > Install")
print("  5. Export: File > Export > Lua Scene (.lua)")
print("=" * 60)
