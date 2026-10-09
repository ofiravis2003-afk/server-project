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
}

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

function Materials.Apply(root: Instance)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.MaterialVariant == "" then
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
