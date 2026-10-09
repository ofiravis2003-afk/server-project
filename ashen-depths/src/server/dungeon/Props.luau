--!strict
-- Real 3D props for the dungeon (made with Studio's AI mesh generator, kept in ServerStorage.DungeonProps
-- and saved with the Depths place): Torch, Sarcophagus, Chest (with "Base" and "Lid"), BrokenPillar, BonePile.
-- Every builder asks here first and falls back to its plain parts when a prop is missing.

local ServerStorage = game:GetService("ServerStorage")

local Props = {}

function Props.Has(name: string): boolean
	local folder = ServerStorage:FindFirstChild("DungeonProps")
	local prop = folder and folder:FindFirstChild(name)
	return prop ~= nil and prop:IsA("Model")
end

-- Clones prop `name` into `parent`, standing with the bottom-center of its box on `cframe`
-- (and turned like `cframe`), optionally scaled. Returns nil if the prop doesn't exist.
function Props.Place(name: string, parent: Instance, cframe: CFrame, scale: number?): Model?
	local folder = ServerStorage:FindFirstChild("DungeonProps")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local prop = source:Clone()
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	if scale and scale ~= 1 then
		prop:ScaleTo(prop:GetScale() * scale)
	end
	prop:PivotTo(cframe)
	local box, size = prop:GetBoundingBox()
	local bottom = box.Position - Vector3.new(0, size.Y / 2, 0)
	prop:PivotTo(prop:GetPivot() + (cframe.Position - bottom))
	prop.Parent = parent
	return prop
end

return Props
