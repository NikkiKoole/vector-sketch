# Godot → LÖVE2D Skeleton Export Pipeline

## Setup in Godot 4.x

1. Create new project, add your character PNG to the project folder

2. Build the scene tree:
   ```
   Node2D (root) — attach export_skeleton.gd here
   ├── Skeleton2D
   │   └── Torso (Bone2D)
   │       ├── Head (Bone2D)
   │       ├── LUpperArm (Bone2D)
   │       │   └── LLowerArm (Bone2D)
   │       ├── RUpperArm (Bone2D)
   │       │   └── RLowerArm (Bone2D)
   │       ├── LUpperLeg (Bone2D)
   │       │   └── LLowerLeg (Bone2D)
   │       └── RUpperLeg (Bone2D)
   │           └── RLowerLeg (Bone2D)
   └── Polygon2D — set texture, draw mesh, paint weights
   ```

3. Select Polygon2D, set its **Texture** to your PNG

4. Select Polygon2D, click **"UV"** button at bottom of viewport:
   - **Points tab**: draw outline around character (click to place vertices)
   - Add internal vertices with the pencil tool for smoother deformation
   - **Polygons tab**: click "Triangulate" to auto-generate triangles
   - **Bones tab**: select each bone, paint weights with brush

5. Select Skeleton2D, click **"Set Rest Pose"** in the 2D toolbar

6. Run the scene (F5) — it exports `skeleton_export.json`

7. Copy the JSON + your PNG to the LÖVE experiment folder

## Export format (skeleton_export.json)

```json
{
  "bones": [
	{"name": "Torso", "index": 0, "parent": -1, "rest_position": {...}, "rest_rotation": 0, "length": 80},
	{"name": "Head", "index": 1, "parent": 0, ...}
  ],
  "vertices": [{"x": 10, "y": 20}, ...],
  "uvs": [{"u": 0.1, "v": 0.2}, ...],
  "triangles": [0, 1, 2, 1, 2, 3, ...],
  "bone_weights": [
	{"bone_name": "Torso", "bone_index": 0, "weights": [0.8, 0.2, 0, ...]},
	...
  ],
  "texture": {"path": "res://character.png", "width": 700, "height": 679}
}
```
