--!strict
-- Builds a dragon Model from its genes, using plain parts (no imported meshes).
--
-- Layout (Normal size, in studs): the dragon faces -Z (its LookVector), feet on y = 0.
-- The model's pivot is the point on the ground under its body, so
--   model:PivotTo(CFrame.new(groundPosition))
-- puts it standing on the ground. Lives in Shared so the UI can show previews later too.

local Genes = require(script.Parent.Genes)
local Rarity = require(script.Parent.Rarity)

type GeneOption = Genes.GeneOption
type PartKind = "Ellipsoid" | "Ball" | "Block" | "Wedge"

local BODY_Y = 2.6 -- height of the body's centre at Normal size
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 25)
local FLAME = Color3.fromRGB(255, 120, 30)
local STARLIGHT = Color3.fromRGB(200, 230, 255)

local DragonBuilder = {}

local function solid(color: Color3): GeneOption
	return { Id = "_", Rarity = "Common", Color = color }
end

local function newPart(model: Model, name: string, kind: PartKind, size: Vector3, cframe: CFrame, look: GeneOption)
	local part: BasePart
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if kind == "Ball" then
			basic.Shape = Enum.PartType.Ball
		end
		part = basic
	end
	if kind == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end

	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = look.Color or WHITE
	part.Material = look.Material or Enum.Material.SmoothPlastic
	part.Transparency = look.Transparency or 0
	part.Reflectance = look.Reflectance or 0
	part.Parent = model
	return part
end

local function glow(part: BasePart, color: Color3, transparency: number?)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency or 0
	part.Reflectance = 0
end

