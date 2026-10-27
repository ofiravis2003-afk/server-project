--!strict
-- Dresses a floor's plain parts in the realistic catacomb materials.
-- The materials are MaterialVariants made with Studio's material generator and saved in the Depths
-- place (MaterialService). A part keeps its base material and gets the variant on top; its color tints
-- the texture, so dark colors are brightened to let the stone and metal detail show.
-- If a variant is missing (e.g. in the city place), parts simply keep their plain look.

local MaterialService = game:GetService("MaterialService")

type Rule = { Variant: string, Brighten: number, MaxBrightness: number? }

local RULES: { [Enum.Material]: Rule } = {
	[Enum.Material.Cobblestone] = { Variant = "CatacombWall", Brighten = 2 },
	[Enum.Material.Slate] = { Variant = "CatacombFloor", Brighten = 2.2 },
	[Enum.Material.Limestone] = { Variant = "AncientLimestone", Brighten = 1.5 },
	-- Only dark iron: bright metals (gold coins, silver keys, chest trims) keep their color.
	[Enum.Material.Metal] = { Variant = "DarkIron", Brighten = 2.5, MaxBrightness = 0.3 },
	[Enum.Material.Wood] = { Variant = "OldWood", Brighten = 1.8 },
	-- chapter II's caverns (see Materials.Cavern)
	[Enum.Material.Rock] = { Variant = "CavernRock", Brighten = 1.8 },
	[Enum.Material.Ground] = { Variant = "CavernFloor", Brighten = 1.9 },
}

-- The parts of a room or corridor the caverns turn to raw rock (walls, arches, ceiling) and mossy earth (floor).
local CAVERN_ROCK = { Wall = true, Lintel = true, Pillar = true, PillarBase = true, Arch = true, Ceiling = true, Shaft = true, Rim = true }
local CAVERN_EARTH = { Floor = true, Step = true }

local Materials = {}

local available: { [string]: boolean }? = nil

local function hasVariant(name: string): boolean
	if not available then
		local found = {}
		for _, variant in MaterialService:GetDescendants() do
			if variant:IsA("MaterialVariant") then
				found[variant.Name] = true
			end
		end
		available = found
	end
	return (available :: { [string]: boolean })[name] == true
end

local function brighten(color: Color3, factor: number): Color3
	return Color3.new(math.min(color.R * factor, 1), math.min(color.G * factor, 1), math.min(color.B * factor, 1))
end

-- Chapter II (the Rotwood Caverns): the catacombs' cut stone becomes natural cave rock and mossy earth.
-- Run before Apply, which then dresses them in the cavern materials.
function Materials.Cavern(root: Instance)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.MaterialVariant == "" then
			if CAVERN_ROCK[part.Name] then
				part.Material = Enum.Material.Rock
				part.Color = Color3.fromRGB(62, 60, 54)
			elseif CAVERN_EARTH[part.Name] then
				part.Material = Enum.Material.Ground
				part.Color = Color3.fromRGB(52, 60, 40)
			end
		end
	end
end

function Materials.Apply(root: Instance)
	for _, part in root:GetDescendants() do
		-- Real 3D props carry their own textures (SurfaceAppearance); leave them alone.
		if part:IsA("BasePart") and part.MaterialVariant == "" and not part:FindFirstChildOfClass("SurfaceAppearance") then
			local rule = RULES[part.Material]
			if rule and hasVariant(rule.Variant) then
				local _, _, value = part.Color:ToHSV()
				if not rule.MaxBrightness or value <= rule.MaxBrightness then
					part.MaterialVariant = rule.Variant
					part.Color = brighten(part.Color, rule.Brighten)
				end
			end
		end
	end
end

return Materials
