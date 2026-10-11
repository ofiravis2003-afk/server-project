--!strict
-- Builds a weapon Tool. With a Tripo model in ReplicatedStorage.WeaponModels ("<Look>_<Tier>", e.g. "Sword_Rare")
-- the Tool is that mesh; otherwise it's made out of plain parts.
-- Every weapon is built standing up: the grip is at the origin and the weapon extends along +Y.
-- `GRIP` turns a part-built weapon so it points forward out of the player's hand. A model's "WeaponGrip"
-- attachment is the whole hold: its Y is the blade, standing up out of the fist (a sword held up, ready),
-- its -Z faces forward (an axe's blade); the bow's frame is turned so it stands upright with its string back.
--
-- Rarities share three looks: Common, Rare (also Epic) and Legendary (also Mythic). A missing look falls back to
-- the nearest one there is. Epic, Legendary and Mythic weapons glow in their rarity's color; Mythic burns.
-- A "Muzzle" attachment marks where shots leave the weapon (a staff's crystal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(script.Parent.Rarity)

local WeaponBuilder = {}

local TIER_LOOKS: { [string]: { string } } = {
	Common = { "Common", "Rare", "Legendary" },
	Rare = { "Rare", "Common", "Legendary" },
	Epic = { "Rare", "Legendary", "Common" },
	Legendary = { "Legendary", "Rare", "Common" },
	Mythic = { "Legendary", "Rare", "Common" },
}

local GRIP = CFrame.Angles(math.rad(90), 0, 0)

local WOOD = Color3.fromRGB(92, 64, 42)
local LEATHER = Color3.fromRGB(58, 40, 30)
local IRON = Color3.fromRGB(110, 112, 118)
local STEEL = Color3.fromRGB(176, 180, 186)
local RUST = Color3.fromRGB(150, 110, 84)

local function part(
	parent: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function makeHandle(size: Vector3, color: Color3, material: Enum.Material): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = material
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	return handle
end

local builders: { [string]: (Part) -> () } = {
	Sword = function(h)
		part(h, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -0.7, 0), IRON, Enum.Material.Metal, Enum.PartType.Ball)
		part(h, Vector3.new(1.4, 0.22, 0.36), CFrame.new(0, 0.66, 0), IRON, Enum.Material.Metal)
		part(h, Vector3.new(0.4, 3.2, 0.1), CFrame.new(0, 2.37, 0), RUST, Enum.Material.Metal)
		part(h, Vector3.new(0.28, 0.28, 0.1), CFrame.new(0, 3.97, 0) * CFrame.Angles(0, 0, math.rad(45)), RUST, Enum.Material.Metal)
	end,
	Axe = function(h)
		part(h, Vector3.new(0.26, 3.6, 0.26), CFrame.new(0, 1.4, 0), WOOD, Enum.Material.Wood)
		part(h, Vector3.new(0.18, 1.5, 1.2), CFrame.new(0, 2.7, -0.75), IRON, Enum.Material.Metal)
		part(h, Vector3.new(0.12, 1.8, 0.3), CFrame.new(0, 2.7, -1.4), STEEL, Enum.Material.Metal)
		part(h, Vector3.new(0.3, 0.6, 0.5), CFrame.new(0, 2.7, 0.3), IRON, Enum.Material.Metal)
	end,
	Bow = function(h)
		part(h, Vector3.new(0.2, 2.2, 0.22), CFrame.new(0, 1.4, 0.25) * CFrame.Angles(math.rad(-14), 0, 0), WOOD, Enum.Material.Wood)
		part(h, Vector3.new(0.2, 2.2, 0.22), CFrame.new(0, -1.4, 0.25) * CFrame.Angles(math.rad(14), 0, 0), WOOD, Enum.Material.Wood)
		part(h, Vector3.new(0.04, 5.1, 0.04), CFrame.new(0, 0, 0.78), Color3.fromRGB(225, 215, 190), Enum.Material.Fabric)
	end,
	Staff = function(h)
		part(h, Vector3.new(0.24, 4.8, 0.24), CFrame.new(0, 1.2, 0), WOOD, Enum.Material.Wood)
		for i = 0, 2 do
			local angle = math.rad(i * 120)
			part(
				h,
				Vector3.new(0.12, 0.9, 0.12),
				CFrame.new(math.cos(angle) * 0.28, 3.85, math.sin(angle) * 0.28) * CFrame.Angles(math.sin(angle) * 0.4, 0, -math.cos(angle) * 0.4),
				IRON,
				Enum.Material.Metal
			)
		end
		local orb = part(h, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 4.05, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, Enum.PartType.Ball)
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = Vector3.new(0, 4.05, 0)
		muzzle.Parent = h
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = orb
	end,
	-- An open book held flat in front of the hand, its pages glowing softly.
	Tome = function(h)
		local cover = Color3.fromRGB(90, 24, 28)
		local gold = Color3.fromRGB(200, 160, 70)
		part(h, Vector3.new(1.9, 1.4, 0.12), CFrame.new(0, 0.95, 0), cover, Enum.Material.Leather)
		part(h, Vector3.new(0.85, 1.3, 0.14), CFrame.new(-0.45, 0.95, -0.1) * CFrame.Angles(0, math.rad(6), 0), Color3.fromRGB(235, 225, 195), Enum.Material.SmoothPlastic)
		part(h, Vector3.new(0.85, 1.3, 0.14), CFrame.new(0.45, 0.95, -0.1) * CFrame.Angles(0, math.rad(-6), 0), Color3.fromRGB(235, 225, 195), Enum.Material.SmoothPlastic)
		part(h, Vector3.new(0.1, 1.42, 0.2), CFrame.new(0, 0.95, -0.05), gold, Enum.Material.Metal)
		local rune = part(h, Vector3.new(0.3, 0.3, 0.05), CFrame.new(0.45, 1.0, -0.19) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 140)
		light.Range = 7
		light.Brightness = 1.2
		light.Parent = rune
	end,
}

local function findModel(look: string, rarity: string): BasePart?
	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	if not folder then
		return nil
	end
	for _, tier in TIER_LOOKS[rarity] or TIER_LOOKS.Common do
		local model = folder:FindFirstChild(`{look}_{tier}`)
		local handle = model and model:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") and handle:FindFirstChild("WeaponGrip") then
			return handle
		end
	end
	return nil
end

-- A glow (and for Mythic, flames) in the rarity's color, so a better weapon shows from across the room.
local function addAura(handle: BasePart, rarity: string)
	if rarity ~= "Epic" and rarity ~= "Legendary" and rarity ~= "Mythic" then
		return
	end
	local color = (Rarity.Info[rarity] or Rarity.Info.Common).Color
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if rarity == "Epic" then 6 else 9
	light.Brightness = if rarity == "Epic" then 0.8 else 1.4
	light.Parent = handle
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Aura"
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(0.3, 1)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = if rarity == "Epic" then 6 else 14
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.Parent = handle
	if rarity == "Mythic" then
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Flames"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), color)
		fire.LightEmission = 1
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
		fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		fire.Lifetime = NumberRange.new(0.3, 0.6)
		fire.Speed = NumberRange.new(1, 2.5)
		fire.Acceleration = Vector3.new(0, 4, 0)
		fire.Rate = 30
		fire.Shape = Enum.ParticleEmitterShape.Box
		fire.Parent = handle
	end
end

-- Returns a ready Tool for the given look ("Sword", "Axe", "Bow", "Staff", "Tome") and rarity.
function WeaponBuilder.Build(look: string, rarity: string?): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP

	local source = findModel(look, rarity or "Common")
	if source then
		local handle = source:Clone()
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanQuery = false
		handle.Massless = true
		tool.Grip = (handle:FindFirstChild("WeaponGrip") :: Attachment).CFrame
		addAura(handle, rarity or "Common")
		handle.Parent = tool
		return tool
	end

	local handle = makeHandle(Vector3.new(0.28, 1.1, 0.28), LEATHER, Enum.Material.Fabric)
	local build = builders[look] or builders.Sword
	build(handle)
	addAura(handle, rarity or "Common")
	handle.Parent = tool
	return tool
end

return WeaponBuilder