local function addLight(parent: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.5
	light.Parent = parent
end

local function addParticles(
	parent: BasePart,
	fromColor: Color3,
	toColor: Color3,
	settings: { Rate: number, Lifetime: number, Speed: number, Size: number, Spread: number? }
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(fromColor, toColor)
	emitter.Rate = settings.Rate
	emitter.Lifetime = NumberRange.new(settings.Lifetime * 0.7, settings.Lifetime)
	emitter.Speed = NumberRange.new(settings.Speed * 0.5, settings.Speed)
	emitter.Size = NumberSequence.new(settings.Size, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.LightEmission = 1
	emitter.SpreadAngle = Vector2.new(settings.Spread or 180, settings.Spread or 180)
	emitter.Parent = parent
end

local function buildWing(model: Model, side: number, wings: string, body: GeneOption, accent: GeneOption)
	-- Wings start at the shoulder, sweep back a little and lift up.
	local root = CFrame.new(side * 1.2, 3.4, -0.5)
		* CFrame.Angles(0, -side * math.rad(15), 0)
		* CFrame.Angles(0, 0, side * math.rad(25))
	local function at(x: number, y: number, z: number, yaw: number?): CFrame
		return root * CFrame.new(side * x, y, z) * CFrame.Angles(0, side * (yaw or 0), 0)
	end

	local arm = newPart(model, "WingArm", "Block", Vector3.new(3.4, 0.3, 0.3), at(1.7, 0, 0), body)

	if wings == "Bat" then
		newPart(model, "WingMembrane", "Block", Vector3.new(3.2, 0.1, 2.4), at(1.6, -0.05, 1.2), accent)
		newPart(model, "WingFinger", "Block", Vector3.new(0.2, 0.2, 2.4), at(1.2, 0, 1.2), body)
		newPart(model, "WingFinger", "Block", Vector3.new(0.2, 0.2, 2.4), at(2.7, 0, 1.2), body)
	elseif wings == "Feathered" then
		local lengths = { 2.6, 2.5, 2.2, 1.8 }
		for i, length in lengths do
			local x = 0.4 + i * 0.65
			newPart(
				model,
				"Feather",
				"Block",
				Vector3.new(0.6, 0.12, length),
				at(x, -0.05, length / 2, 0.08 * i),
				accent
			)
		end
	elseif wings == "Crystal" then
		for i = 1, 3 do
			local shard = newPart(
				model,
				"WingShard",
				"Block",
				Vector3.new(0.55, 0.15, 2.8 - i * 0.3),
				at(0.2 + i * 0.9, 0, 1.3, 0.1 * i),
				accent
			)
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.3
		end
		addLight(arm, accent.Color or WHITE, 8)
	elseif wings == "Flame" then
		local membrane = newPart(model, "WingFlame", "Block", Vector3.new(3.2, 0.1, 2.2), at(1.6, -0.05, 1.1), accent)
		glow(membrane, FLAME, 0.2)
		addParticles(
			membrane,
			Color3.fromRGB(255, 220, 80),
			FLAME,
			{ Rate = 12, Lifetime = 0.8, Speed = 2, Size = 0.5 }
		)
	elseif wings == "Starlight" then
		glow(arm, STARLIGHT)
		local membrane = newPart(model, "WingStar", "Block", Vector3.new(3.2, 0.1, 2.4), at(1.6, -0.05, 1.2), accent)
		membrane.Material = Enum.Material.Glass
		membrane.Color = STARLIGHT
		membrane.Transparency = 0.4
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = STARLIGHT
		sparkles.Parent = membrane
	end
end

local function buildHorns(model: Model, horns: string, accent: GeneOption, head: BasePart)
	if horns == "Crown" then
		for i = 0, 4 do
			local angle = math.rad(-60 + i * 30)
			local position = Vector3.new(math.sin(angle) * 0.6, 5.35, -2.4 - math.cos(angle) * 0.6)
			newPart(model, "CrownSpike", "Wedge", Vector3.new(0.2, 0.6, 0.35), CFrame.new(position), accent)
		end
		return
	elseif horns == "Halo" then
		local center = Vector3.new(0, 6.1, -2.4)
		for i = 1, 10 do
			local angle = i / 10 * math.pi * 2
			local bead = newPart(
				model,
				"Halo",
				"Ball",
				Vector3.one * 0.3,
				CFrame.new(center + Vector3.new(math.cos(angle) * 0.8, 0, math.sin(angle) * 0.8)),
				accent
			)
			glow(bead, Color3.fromRGB(255, 240, 170))
		end
		addLight(head, Color3.fromRGB(255, 240, 170), 10)
		return
	end

	for _, side in { -1, 1 } do
		local base = CFrame.new(side * 0.45, 5.3, -2.3)
		if horns == "Nubs" then
			newPart(model, "Horn", "Ball", Vector3.one * 0.4, base, accent)
		elseif horns == "Short" then
			newPart(model, "Horn", "Wedge", Vector3.new(0.3, 0.8, 0.5), base * CFrame.new(0, 0.3, 0), accent)
		elseif horns == "Curved" then
			newPart(
				model,
				"Horn",
				"Wedge",
				Vector3.new(0.3, 0.7, 0.5),
				base * CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(20), 0, 0),
				accent
			)
			newPart(
				model,
				"HornTip",
				"Wedge",
				Vector3.new(0.22, 0.6, 0.4),
				base * CFrame.new(0, 0.75, 0.35) * CFrame.Angles(math.rad(55), 0, 0),
				accent
			)
		elseif horns == "Crystal" then
			local horn = newPart(
				model,
				"Horn",
				"Block",
				Vector3.new(0.3, 1.2, 0.3),
				base * CFrame.new(0, 0.5, 0.1) * CFrame.Angles(math.rad(15), 0, -side * math.rad(10)),
				accent
			)
			horn.Material = Enum.Material.Glass
			horn.Transparency = 0.2
			addLight(horn, accent.Color or WHITE, 6)
		end
	end
end

local function buildTail(model: Model, tail: string, body: GeneOption, accent: GeneOption)
	newPart(model, "Tail", "Ellipsoid", Vector3.new(1.4, 1.2, 1.8), CFrame.new(0, 2.5, 2.4), body)
	newPart(model, "Tail", "Ellipsoid", Vector3.new(1, 0.9, 1.6), CFrame.new(0, 2.2, 3.6), body)
	newPart(model, "Tail", "Ellipsoid", Vector3.new(0.7, 0.6, 1.4), CFrame.new(0, 2.1, 4.7), body)

	local tip = CFrame.new(0, 2.1, 5.55)
	local diamond = CFrame.Angles(math.rad(45), 0, 0)

	if tail == "Spiked" then
		newPart(model, "TailTip", "Block", Vector3.new(0.15, 0.9, 0.9), tip * diamond, accent)
		for i, z in { 2.4, 3.6, 4.7 } do
			local height = 0.75 - i * 0.12
			newPart(model, "Spine", "Wedge", Vector3.new(0.15, height, 0.6), CFrame.new(0, 3.05 - i * 0.25, z), accent)
		end
	elseif tail == "Club" then
		newPart(model, "TailTip", "Ball", Vector3.one * 1.1, tip, accent)
	elseif tail == "Flame" then
		local flame = newPart(model, "TailTip", "Ball", Vector3.one * 0.9, tip, accent)
		glow(flame, FLAME)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 4
		fire.Color = FLAME
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = flame
	elseif tail == "Twin" then
		for _, side in { -1, 1 } do
			newPart(
				model,
				"TailTip",
				"Block",
				Vector3.new(0.15, 0.9, 0.9),
				tip * CFrame.new(side * 0.35, 0, 0) * CFrame.Angles(0, side * math.rad(20), 0) * diamond,
				accent
			)
		end
	elseif tail == "Comet" then
		local comet = newPart(model, "TailTip", "Ball", Vector3.one * 0.9, tip, accent)
		glow(comet, accent.Color or WHITE)
		addLight(comet, accent.Color or WHITE, 8)
		addParticles(
			comet,
			WHITE,
			accent.Color or WHITE,
			{ Rate = 25, Lifetime = 1.2, Speed = 1, Size = 0.6, Spread = 15 }
		)
	end
end

local function addAura(torso: BasePart, aura: string)
	if aura == "Ember" then
		addParticles(
			torso,
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(255, 60, 20),
			{ Rate = 10, Lifetime = 1.5, Speed = 2, Size = 0.35 }
		)
	elseif aura == "Frost" then
		addParticles(torso, WHITE, Color3.fromRGB(140, 210, 255), { Rate = 12, Lifetime = 2, Speed = 0.6, Size = 0.3 })
	elseif aura == "Storm" then
		addParticles(
			torso,
			Color3.fromRGB(255, 255, 150),
			Color3.fromRGB(255, 230, 40),
			{ Rate = 6, Lifetime = 0.25, Speed = 8, Size = 0.4 }
		)
		addLight(torso, Color3.fromRGB(255, 240, 120), 12)
	elseif aura == "Starfall" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 215, 90)
		sparkles.Parent = torso
	elseif aura == "Cosmic" then
		addParticles(
			torso,
			Color3.fromRGB(255, 120, 230),
			Color3.fromRGB(110, 60, 255),
			{ Rate = 20, Lifetime = 2, Speed = 1, Size = 0.5 }
		)
		addLight(torso, Color3.fromRGB(170, 90, 255), 14)
	end
end

function DragonBuilder.Build(genes: Genes.DragonGenes): Model
	local body = Genes.Get("Body", genes.Body)
	local accent = Genes.Get("Accent", genes.Accent)

	local model = Instance.new("Model")
	model.Name = "Dragon"

	-- Body, belly and legs
	local torso = newPart(model, "Body", "Ellipsoid", Vector3.new(3, 2.6, 4.2), CFrame.new(0, BODY_Y, 0), body)
	newPart(model, "Belly", "Ellipsoid", Vector3.new(2.4, 2, 3.6), CFrame.new(0, 2.3, -0.4), accent)
	for _, x in { -0.95, 0.95 } do
		for _, z in { -1.2, 1.2 } do
			newPart(model, "Leg", "Block", Vector3.new(0.7, 1.7, 0.7), CFrame.new(x, 0.85, z), body)
			newPart(model, "Foot", "Ellipsoid", Vector3.new(0.9, 0.4, 1.1), CFrame.new(x, 0.2, z - 0.15), accent)
		end
	end

	-- Neck and head
	newPart(
		model,
		"Neck",
		"Ellipsoid",
		Vector3.new(1.3, 2, 1.3),
		CFrame.new(0, 3.7, -1.9) * CFrame.Angles(math.rad(-30), 0, 0),
		body
	)
	local head = newPart(model, "Head", "Ellipsoid", Vector3.new(1.8, 1.6, 2), CFrame.new(0, 4.6, -2.5), body)
	newPart(model, "Snout", "Ellipsoid", Vector3.new(1.2, 0.9, 1.4), CFrame.new(0, 4.3, -3.4), body)
	for _, side in { -1, 1 } do
		newPart(model, "Eye", "Ball", Vector3.one * 0.5, CFrame.new(side * 0.6, 4.85, -3.05), solid(WHITE))
		newPart(model, "Pupil", "Ball", Vector3.one * 0.28, CFrame.new(side * 0.65, 4.87, -3.27), solid(BLACK))
	end

	buildHorns(model, genes.Horns, accent, head)
	for _, side in { -1, 1 } do
		buildWing(model, side, genes.Wings, body, accent)
	end
	buildTail(model, genes.Tail, body, accent)
	addAura(torso, genes.Aura)

	-- Pivot on the ground under the body, then grow/shrink to the dragon's size.
	model.PrimaryPart = torso
	torso.PivotOffset = CFrame.new(0, -BODY_Y, 0)
	local scale = Genes.Get("Size", genes.Size).Scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end

	local rarity = Genes.GetRarity(genes)
	model:SetAttribute("DragonName", Genes.GetName(genes))
	model:SetAttribute("Rarity", rarity.Name)
	return model
end

-- Floating name + rarity label above a dragon built by DragonBuilder.Build.
function DragonBuilder.AddNameTag(model: Model, genes: Genes.DragonGenes)
	local torso = model.PrimaryPart
	if not torso then
		return
	end
	local rarity: Rarity.Tier = Genes.GetRarity(genes)
	local scale = Genes.Get("Size", genes.Size).Scale or 1

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(220, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4 * scale, 0)
	billboard.MaxDistance = 90
	billboard.Adornee = torso

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = WHITE
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = Genes.GetName(genes)
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Position = UDim2.fromScale(0, 0.55)
	rarityLabel.Size = UDim2.fromScale(1, 0.45)
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.Color
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Text = rarity.Name
	rarityLabel.Parent = billboard

	billboard.Parent = torso
end

return DragonBuilder
