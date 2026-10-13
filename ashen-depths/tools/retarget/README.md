# Mixamo → R15 retarget (for player animations)

1. Download from Mixamo on the **X Bot** character: FBX, 30 fps, "Without Skin" (packs: Pose "No Character").
2. Retarget in background Blender (Microsoft Store install):
   `%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe -b --factory-startup --python retarget.py -- <clip.fbx> <clip.json> [inplace]`
   (no console output — wait for the JSON file to appear).
3. `python to_lua.py <clip.json> <Name> <clip.luau> [step] [loop]` → a Luau snippet; run it in Studio (MCP) to build
   `ServerStorage.R15Clips.<Name>` (a KeyframeSequence), then right-click → Save to Roblox for the animation id.

How it works: each R15 part follows one Mixamo bone's world rotation (Hips→LowerTorso, Spine2→UpperTorso,
Head, Arm/ForeArm/Hand, UpLeg/Leg/Foot). A fixed offset per part swings R15's rest pose (arms down) into
Mixamo's T-pose first, so the arm deltas line up. Hips height changes come through on the Root joint
(scaled so 1 Mixamo hip height = 2.19 studs); `inplace` drops the hips' sideways travel.
Axes: Blender (Z up, facing -Y) → Roblox (Y up, facing -Z): (x, y, z) → (-x, z, y).
