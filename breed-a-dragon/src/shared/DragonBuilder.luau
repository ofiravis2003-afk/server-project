--!strict
-- Builds a dragon Model from its genes.
--
-- Layout (Normal size, in studs): the dragon faces -Z (its LookVector), feet on y = 0,
-- snout at about z = -5, tail tip at about z = +7.5.
-- The model's pivot is the point on the ground under its body, so
--   model:PivotTo(CFrame.new(groundPosition))
-- puts it standing on the ground. Lives in Shared so the UI can show previews later too.
--
-- Two ways to build one:
--   * From the Tripo AI model, if ReplicatedStorage has "TripoDragon" (MeshParts named Body,
--     HeadNeck, LeftWing, RightWing, Leg1-4): the meshes are coloured by the genes and rare
--     genes add extras on top.
--   * Otherwise from plain parts. Wing membranes are then real triangles, each made from
--     two WedgeParts (see `triangle`).

local Config = require(script.Parent.Config)
local Genes = require(script.Parent.Genes)
local Fonts = require(script.Parent.Fonts)
local Rarity = require(script.Parent.Rarity)

type GeneOption = Genes.GeneOption
type PartKind = "Ellipsoid" | "Ball" | "Block" | "Wedge" | "Cylinder"

local CHEST = Vector3.new(0, 2.9, -0.7) -- centre of the chest, the model's main part
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(15, 15, 20)
local BONE = Color3.fromRGB(235, 225, 205)
local EYE = Color3.fromRGB(255, 190, 40)
local FLAME = Color3.fromRGB(255, 120, 30)
local STARLIGHT = Color3.fromRGB(200, 230, 255)
local MEMBRANE_THICKNESS = 0.08

local DragonBuilder = {}

-- While a wing or the tail is being built, every new part is tagged with it (see buildRigged).
local currentRig: string? = nil
-- While set, every new part is also added to this list (see collectParts).
local collecting: { BasePart }? = nil

local function look(color: Color3, material: Enum.Material?, transparency: number?): GeneOption
	return { Id = "_", Rarity = "Common", Color = color, Material = material, Transparency = transparency }
end

local function applyLook(part: BasePart, option: GeneOption)
	part.Color = option.Color or WHITE
	part.Material = option.Material or Enum.Material.SmoothPlastic
	part.Transparency = option.Transparency or 0
	part.Reflectance = option.Reflectance or 0
end

local function newPart(model: Model, name: string, kind: PartKind, size: Vector3, cframe: CFrame, option: GeneOption)
	local part: BasePart
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if kind == "Ball" then
			basic.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			basic.Shape = Enum.PartType.Cylinder
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
	applyLook(part, option)
	if currentRig then
		part:SetAttribute("Rig", currentRig)
	end
	if collecting then
		table.insert(collecting, part)
	end
	part.Parent = model
	return part
end

local function ellipsoid(model: Model, name: string, size: Vector3, position: Vector3, option: GeneOption)
	return newPart(model, name, "Ellipsoid", size, CFrame.new(position), option)
end

-- A round rod from p1 to p2 (wing bones).
local function bone(model: Model, name: string, p1: Vector3, p2: Vector3, radius: number, option: GeneOption)
	local length = (p2 - p1).Magnitude
	local cframe = CFrame.lookAt((p1 + p2) / 2, p2) * CFrame.Angles(0, math.rad(90), 0)
	return newPart(model, name, "Cylinder", Vector3.new(length, radius * 2, radius * 2), cframe, option)
end

