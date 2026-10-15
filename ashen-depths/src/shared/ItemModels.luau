--!strict
-- A small 3D model of any item, for pictures (the bag, the "New item!" card).
-- Weapons come from WeaponBuilder; materials and potions are made here from a few parts.

local WeaponBuilder = require(script.Parent.WeaponBuilder)
local Items = require(script.Parent.Items)

local ItemModels = {}

local function part(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local BONE = Color3.fromRGB(214, 204, 178)

local builders: { [string]: (Model) -> () } = {
	Bone = function(m)
		local tilt = CFrame.Angles(0, 0, math.rad(30))
		part(m, Vector3.new(2.4, 0.42, 0.42), tilt, BONE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for _, x in { -1.25, 1.25 } do
			for _, z in { -0.24, 0.24 } do
				part(m, Vector3.new(0.62, 0.62, 0.62), tilt * CFrame.new(x, 0, z), BONE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end,
	Fletching = function(m)
		local shaft = part(m, Vector3.new(0.1, 2.6, 0.1), CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(70, 52, 36), Enum.Material.Wood)
		for i, side in { -1, 1 } do
			local vane = part(m, Vector3.new(0.05, 1.1, 0.5), shaft.CFrame * CFrame.new(0, -0.8, 0) * CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, 0, side * 0.25), Color3.fromRGB(28, 26, 30), Enum.Material.Fabric)
			vane.Shape = Enum.PartType.Wedge
		end
		part(m, Vector3.new(0.05, 1.1, 0.5), shaft.CFrame * CFrame.new(0, -0.8, 0.25), Color3.fromRGB(28, 26, 30), Enum.Material.Fabric).Shape = Enum.PartType.Wedge
	end,
	RatTail = function(m)
		local at = CFrame.new()
		for i = 1, 7 do
			local thickness = 0.32 - i * 0.035
			at = at * CFrame.Angles(0, 0, math.rad(18)) * CFrame.new(0.38, 0, 0)
			part(m, Vector3.new(0.45, thickness, thickness), at, Color3.fromRGB(196, 140, 140), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	end,
	SlimeGel = function(m)
		local blob = part(m, Vector3.new(1.6, 1.2, 1.6), CFrame.new(), Color3.fromRGB(90, 220, 90), Enum.Material.Glass, Enum.PartType.Ball)
		blob.Transparency = 0.25
		part(m, Vector3.new(0.6, 0.45, 0.6), CFrame.new(0.4, 0.2, -0.3), Color3.fromRGB(150, 255, 140), Enum.Material.Neon, Enum.PartType.Ball).Transparency = 0.4
	end,
	GraveShroud = function(m)
		for i = 0, 3 do
			part(m, Vector3.new(1.8 - i * 0.15, 0.06, 0.55), CFrame.new(0, i * 0.05, (i - 1.5) * 0.45) * CFrame.Angles(math.rad(i * 8 - 12), math.rad(i * 9), 0), Color3.fromRGB(46, 50, 44), Enum.Material.Fabric)
		end
		part(m, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.6, 0.15, 0.2), Color3.fromRGB(110, 230, 150), Enum.Material.Neon, Enum.PartType.Ball)
	end,
	HealthPotion = function(m)
		local glass = part(m, Vector3.new(1.4, 1.4, 1.4), CFrame.new(), Color3.fromRGB(230, 235, 240), Enum.Material.Glass, Enum.PartType.Ball)
		glass.Transparency = 0.55
		part(m, Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, -0.08, 0), Color3.fromRGB(220, 30, 40), Enum.Material.Neon, Enum.PartType.Ball).Transparency = 0.15
		part(m, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 235, 240), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.5
		part(m, Vector3.new(0.3, 0.34, 0.34), CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	end,
}

-- A model of the item, centered near the origin. Unknown items get a plain box.
function ItemModels.Build(itemName: string, rarity: string): Model
	local def = Items.Defs[itemName]
	local model = Instance.new("Model")
	model.Name = itemName
	if def and def.Look then
		local tool = WeaponBuilder.Build(def.Look, rarity)
		for _, child in tool:GetChildren() do
			if child:IsA("BasePart") or child:IsA("Model") then
				child.Parent = model
			end
		end
		tool:Destroy()
		return model
	end
	local build = builders[itemName]
	if build then
		build(model)
	else
		part(model, Vector3.new(1, 1, 1), CFrame.new(), Color3.fromRGB(120, 110, 100), Enum.Material.Slate)
	end
	return model
end

return ItemModels
