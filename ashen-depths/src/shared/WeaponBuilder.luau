--!strict
-- Builds a weapon Tool out of plain parts, until the real models (KayKit / Tripo) arrive.
-- Every weapon is built standing up: the grip (the Tool's Handle) is at the origin and the
-- weapon extends along +Y. `GRIP` turns it so it points forward out of the player's hand.

local WeaponBuilder = {}

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
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = orb
	end,
	Daggers = function(h)
		part(h, Vector3.new(0.7, 0.14, 0.26), CFrame.new(0, 0.42, 0), IRON, Enum.Material.Metal)
		part(h, Vector3.new(0.26, 1.3, 0.08), CFrame.new(0, 1.14, 0), STEEL, Enum.Material.Metal)
		part(h, Vector3.new(0.18, 0.18, 0.08), CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(45)), STEEL, Enum.Material.Metal)
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

-- Returns a ready Tool for the given look ("Sword", "Axe", "Bow", "Staff", "Daggers", "Tome").
function WeaponBuilder.Build(look: string): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP

	local handleSize = if look == "Daggers" then Vector3.new(0.22, 0.7, 0.22) else Vector3.new(0.28, 1.1, 0.28)
	local handle = makeHandle(handleSize, LEATHER, Enum.Material.Fabric)
	local build = builders[look] or builders.Sword
	build(handle)
	handle.Parent = tool
	return tool
end

return WeaponBuilder