-- A flat triangle with corners a, b, c, made from two WedgePart halves.
local function triangle(model: Model, name: string, a: Vector3, b: Vector3, c: Vector3, option: GeneOption): BasePart
	-- Put the longest side between b and c, so `a` is the corner opposite it.
	local ab, ac, bc = b - a, c - a, c - b
	local abLength, acLength, bcLength = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abLength > acLength and abLength > bcLength then
		c, a = a, c
	elseif acLength > bcLength and acLength > abLength then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local first = newPart(
		model,
		name,
		"Wedge",
		Vector3.new(MEMBRANE_THICKNESS, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		option
	)
	newPart(
		model,
		name,
		"Wedge",
		Vector3.new(MEMBRANE_THICKNESS, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		option
	)
	return first
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

-- Small, slow glints of light. (Not Roblox's old "Sparkles" object: its big cartoon stars
-- don't shrink with the dragon, so they swamped the small pets.)
local function addSparkles(parent: BasePart, color: Color3)
	addParticles(parent, color, color, { Rate = 3, Lifetime = 1.2, Speed = 0.6, Size = 0.3 })
end

local function buildWing(model: Model, side: number, wings: string, body: GeneOption, accent: GeneOption)
	-- Wing space: x points away from the body, y up, z towards the tail.
	-- The wing starts on top of the shoulder, lifts up a little and sweeps back.
	local root = CFrame.new(side * 1, 3.75, -0.9)
		* CFrame.Angles(0, -side * math.rad(10), 0)
		* CFrame.Angles(0, 0, side * math.rad(20))
	local function P(x: number, y: number, z: number): Vector3
		return root:PointToWorldSpace(Vector3.new(side * x, y, z))
	end

	local shoulder, elbow, wrist = P(0, 0, 0), P(2.4, 0.8, -0.5), P(4.8, 1.6, 0)

	if wings == "Feathered" then
		bone(model, "WingBone", shoulder, elbow, 0.2, body)
		bone(model, "WingBone", elbow, wrist, 0.16, body)
		local light = look((accent.Color or WHITE):Lerp(WHITE, 0.25))
		local count = 8
		for i = count, 1, -1 do
			local t = i / count
			local base = if t < 0.5 then shoulder:Lerp(elbow, t * 2) else elbow:Lerp(wrist, (t - 0.5) * 2)
			local along = if t < 0.5 then (elbow - shoulder).Unit else (wrist - elbow).Unit
			-- Feathers near the body point back; feathers near the wingtip fan outwards and get longer.
			local angle = math.rad(5 + 60 * t)
			local length = 2.6 + 1.8 * t
			local direction = (P(math.sin(angle), -0.08, math.cos(angle)) - shoulder).Unit
			triangle(
				model,
				"Feather",
				base - along * 0.35,
				base + along * 0.35,
				base + direction * length,
				if i % 2 == 0 then accent else light
			)
		end
		return
	end

	-- Bat-style wing: arm bones, fingers fanning out from the wrist, and skin between them.
	local tips = { P(6.6, 0.6, 1.4), P(5.2, 0, 3.2), P(3.4, -0.3, 3.8) }
	local inner, back = P(1.6, -0.4, 3), P(0.1, -0.3, 1.9)

	local boneLook, skinLook = body, accent
	if wings == "Crystal" then
		boneLook = look(accent.Color or WHITE, Enum.Material.Glass, 0.1)
		skinLook = look(accent.Color or WHITE, Enum.Material.Glass, 0.35)
	elseif wings == "Flame" then
		skinLook = look(FLAME, Enum.Material.Neon, 0.25)
	elseif wings == "Starlight" then
		boneLook = look(STARLIGHT, Enum.Material.Neon)
		skinLook = look(STARLIGHT, Enum.Material.Glass, 0.45)
	end

	local arm = bone(model, "WingBone", shoulder, elbow, 0.2, boneLook)
	bone(model, "WingBone", elbow, wrist, 0.16, boneLook)
	for _, tip in tips do
		bone(model, "WingFinger", wrist, tip, 0.08, boneLook)
	end
	bone(model, "WingFinger", elbow, inner, 0.07, boneLook)
	newPart(
		model,
		"WingClaw",
		"Ellipsoid",
		Vector3.new(0.18, 0.18, 0.4),
		CFrame.lookAt(wrist, wrist + (wrist - elbow)),
		look(BONE)
	)

	local skin = triangle(model, "WingSkin", wrist, tips[1], tips[2], skinLook)
	triangle(model, "WingSkin", wrist, tips[2], tips[3], skinLook)
	triangle(model, "WingSkin", wrist, tips[3], elbow, skinLook)
	triangle(model, "WingSkin", elbow, tips[3], inner, skinLook)
	triangle(model, "WingSkin", elbow, inner, back, skinLook)
	triangle(model, "WingSkin", elbow, back, shoulder, skinLook)

	if wings == "Crystal" then
		addLight(arm, accent.Color or WHITE, 8)
	elseif wings == "Flame" then
		addParticles(skin, Color3.fromRGB(255, 220, 80), FLAME, { Rate = 12, Lifetime = 0.8, Speed = 2, Size = 0.5 })
	elseif wings == "Starlight" then
		addSparkles(arm, STARLIGHT)
	end
end

local function buildHead(model: Model, body: GeneOption, accent: GeneOption): BasePart
	-- Neck: three segments curving up and forward.
	ellipsoid(model, "Neck", Vector3.new(1.5, 1.6, 1.6), Vector3.new(0, 3.75, -1.95), body)
	ellipsoid(model, "Neck", Vector3.new(1.25, 1.35, 1.35), Vector3.new(0, 4.45, -2.55), body)
	ellipsoid(model, "Neck", Vector3.new(1.05, 1.15, 1.15), Vector3.new(0, 5.1, -2.95), body)

	local head = ellipsoid(model, "Head", Vector3.new(1.5, 1.3, 1.8), Vector3.new(0, 5.6, -3.35), body)
	ellipsoid(model, "Snout", Vector3.new(1, 0.75, 1.7), Vector3.new(0, 5.35, -4.35), body)
	ellipsoid(model, "Jaw", Vector3.new(0.85, 0.4, 1.5), Vector3.new(0, 5, -4.15), accent)

	for _, side in { -1, 1 } do
		newPart(model, "Nostril", "Ball", Vector3.one * 0.14, CFrame.new(side * 0.22, 5.58, -4.9), look(BLACK))
		ellipsoid(model, "Brow", Vector3.new(0.45, 0.22, 0.75), Vector3.new(side * 0.55, 6.02, -3.8), body)
		local eye = newPart(model, "Eye", "Ball", Vector3.one * 0.38, CFrame.new(side * 0.62, 5.8, -3.85), look(EYE))
		glow(eye, EYE)
		-- Slit pupil, like a reptile.
		newPart(model, "Pupil", "Block", Vector3.new(0.05, 0.28, 0.09), CFrame.new(side * 0.8, 5.8, -3.85), look(BLACK))
	end
	return head
end

local function buildLegs(model: Model, body: GeneOption)
	local claw = look(BONE)
	for _, side in { -1, 1 } do
		-- Front leg
		ellipsoid(model, "Shoulder", Vector3.new(0.85, 1.5, 0.95), Vector3.new(side * 1.05, 2.25, -1.2), body)
		newPart(model, "Forearm", "Block", Vector3.new(0.55, 1.3, 0.55), CFrame.new(side * 1.1, 0.95, -1.3), body)
		ellipsoid(model, "Paw", Vector3.new(0.8, 0.4, 1), Vector3.new(side * 1.1, 0.2, -1.5), body)
		-- Back leg
		ellipsoid(model, "Thigh", Vector3.new(1, 1.8, 1.5), Vector3.new(side * 1.1, 2.2, 1.1), body)
		newPart(model, "Shin", "Block", Vector3.new(0.6, 1.2, 0.6), CFrame.new(side * 1.15, 0.85, 1.45), body)
		ellipsoid(model, "Paw", Vector3.new(0.85, 0.4, 1.1), Vector3.new(side * 1.15, 0.2, 1.2), body)

		for _, offset in { -0.22, 0, 0.22 } do
			ellipsoid(model, "Claw", Vector3.new(0.12, 0.15, 0.35), Vector3.new(side * 1.1 + offset, 0.12, -2.05), claw)
			ellipsoid(model, "Claw", Vector3.new(0.12, 0.15, 0.35), Vector3.new(side * 1.15 + offset, 0.12, 0.6), claw)
		end
	end
end

-- Spikes along the back, from the neck to the hips.
local function buildSpine(model: Model, accent: GeneOption)
	local spikes = {
		{ Position = Vector3.new(0, 5.6, -2.95), Height = 0.4 },
		{ Position = Vector3.new(0, 5.05, -2.55), Height = 0.45 },
		{ Position = Vector3.new(0, 4.3, -1.6), Height = 0.6 },
		{ Position = Vector3.new(0, 4.25, -0.8), Height = 0.65 },
		{ Position = Vector3.new(0, 4.15, 0), Height = 0.6 },
		{ Position = Vector3.new(0, 3.9, 0.8), Height = 0.55 },
		{ Position = Vector3.new(0, 3.75, 1.5), Height = 0.45 },
	}
	for _, spike in spikes do
		newPart(
			model,
			"Spike",
			"Wedge",
			Vector3.new(0.14, spike.Height, spike.Height * 0.9),
			CFrame.new(spike.Position),
			accent
		)
	end
end

local function buildHorns(model: Model, horns: string, accent: GeneOption, head: BasePart)
	if horns == "Crown" then
		for i = 0, 4 do
			local angle = math.rad(-60 + i * 30)
			local position = Vector3.new(math.sin(angle) * 0.55, 6.25, -3.2 - math.cos(angle) * 0.55)
			newPart(model, "CrownSpike", "Wedge", Vector3.new(0.18, 0.6, 0.35), CFrame.new(position), accent)
		end
		return
	elseif horns == "Halo" then
		local center = Vector3.new(0, 6.95, -3.2)
		for i = 1, 10 do
			local angle = i / 10 * math.pi * 2
			local bead = newPart(
				model,
				"Halo",
				"Ball",
				Vector3.one * 0.3,
				CFrame.new(center + Vector3.new(math.cos(angle) * 0.75, 0, math.sin(angle) * 0.75)),
				accent
			)
			glow(bead, Color3.fromRGB(255, 240, 170))
		end
		addLight(head, Color3.fromRGB(255, 240, 170), 10)
		return
	end

	for _, side in { -1, 1 } do
		-- Horns grow from the back of the head and point up and back.
		local base = CFrame.new(side * 0.42, 6.1, -3)
		if horns == "Nubs" then
			newPart(model, "Horn", "Ball", Vector3.one * 0.35, base, accent)
		elseif horns == "Short" then
			newPart(model, "Horn", "Wedge", Vector3.new(0.28, 0.8, 0.55), base * CFrame.new(0, 0.3, 0.1), accent)
		elseif horns == "Curved" then
			newPart(
				model,
				"Horn",
				"Wedge",
				Vector3.new(0.3, 0.7, 0.5),
				base * CFrame.new(0, 0.3, 0.1) * CFrame.Angles(math.rad(20), 0, 0),
				accent
			)
			newPart(
				model,
				"HornTip",
				"Wedge",
				Vector3.new(0.22, 0.6, 0.4),
				base * CFrame.new(0, 0.75, 0.45) * CFrame.Angles(math.rad(55), 0, 0),
				accent
			)
		elseif horns == "Crystal" then
			local horn = newPart(
				model,
				"Horn",
				"Block",
				Vector3.new(0.3, 1.2, 0.3),
				base * CFrame.new(0, 0.5, 0.15) * CFrame.Angles(math.rad(20), 0, -side * math.rad(10)),
				accent
			)
			horn.Material = Enum.Material.Glass
			horn.Transparency = 0.2
			addLight(horn, accent.Color or WHITE, 6)
		end
	end
end

local function buildTail(model: Model, tail: string, body: GeneOption, accent: GeneOption)
	local segments = {
		{ Size = Vector3.new(1.6, 1.5, 1.9), Position = Vector3.new(0, 2.65, 2.4) },
		{ Size = Vector3.new(1.25, 1.15, 1.8), Position = Vector3.new(0, 2.4, 3.6) },
		{ Size = Vector3.new(0.95, 0.85, 1.7), Position = Vector3.new(0, 2.2, 4.75) },
		{ Size = Vector3.new(0.7, 0.6, 1.6), Position = Vector3.new(0, 2.1, 5.8) },
		{ Size = Vector3.new(0.45, 0.4, 1.4), Position = Vector3.new(0, 2.1, 6.75) },
	}
	for _, segment in segments do
		ellipsoid(model, "Tail", segment.Size, segment.Position, body)
	end

	local tip = CFrame.new(0, 2.15, 7.5)
	local diamond = CFrame.Angles(math.rad(45), 0, 0)

	if tail == "Spiked" then
		newPart(model, "TailTip", "Block", Vector3.new(0.12, 0.9, 0.9), tip * diamond, accent)
		for i = 1, 4 do
			local segment = segments[i]
			local height = 0.6 - i * 0.08
			local top = segment.Position + Vector3.new(0, segment.Size.Y / 2 + height * 0.2, 0)
			newPart(model, "TailSpike", "Wedge", Vector3.new(0.12, height, height * 0.9), CFrame.new(top), accent)
		end
	elseif tail == "Club" then
		newPart(model, "TailTip", "Ball", Vector3.one * 1.1, tip, accent)
		for _, offset in { Vector3.new(0.55, 0, 0), Vector3.new(-0.55, 0, 0), Vector3.new(0, 0.55, 0) } do
			newPart(model, "ClubSpike", "Ball", Vector3.one * 0.3, tip + offset, look(BONE))
		end
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
				Vector3.new(0.12, 0.9, 0.9),
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

-- Runs `build` and returns every part it made.
local function collectParts(build: () -> ()): { BasePart }
	collecting = {}
	build()
	local made = collecting or {}
	collecting = nil
	return made
end

-- Runs `build` with every part it makes tagged Rig = `tag`, then adds an invisible
-- joint part named `tag .. "Joint"` at `joint` for the animator to rotate around.
local function buildRigged(model: Model, tag: string, joint: Vector3, build: () -> ())
	currentRig = tag
	build()
	currentRig = nil
	local jointPart = newPart(model, tag .. "Joint", "Block", Vector3.one * 0.2, CFrame.new(joint), look(WHITE))
	jointPart.Transparency = 1
end

local function addAura(chest: BasePart, aura: string)
	if aura == "Ember" then
		addParticles(
			chest,
			Color3.fromRGB(255, 200, 60),
			Color3.fromRGB(255, 60, 20),
			{ Rate = 10, Lifetime = 1.5, Speed = 2, Size = 0.35 }
		)
	elseif aura == "Frost" then
		addParticles(chest, WHITE, Color3.fromRGB(140, 210, 255), { Rate = 12, Lifetime = 2, Speed = 0.6, Size = 0.3 })
	elseif aura == "Storm" then
		addParticles(
			chest,
			Color3.fromRGB(255, 255, 150),
			Color3.fromRGB(255, 230, 40),
			{ Rate = 6, Lifetime = 0.25, Speed = 8, Size = 0.4 }
		)
		addLight(chest, Color3.fromRGB(255, 240, 120), 12)
	elseif aura == "Starfall" then
		addSparkles(chest, Color3.fromRGB(255, 215, 90))
	elseif aura == "Cosmic" then
		addParticles(
			chest,
			Color3.fromRGB(255, 120, 230),
			Color3.fromRGB(110, 60, 255),
			{ Rate = 20, Lifetime = 2, Speed = 1, Size = 0.5 }
		)
		addLight(chest, Color3.fromRGB(170, 90, 255), 14)
	end
end

local function buildFromParts(genes: Genes.DragonGenes): Model
	local body = Genes.Get("Body", genes.Body)
	local accent = Genes.Get("Accent", genes.Accent)

	local model = Instance.new("Model")
	model.Name = "Dragon"

	-- Body: chest, hips and a belly plate underneath.
	local chest = ellipsoid(model, "Chest", Vector3.new(2.6, 2.4, 2.8), CHEST, body)
	ellipsoid(model, "Hips", Vector3.new(2.4, 2.1, 2.5), Vector3.new(0, 2.65, 1), body)
	ellipsoid(model, "Belly", Vector3.new(2, 1.5, 3.6), Vector3.new(0, 2.25, 0), accent)

	local head = buildHead(model, body, accent)
	buildLegs(model, body)
	buildSpine(model, accent)
	buildHorns(model, genes.Horns, accent, head)
	-- Wings and tail are tagged (attribute "Rig") and get an invisible joint part,
	-- so DragonAnimator can flap the wings at the shoulders and sway the tail at its base.
	for _, side in { -1, 1 } do
		local tag = if side == 1 then "RightWing" else "LeftWing"
		buildRigged(model, tag, Vector3.new(side * 1, 3.75, -0.9), function()
			buildWing(model, side, genes.Wings, body, accent)
		end)
	end
	buildRigged(model, "Tail", Vector3.new(0, 2.65, 1.5), function()
		buildTail(model, genes.Tail, body, accent)
	end)
	addAura(chest, genes.Aura)

	-- Pivot on the ground under the middle of the dragon, then grow/shrink to its size.
	model.PrimaryPart = chest
	chest.PivotOffset = CFrame.new(-CHEST)
	local scale = Genes.Get("Size", genes.Size).Scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

-- ===== Dragons from the Tripo model =====

local MESH_DRAGON_LENGTH = 11 -- studs: longest side of a Normal-size mesh dragon (like the part dragon)
local ACCENT_MESHES = { LeftWing = true, RightWing = true }

-- A MaterialVariant (skin texture) made in Studio's Material Manager, or nil if there isn't one.
local reportedSkins: { [string]: boolean } = {}
local function findSkinVariant(name: string): MaterialVariant?
	local ok, variant = pcall(function()
		return game:GetService("MaterialService"):FindFirstChild(name)
	end)
	local found = if ok and variant and variant:IsA("MaterialVariant") then variant else nil
	-- Say once in the Output window whether the skin was found (helps when it doesn't show).
	if ok and not reportedSkins[name] then
		reportedSkins[name] = true
		print(
			if found
				then `[Dragons] Skin "{name}" found: dragons wear it.`
				else `[Dragons] No skin "{name}" in MaterialService.`
		)
	end
	return found
end

-- Puts the skin texture on a part, unless its gene has a special material of its own.
local function applySkin(part: BasePart, option: GeneOption, variant: MaterialVariant?)
	if variant and (option.Material == nil or option.Material == Enum.Material.SmoothPlastic) then
		part.Material = variant.BaseMaterial
		part.MaterialVariant = variant.Name
	end
end
-- Tripo's pieces don't quite meet; growing each body piece a little closes the slits between them.
local SEAM_OVERLAP = 1.03
-- Name of a small part placed in the template on one eye socket (the other eye is mirrored).
local EYE_MARKERS = { "Eye", "RightEye", "LeftEye" }

-- World-space box around a part (works for rotated parts).
local function boundsOf(part: BasePart): (Vector3, Vector3)
	local half = part.Size / 2
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = part.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	return low, high
end

local function findTripoTemplate(): Model?
	-- Shared code also runs in tests outside Roblox, where there is no `game`.
	local ok, storage = pcall(function()
		return game:GetService("ReplicatedStorage")
	end)
	if not ok or not storage then
		return nil
	end
	local template = storage:FindFirstChild("TripoDragon")
	if template and template:IsA("Model") and template:FindFirstChild("Body") then
		return template
	end
	return nil
end

-- Scans the Tripo head by "feeling" it with rays, once per template:
--   1. the tip of the snout (the most forward point of the head),
--   2. the eye: a bit behind and above the tip, on the side of the head,
--   3. the top of the skull at the back of the head (where a crown or halo should sit;
--      the top of the mesh's box is the tip of its horns, which is far too high).
-- Rays only hit things in the Workspace, so a temporary invisible copy of the head is used.
-- Positions are returned relative to the HeadNeck mesh.
type HeadScan = { Eye: Vector3?, EyeSize: number?, Top: Vector3? }
local headScans: { [Model]: HeadScan } = {}

local function scanHead(template: Model): HeadScan
	local cached = headScans[template]
	if cached then
		return cached
	end
	local result: HeadScan = {}
	headScans[template] = result

	local head = template:FindFirstChild("HeadNeck")
	local body = template:FindFirstChild("Body")
	if not head or not body or not head:IsA("BasePart") or not body:IsA("BasePart") then
		return result
	end

	pcall(function()
		local probe = head:Clone()
		probe.Anchored = true
		probe.CanQuery = true
		probe.Transparency = 1
		probe.Parent = workspace
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { probe }

		local headCenter = head.CFrame.Position
		local flat = (headCenter - body.CFrame.Position) * Vector3.new(1, 0, 1)
		local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.yAxis)
		local low, high = boundsOf(head)
		local height = high.Y - low.Y
		local reach = (high - low).Magnitude + 1

		-- 1. The snout tip: the most forward point in the top half of the mesh. If several heights
		--    are (almost) equally far forward, take the middle of them.
		local hits: { { Y: number, Along: number } } = {}
		local tipForward = -math.huge
		for i = 0, 24 do
			local y = high.Y - height * 0.5 * i / 24
			local start = Vector3.new(headCenter.X, y, headCenter.Z) + forward * reach
			local hit = workspace:Raycast(start, -forward * reach * 2, params)
			if hit then
				local along = (hit.Position - headCenter):Dot(forward)
				table.insert(hits, { Y = y, Along = along })
				tipForward = math.max(tipForward, along)
			end
		end
		local sum, count = 0, 0
		for _, hit in hits do
			if hit.Along >= tipForward - height * 0.03 then
				sum += hit.Y
				count += 1
			end
		end
		if count > 0 then
			local tipY = sum / count
			local eyes = Config.Dragons.MeshEyes
			local behind = forward * (tipForward - height * eyes.Back)

			-- 2. The eye: onto the side of the head (a little lower each try, in case a spot misses).
			for try = 0, 4 do
				local spot = Vector3.new(headCenter.X, tipY + height * (eyes.Up - 0.04 * try), headCenter.Z) + behind
				local side = workspace:Raycast(spot + right * reach, -right * reach * 2, params)
				if side then
					result.EyeSize = height * eyes.Size
					local onSurface = side.Position - right * height * eyes.Size * 0.25
					result.Eye = head.CFrame:PointToObjectSpace(onSurface)
					break
				end
			end

			-- 3. The top of the skull at the back of the head (by the horns), straight down from
			--    above, on the centre line.
			local above = Vector3.new(headCenter.X, high.Y + 1, headCenter.Z)
				+ forward * (tipForward - height * eyes.TopBack)
			local top = workspace:Raycast(above, Vector3.new(0, -(height + 2), 0), params)
			if top then
				result.Top = head.CFrame:PointToObjectSpace(top.Position + Vector3.new(0, height * eyes.TopUp, 0))
			end
		end
		probe:Destroy()
	end)
	return result
end

-- The skin of the body and head, "felt" with rays once per template after the model is turned and
-- sized (so in the same space every build uses): rays from above and from both sides.
-- Pattern markings are stuck onto these points.
type SkinPoint = { Position: Vector3, Normal: Vector3, Host: string, Top: boolean, Row: number, Column: number }
local skinScans: { [Model]: { SkinPoint } } = {}
local SKIN_ROWS = 28 -- along the body
local SKIN_COLUMNS = 10 -- across the back (from above) or up the side

local function scanSkin(template: Model, model: Model): { SkinPoint }
	local cached = skinScans[template]
	if cached then
		return cached
	end
	local points: { SkinPoint } = {}
	skinScans[template] = points

	pcall(function()
		local probes: { Instance } = {}
		for _, name in { "Body", "HeadNeck" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local probe = part:Clone()
				probe:ClearAllChildren()
				probe.Name = name
				probe.Anchored = true
				probe.CanQuery = true
				probe.Transparency = 1
				probe.Parent = workspace
				table.insert(probes, probe)
			end
		end
		local body = model:FindFirstChild("Body")
		if #probes == 0 or not body or not body:IsA("BasePart") then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = probes

		local low, high = boundsOf(body)
		local size = high - low
		local reach = size.Magnitude + 2
		for row = 0, SKIN_ROWS - 1 do
			local z = low.Z + size.Z * (row + 0.5) / SKIN_ROWS
			for column = 0, SKIN_COLUMNS - 1 do
				local t = (column + 0.5) / SKIN_COLUMNS
				-- From above, across the middle 80% of the width.
				local x = low.X + size.X * (0.1 + 0.8 * t)
				local hit = workspace:Raycast(Vector3.new(x, high.Y + 1, z), Vector3.new(0, -reach, 0), params)
				if hit and hit.Normal.Y > 0.25 then
					table.insert(points, {
						Position = hit.Position,
						Normal = hit.Normal,
						Host = hit.Instance.Name,
						Top = true,
						Row = row,
						Column = column,
					})
				end
				-- From each side, over the upper 70% of the height.
				local y = low.Y + size.Y * (0.3 + 0.7 * t)
				for _, side in { -1, 1 } do
					local start = Vector3.new(side * reach, y, z)
					local sideHit = workspace:Raycast(start, Vector3.new(-side * reach * 2, 0, 0), params)
					if sideHit then
						table.insert(points, {
							Position = sideHit.Position,
							Normal = sideHit.Normal,
							Host = sideHit.Instance.Name,
							Top = false,
							Row = row,
							Column = column * side,
						})
					end
				end
			end
		end
		for _, probe in probes do
			probe:Destroy()
		end

		-- The rays hit Roblox's collision shape, which is made of flat facets, so neighbouring
		-- points can face quite different ways. Averaging each normal with its neighbours'
		-- gives a smooth skin, and the markings all lie flat instead of sticking out at angles.
		local smoothRadius = size.Magnitude * 0.06
		local smoothed = {}
		for i, point in points do
			local sum = Vector3.zero
			for _, other in points do
				if other.Host == point.Host and (other.Position - point.Position).Magnitude <= smoothRadius then
					sum += other.Normal
				end
			end
			smoothed[i] = if sum.Magnitude > 0.01 then sum.Unit else point.Normal
		end
		for i, point in points do
			point.Normal = smoothed[i]
		end
	end)
	return points
end

-- A stable number from a string, so a dragon's markings look the same every time it is built.
local function seedFrom(text: string): number
	local hash = 7
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

-- A flat marking lying on the skin at `point`, its length running along `along`.
local function skinMark(
	model: Model,
	point: SkinPoint,
	along: Vector3,
	size: Vector3, -- x: width, y: thickness, z: length
	kind: PartKind,
	option: GeneOption
): BasePart
	local up = point.Normal
	local length = (along - up * along:Dot(up))
	if length.Magnitude < 0.01 then
		length = Vector3.new(0, 0, -1) - up * -up.Z
	end
	local look = length.Unit
	local right = look:Cross(up).Unit
	-- Mostly sunk into the skin, so it hugs the curve instead of floating. (Rays hit the mesh's
	-- collision shape, which is only close to what you see: see README, CollisionFidelity.)
	local frame = CFrame.fromMatrix(point.Position - up * size.Y * 0.5, right, up)
	local part = newPart(model, "Pattern", kind, size, frame, option)
	local host = model:FindFirstChild(point.Host)
	local rig = host and host:GetAttribute("Rig")
	if rig then
		part:SetAttribute("Rig", rig)
	end
	return part
end

-- A thin glowing line on the skin from one point to another.
local function skinLine(model: Model, a: SkinPoint, b: SkinPoint, width: number, color: Color3, transparency: number?)
	local from = a.Position + a.Normal * width * 0.3
	local to = b.Position + b.Normal * width * 0.3
	local length = (to - from).Magnitude
	if length < 0.02 then
		return
	end
	local part = newPart(
		model,
		"Pattern",
		"Block",
		Vector3.new(width, width, length + width),
		CFrame.lookAt((from + to) / 2, to),
		look(color)
	)
	glow(part, color, transparency)
end

local function closest(points: { SkinPoint }, to: Vector3, skip: SkinPoint?): (SkinPoint?, number)
	local best, bestDistance = nil, math.huge
	for _, point in points do
		local distance = (point.Position - to).Magnitude
		if point ~= skip and distance < bestDistance then
			best, bestDistance = point, distance
		end
	end
	return best, bestDistance
end

-- Picks up to `count` random points that are at least `spacing` apart.
local function spreadOut(points: { SkinPoint }, count: number, spacing: number, rng: Random): { SkinPoint }
	local picked: { SkinPoint } = {}
	for _ = 1, count * 8 do
		if #picked >= count or #points == 0 then
			break
		end
		local candidate = points[rng:NextInteger(1, #points)]
		local _, distance = closest(picked, candidate.Position)
		if distance >= spacing then
			table.insert(picked, candidate)
		end
	end
	return picked
end

-- Rune shapes: line segments in a 1x1 square (u across, v up), like old carved letters.
local RUNES = {
	{ { 0.5, 0, 0.5, 1 }, { 0.5, 1, 0.9, 0.7 }, { 0.5, 0.6, 0.9, 0.3 } },
	{ { 0.2, 0, 0.2, 1 }, { 0.8, 0, 0.8, 1 }, { 0.2, 0.7, 0.8, 0.3 } },
	{ { 0.5, 0, 0.5, 1 }, { 0.1, 0.8, 0.5, 0.5 }, { 0.9, 0.8, 0.5, 0.5 } },
	{ { 0.2, 1, 0.8, 0.5 }, { 0.8, 0.5, 0.2, 0 }, { 0.2, 1, 0.2, 0 } },
	{ { 0.5, 0, 0.5, 1 }, { 0.15, 0.25, 0.85, 0.75 }, { 0.85, 0.25, 0.15, 0.75 } },
}

-- The markings of the Pattern gene, drawn in the Accent colour (glowing for the rare ones).
local function drawPattern(
	model: Model,
	template: Model,
	genes: Genes.DragonGenes,
	bodyLook: GeneOption,
	accent: GeneOption
)
	local pattern = genes.Pattern
	if pattern == nil or pattern == "Plain" then
		return
	end
	local skin = scanSkin(template, model)
	if #skin == 0 then
		return
	end
	local rng = Random.new(seedFrom(Genes.GetKey(genes)))
	-- The markings must stand out: if the accent is (almost) the body colour, darken it.
	local markLook = accent
	local bodyColor, accentColor = bodyLook.Color or WHITE, accent.Color or WHITE
	local difference = math.abs(bodyColor.R - accentColor.R)
		+ math.abs(bodyColor.G - accentColor.G)
		+ math.abs(bodyColor.B - accentColor.B)
	if difference < 0.25 then
		markLook = look(bodyColor:Lerp(BLACK, 0.45), bodyLook.Material)
	end
	local glowColor = markLook.Color or WHITE
	if glowColor.R + glowColor.G + glowColor.B < 0.6 then
		glowColor = glowColor:Lerp(WHITE, 0.6) -- a dark accent wouldn't glow
	end
	local forward = Vector3.new(0, 0, -1)

	local bodyPoints, topPoints = {}, {}
	for _, point in skin do
		if point.Host == "Body" then
			table.insert(bodyPoints, point)
			if point.Top then
				table.insert(topPoints, point)
			end
		end
	end

	if pattern == "Spots" then
		for _, point in spreadOut(skin, 24, 0.55, rng) do
			local d = rng:NextNumber(0.25, 0.55)
			skinMark(model, point, forward, Vector3.new(d, 0.14, d * rng:NextNumber(0.8, 1.3)), "Ellipsoid", markLook)
		end
	elseif pattern == "Stripes" then
		-- Bands around the back, like a tiger: every fourth row along the body, made of short
		-- pieces on every other column (the pieces are long enough to join up).
		for _, point in bodyPoints do
			local column = math.abs(point.Column)
			local onBack = point.Top or column >= SKIN_COLUMNS * 0.6
			if point.Row % 4 == 1 and column % 2 == 0 and onBack then
				local around = point.Normal:Cross(forward)
				if around.Magnitude > 0.1 then
					local length = rng:NextNumber(0.6, 0.8)
					skinMark(model, point, around, Vector3.new(0.26, 0.14, length), "Ellipsoid", markLook)
				end
			end
		end
	elseif pattern == "Scales" then
		-- Small overlapping plates over the back, each row shifted half a plate, in a colour
		-- between the skin and the accent so they read as scales, not stickers.
		local scaleColor = (bodyLook.Color or WHITE):Lerp(markLook.Color or WHITE, 0.5)
		local scaleLook = look(scaleColor, bodyLook.Material)
		local count = 0
		for _, point in topPoints do
			if (point.Column + point.Row) % 2 == 0 and count < 90 then
				skinMark(model, point, forward, Vector3.new(0.34, 0.07, 0.38), "Ellipsoid", scaleLook)
				count += 1
			end
		end
	elseif pattern == "Veins" then
		-- Glowing cracks, like lava under the skin: short wandering lines.
		local veinColor = Color3.fromRGB(255, 120, 30)
		for _, start in spreadOut(bodyPoints, 6, 1.2, rng) do
			local current = start
			local heading = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			for _ = 1, 6 do
				local goal = current.Position + heading.Unit * 0.5
				local nextPoint = closest(bodyPoints, goal, current)
				if not nextPoint or (nextPoint.Position - current.Position).Magnitude > 0.9 then
					break
				end
				skinLine(model, current, nextPoint, 0.07, veinColor)
				heading = (heading.Unit + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), 0)).Unit
				current = nextPoint
			end
		end
	elseif pattern == "Runes" then
		-- Old glowing letters on the flanks.
		local flanks = {}
		for _, point in bodyPoints do
			if not point.Top and math.abs(point.Normal.X) > 0.6 then
				table.insert(flanks, point)
			end
		end
		for _, point in spreadOut(flanks, 6, 1.3, rng) do
			local up = point.Normal
			local u = Vector3.new(0, 0, -1)
			u = (u - up * u:Dot(up)).Unit
			local v = up:Cross(u).Unit
			local size = 0.55
			for _, bar in RUNES[rng:NextInteger(1, #RUNES)] do
				local a = point.Position + (u * (bar[1] - 0.5) + v * (bar[2] - 0.5)) * size
				local b = point.Position + (u * (bar[3] - 0.5) + v * (bar[4] - 0.5)) * size
				local from = { Position = a, Normal = up, Host = point.Host, Top = false, Row = 0, Column = 0 }
				local to = { Position = b, Normal = up, Host = point.Host, Top = false, Row = 0, Column = 0 }
				skinLine(model, from, to, 0.06, glowColor)
			end
		end
	elseif pattern == "Starmap" then
		-- Tiny stars all over, and a few of them joined into constellations.
		local stars = spreadOut(skin, 34, 0.35, rng)
		for _, point in stars do
			local d = rng:NextNumber(0.08, 0.16)
			local star = skinMark(model, point, forward, Vector3.new(d, d, d), "Ball", look(WHITE))
			glow(star, Color3.fromRGB(235, 240, 255))
		end
		for i = 1, math.min(3, #stars) do
			local current = stars[i]
			for _ = 1, 3 do
				local nextStar = closest(stars, current.Position, current)
				if not nextStar then
					break
				end
				skinLine(model, current, nextStar, 0.03, glowColor, 0.35)
				current = nextStar
			end
		end
	end
end

local function buildFromMesh(template: Model, genes: Genes.DragonGenes): Model
	local bodyLook = Genes.Get("Body", genes.Body)
	local accent = Genes.Get("Accent", genes.Accent)
	local skinVariant = findSkinVariant(Config.Dragons.SkinVariant)
	local wingVariant = findSkinVariant(Config.Dragons.WingVariant)

	local model = template:Clone()
	model.Name = "Dragon"
	local bodyMesh = model:FindFirstChild("Body") :: BasePart
	local headMesh = model:FindFirstChild("HeadNeck") :: BasePart?
	local eyeMarker: BasePart?
	for _, name in EYE_MARKERS do
		local found = model:FindFirstChild(name)
		if found and found:IsA("BasePart") then
			eyeMarker = found
			break
		end
	end
	-- A hand-placed marker that is obviously too big for an eye is ignored.
	if eyeMarker and headMesh then
		local low, high = boundsOf(headMesh)
		if math.max(eyeMarker.Size.X, eyeMarker.Size.Y, eyeMarker.Size.Z) > (high.Y - low.Y) * 0.3 then
			eyeMarker:Destroy()
			eyeMarker = nil
		end
	end
	-- Scan the head: put an eye marker where the eye was found (unless one was placed by hand),
	-- and an invisible marker on top of the skull for crowns and halos.
	local topMarker: BasePart?
	if headMesh then
		local scan = scanHead(template)
		if not eyeMarker and scan.Eye and scan.EyeSize then
			eyeMarker = newPart(
				model,
				"Eye",
				"Ball",
				Vector3.one * scan.EyeSize,
				CFrame.new(headMesh.CFrame:PointToWorldSpace(scan.Eye)),
				look(WHITE)
			)
		end
		if scan.Top then
			topMarker = newPart(
				model,
				"HeadTop",
				"Block",
				Vector3.one * 0.1,
				CFrame.new(headMesh.CFrame:PointToWorldSpace(scan.Top)),
				look(WHITE)
			)
		end
	end

	-- Colour every mesh by the genes, and make them pure decoration (no physics).
	for _, part in model:GetDescendants() do
		if part:IsA("SurfaceAppearance") then
			part:Destroy() -- a texture would hide the gene colours
		elseif part:IsA("BasePart") then
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.Massless = true
			local isWing = ACCENT_MESHES[part.Name] == true
			-- A skin left on the template by hand is ignored; the code decides (applySkin below).
			part.MaterialVariant = ""
			applyLook(part, if isWing then accent else bodyLook)
			if part ~= eyeMarker and part ~= topMarker then
				applySkin(part, if isWing then accent else bodyLook, if isWing then wingVariant else skinVariant)
			end
			if part ~= eyeMarker and part ~= topMarker and not ACCENT_MESHES[part.Name] then
				part.Size *= SEAM_OVERLAP
			end
		end
	end

	-- 1. Turn it to face -Z (the way the head points), stand it on y = 0, centre the body.
	local boxFrame, boxSize = model:GetBoundingBox()
	local groundY = boxFrame.Position.Y - boxSize.Y / 2
	local bodyCenter = bodyMesh.CFrame.Position
	local forward = if headMesh then (headMesh.CFrame.Position - bodyCenter) * Vector3.new(1, 0, 1) else Vector3.zero
	if forward.Magnitude < 0.01 then
		forward = Vector3.new(0, 0, -1)
	end
	local ground = Vector3.new(bodyCenter.X, groundY, bodyCenter.Z)
	if model.PrimaryPart then
		model.PrimaryPart = nil -- so WorldPivot below is used as the pivot
	end
	model.WorldPivot = CFrame.lookAt(ground, ground + forward.Unit)
	model:PivotTo(CFrame.new())
	model.PrimaryPart = bodyMesh
	bodyMesh.PivotOffset = bodyMesh.CFrame:Inverse()

	-- 2. Same size as every other Normal dragon.
	local _, size = model:GetBoundingBox()
	local normalize = MESH_DRAGON_LENGTH / math.max(size.X, size.Y, size.Z)
	model:ScaleTo(normalize)

	-- 3. Wings: tag them for the animator and put a shoulder joint at their inner edge.
	--    Which side a wing is on is worked out from where it is, not from its name.
	for _, name in { "LeftWing", "RightWing" } do
		local wing = model:FindFirstChild(name)
		if wing and wing:IsA("BasePart") then
			local low, high = boundsOf(wing)
			local onRight = (low.X + high.X) / 2 > 0
			local tag = if onRight then "RightWing" else "LeftWing"
			wing:SetAttribute("Rig", tag)
			local joint = Vector3.new(
				if onRight then low.X + (high.X - low.X) * 0.08 else high.X - (high.X - low.X) * 0.08,
				low.Y + (high.Y - low.Y) * 0.3,
				(low.Z + high.Z) / 2
			)
			local jointPart = newPart(model, tag .. "Joint", "Block", Vector3.one * 0.2, CFrame.new(joint), look(WHITE))
			jointPart.Transparency = 1
		end
	end

	-- 3b. Eyes: glossy amber with a dark slit pupil and a tiny white shine, on the marked
	-- eye socket and its mirror image. (Neon made them glow so much the pupil disappeared.)
	if eyeMarker then
		local marked = eyeMarker.CFrame.Position
		local diameter = math.max(eyeMarker.Size.X, eyeMarker.Size.Y, eyeMarker.Size.Z)
		eyeMarker:Destroy()
		for _, side in { 1, -1 } do
			local position = Vector3.new(math.abs(marked.X) * side, marked.Y, marked.Z)
			newPart(model, "Eye", "Ball", Vector3.one * diameter, CFrame.new(position), look(EYE, Enum.Material.Glass))
			-- The pupil sits on the outside of the eye, facing sideways and a little forward.
			-- It is a thin slab that crosses the eye's surface, so it shows clearly but stays
			-- inside the eye's outline.
			local outward = Vector3.new(side, 0, -0.35).Unit
			local pupilAt = position + outward * diameter * 0.45
			local facing = CFrame.lookAt(pupilAt, pupilAt + outward)
			newPart(
				model,
				"Pupil",
				"Block",
				Vector3.new(diameter * 0.2, diameter * 0.6, diameter * 0.14),
				facing,
				look(BLACK)
			)
			-- A small shine at the top front of the eye makes it look wet and alive.
			local shine = newPart(
				model,
				"EyeShine",
				"Ball",
				Vector3.one * diameter * 0.18,
				facing * CFrame.new(-side * diameter * 0.16, diameter * 0.16, -diameter * 0.04),
				look(WHITE)
			)
			glow(shine, WHITE)
		end
	end

	-- 3c. Skin markings (the Pattern gene).
	drawPattern(model, template, genes, bodyLook, accent)

	-- 4. Extras for rare genes, placed relative to the head and the back of the body.
	if headMesh and (genes.Horns == "Halo" or genes.Horns == "Crown" or genes.Horns == "Crystal") then
		local headTop: Vector3
		if topMarker then
			headTop = topMarker.CFrame.Position
		else
			-- No scan (e.g. outside Roblox): a rough guess below the horn tips.
			local low, high = boundsOf(headMesh)
			headTop = Vector3.new(0, low.Y + (high.Y - low.Y) * 0.8, low.Z + (high.Z - low.Z) * 0.35)
		end
		-- buildHorns draws around the part-dragon's head; move what it makes onto this head.
		local made = collectParts(function()
			buildHorns(model, genes.Horns, accent, headMesh)
		end)
		local shift = headTop - Vector3.new(0, 6.25, -3.2)
		for _, part in made do
			part.CFrame = part.CFrame + shift
		end
	end
	if topMarker then
		topMarker:Destroy()
	end
	if genes.Tail == "Flame" or genes.Tail == "Comet" then
		local low, high = boundsOf(bodyMesh)
		local tip = Vector3.new(0, low.Y + (high.Y - low.Y) * 0.35, high.Z - 0.2)
		local tipPart = newPart(model, "TailTip", "Ball", Vector3.one * 0.7, CFrame.new(tip), accent)
		glow(tipPart, if genes.Tail == "Flame" then FLAME else accent.Color or WHITE)
		if genes.Tail == "Flame" then
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 4
			fire.Color = FLAME
			fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
			fire.Parent = tipPart
		else
			addParticles(
				tipPart,
				WHITE,
				accent.Color or WHITE,
				{ Rate = 25, Lifetime = 1.2, Speed = 1, Size = 0.6, Spread = 15 }
			)
		end
	end
	addAura(bodyMesh, genes.Aura)

	-- 5. The dragon's own size gene.
	local scale = Genes.Get("Size", genes.Size).Scale or 1
	model:ScaleTo(normalize * scale)
	return model
end

function DragonBuilder.Build(genes: Genes.DragonGenes): Model
	-- Genes saved before a trait existed (e.g. no Pattern) still build.
	genes = Genes.Upgrade(table.clone(genes))
	local template = findTripoTemplate()
	local model = if template then buildFromMesh(template, genes) else buildFromParts(genes)

	local rarity = Genes.GetRarity(genes)
	model:SetAttribute("DragonName", Genes.GetName(genes))
	model:SetAttribute("Rarity", rarity.Name)
	return model
end

-- Floating name + rarity label above a dragon built by DragonBuilder.Build.
-- Only shows up close, so a crowd of dragons doesn't turn into a wall of text.
function DragonBuilder.AddNameTag(model: Model, genes: Genes.DragonGenes)
	local chest = model.PrimaryPart
	if not chest then
		return
	end
	local rarity: Rarity.Tier = Genes.GetRarity(genes)
	local scale = Genes.Get("Size", genes.Size).Scale or 1

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(180, 44)
	-- Just above the top of the dragon, whichever way it was built.
	local _, size = model:GetBoundingBox()
	local chestHeight = chest.CFrame.Position.Y - model:GetPivot().Position.Y
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y - chestHeight + scale, 0)
	billboard.MaxDistance = 40 * math.max(scale, 1)
	billboard.Adornee = chest

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.FontFace = Fonts.Title
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = WHITE
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = Genes.GetName(genes)
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Position = UDim2.fromScale(0, 0.55)
	rarityLabel.Size = UDim2.fromScale(1, 0.45)
	rarityLabel.FontFace = Fonts.Body
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.Color
	rarityLabel.TextStrokeTransparency = 0.3
	rarityLabel.Text = rarity.Name
	rarityLabel.Parent = billboard

	billboard.Parent = chest
end

return DragonBuilder
