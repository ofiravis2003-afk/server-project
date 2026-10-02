--!strict
-- Builds a speckled egg Model for an egg type. Pivot is at the bottom of the egg.
-- Used by the egg shop, the hatch screen and (later) the nests on the island.

local Eggs = require(script.Parent.Eggs)

local EGG_SIZE = Vector3.new(2.4, 3.1, 2.4)

-- Fixed spot layout (angle around, angle from top) so every egg of a type looks the same.
local SPOTS = {
	{ 0.3, 0.9 },
	{ 1.4, 1.3 },
	{ 2.3, 0.7 },
	{ 3.1, 1.7 },
	{ 4.0, 1.1 },
	{ 4.9, 1.9 },
	{ 5.6, 0.8 },
	{ 0.9, 2.2 },
	{ 2.8, 2.4 },
	{ 5.2, 2.5 },
}

local EggBuilder = {}

local function newPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = model
	return part
end

function EggBuilder.Build(eggId: string): Model
	local egg = Eggs.Get(eggId)
	assert(egg, `Unknown egg {eggId}`)

	local model = Instance.new("Model")
	model.Name = egg.Name

	local center = Vector3.new(0, EGG_SIZE.Y / 2, 0)
	local shell = newPart(model, "Shell", EGG_SIZE, CFrame.new(center), egg.Color)
	shell.Reflectance = 0.05

	local radii = EGG_SIZE / 2
	for _, spot in SPOTS do
		local around, fromTop = spot[1], spot[2]
		local direction =
			Vector3.new(math.cos(around) * math.sin(fromTop), math.cos(fromTop), math.sin(around) * math.sin(fromTop))
		local point = center + direction * radii
		-- The surface normal of an ellipsoid, so spots lie flat on the shell.
		local normal = Vector3.new(
			(point.X - center.X) / radii.X ^ 2,
			(point.Y - center.Y) / radii.Y ^ 2,
			(point.Z - center.Z) / radii.Z ^ 2
		).Unit
		local dot =
			newPart(model, "Spot", Vector3.new(0.55, 0.55, 0.12), CFrame.lookAt(point, point + normal), egg.SpotColor)
		if egg.Glow then
			dot.Material = Enum.Material.Neon
		end
	end

	if egg.Glow then
		local light = Instance.new("PointLight")
		light.Color = egg.SpotColor
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = shell
	end

	model.PrimaryPart = shell
	shell.PivotOffset = CFrame.new(0, -EGG_SIZE.Y / 2, 0)
	return model
end

return EggBuilder
