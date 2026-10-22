--!strict
-- A small 3D model of any item, for pictures (the bag, the "New item!" card).
-- Weapons come from WeaponBuilder. Materials and potions use a real model from ReplicatedStorage.ItemModels
-- (named like the item, e.g. "HealthPotion") when there is one, and otherwise are made here from a few parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(script.Parent.Armor)
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
	FoxHelmet = function(m)
		local iron = Color3.fromRGB(105, 102, 98)
		local dome = part(m, Vector3.new(1.7, 1.5, 1.8), CFrame.Angles(math.rad(-8), 0, math.rad(6)), iron, Enum.Material.Metal, Enum.PartType.Ball)
		part(m, Vector3.new(0.18, 1.95, 1.95), dome.CFrame * CFrame.new(0, -0.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 76, 72), Enum.Material.Metal, Enum.PartType.Cylinder) -- the rim
		part(m, Vector3.new(0.12, 0.9, 0.22), dome.CFrame * CFrame.new(0, 0.05, -0.9), Color3.fromRGB(80, 76, 72), Enum.Material.Metal)
		-- the fox, painted on the side
		local fox = Color3.fromRGB(215, 110, 40)
		part(m, Vector3.new(0.05, 0.42, 0.55), dome.CFrame * CFrame.new(0.84, 0.15, 0) * CFrame.Angles(0, 0, math.rad(12)), fox, Enum.Material.SmoothPlastic)
		for _, z in { -0.18, 0.18 } do
			part(m, Vector3.new(0.05, 0.22, 0.14), dome.CFrame * CFrame.new(0.8, 0.45, z) * CFrame.Angles(0, 0, math.rad(12)), fox, Enum.Material.SmoothPlastic)
		end
		-- the dent
		part(m, Vector3.new(0.5, 0.35, 0.5), dome.CFrame * CFrame.new(-0.55, 0.45, 0.3), Color3.fromRGB(70, 68, 66), Enum.Material.Metal, Enum.PartType.Ball)
	end,
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
		-- (no Glass or Neon: pictures in the bag draw them flat and pale)
		part(m, Vector3.new(1.4, 1.4, 1.4), CFrame.new(), Color3.fromRGB(200, 30, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(m, Vector3.new(0.35, 0.35, 0.35), CFrame.new(-0.35, 0.35, -0.45), Color3.fromRGB(255, 220, 220), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(m, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 200, 205), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		part(m, Vector3.new(0.3, 0.34, 0.34), CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	end,
}

-- A model of the item, centered near the origin. Unknown items get a plain box.
function ItemModels.Build(itemName: string, rarity: string): Model
	local def = Items.Defs[itemName]
	local model = Instance.new("Model")
	model.Name = itemName
	-- a brew without a model of its own: the same round bottle, its liquid in the brew's colour
	local made = ReplicatedStorage:FindFirstChild("ItemModels")
	if def and def.Slot == "Potion" and def.Color and not builders[itemName] and not (made and made:FindFirstChild(itemName)) then
		part(model, Vector3.new(1.4, 1.4, 1.4), CFrame.new(), def.Color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(model, Vector3.new(0.35, 0.35, 0.35), CFrame.new(-0.35, 0.35, -0.45), def.Color:Lerp(Color3.new(1, 1, 1), 0.7), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(model, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 200, 205), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		part(model, Vector3.new(0.3, 0.34, 0.34), CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
		return model
	end
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
	-- armor: its Tripo piece (ReplicatedStorage.ArmorModels) or a plain shape in the set's colour; rings: a band and a stone
	local piece = Armor.Pieces[itemName]
	if piece then
		local models = ReplicatedStorage:FindFirstChild("ArmorModels")
		local source = models and piece.Look and models:FindFirstChild(piece.Look)
		local own = ReplicatedStorage:FindFirstChild("ItemModels")
		source = source or (own and own:FindFirstChild(itemName)) -- rings have a model of their own
		if source and source:IsA("Model") then
			local copy = source:Clone()
			copy:PivotTo(CFrame.new())
			return copy
		end
		local set = Armor.SetByName[piece.Set]
		local color = if set then set.Color else Color3.fromRGB(214, 170, 64)
		local material = if piece.Set == "Heavy" or piece.Set == "Medium" then Enum.Material.Metal elseif piece.Set == "Light" then Enum.Material.Leather else Enum.Material.Fabric
		if piece.Slot == "Ring" then
			local band = part(model, Vector3.new(0.3, 1.4, 1.4), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(214, 170, 64), Enum.Material.Metal, Enum.PartType.Cylinder)
			band.Size = Vector3.new(0.3, 1.4, 1.4)
			part(model, Vector3.new(0.32, 1, 1), CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 26, 22), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			part(model, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 0.75, 0), if piece.Name == "EmberBand" then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(150, 30, 40), Enum.Material.Neon, Enum.PartType.Ball)
		elseif piece.Slot == "Head" then
			part(model, Vector3.new(1.4, 1.35, 1.4), CFrame.new(), color, material)
		elseif piece.Slot == "Chest" then
			part(model, Vector3.new(2.2, 1.8, 1.2), CFrame.new(), color, material)
			for _, side in { -1, 1 } do
				part(model, Vector3.new(0.9, 0.5, 1.15), CFrame.new(side * 1.3, 0.75, 0), color, material)
			end
		else
			part(model, Vector3.new(0.75, 1.5, 0.75), CFrame.new(0, 0.3, 0), color, material)
			part(model, Vector3.new(0.8, 0.45, 1.1), CFrame.new(0, -0.55, if piece.Slot == "Legs" then -0.2 else 0), color, material)
		end
		return model
	end
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")
	local made = folder and folder:FindFirstChild(itemName)
	if made and made:IsA("Model") then
		local copy = made:Clone()
		copy:PivotTo(CFrame.new())
		return copy
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
