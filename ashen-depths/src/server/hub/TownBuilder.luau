--!strict
-- Builds Emberhold's town square when the server starts: a cobbled square at dusk with the Great Well (the
-- way down, The Descent) in the middle and the gate guard beside it, Brakka's Forge on the north side, the
-- other shops' houses around it (closed for now), lamp posts, and the lighting and fog of a mining town at dusk.
-- Tripo models come from ServerStorage.TownProps (GreatWell, Anvil, Forge, WeaponRack, Brakka, GateGuard,
-- GuardSpear); anything missing is built from plain parts.
-- Returns the spots other services hang their prompts on.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local TownBuilder = {}

export type Town = {
	Model: Model,
	Spawn: CFrame,
	Well: BasePart, -- the well's rim (for the Descend prompt)
	Brakka: BasePart, -- where Brakka stands (for the Trade prompt)
}

local STONE = Color3.fromRGB(78, 74, 70)
local DARK_STONE = Color3.fromRGB(52, 50, 48)
local TIMBER = Color3.fromRGB(58, 40, 28)
local PLASTER = Color3.fromRGB(150, 132, 108)
local ROOF = Color3.fromRGB(64, 44, 38)
local WARM = Color3.fromRGB(255, 176, 96)

local SQUARE = 150 -- the square's width

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material
	w.Parent = parent
	return w
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
end

-- A Tripo prop from ServerStorage.TownProps, bottom-center on `cframe` (turned like it). Nil if missing.
local function prop(name: string, parent: Instance, cframe: CFrame): Model?
	local folder = ServerStorage:FindFirstChild("TownProps")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	copy:PivotTo(cframe)
	local box, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() + (cframe.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	copy.Parent = parent
	return copy
end

-- A sign with painted letters, hung on a bracket.
local function sign(parent: Instance, text: string, cframe: CFrame)
	local board = part(parent, "Sign", Vector3.new(8, 2.2, 0.3), cframe, TIMBER, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 200, 130)
	label.Text = text
	label.Parent = gui
	gui.Parent = board
	part(parent, "SignBracket", Vector3.new(0.3, 0.3, 1.4), cframe * CFrame.new(0, 1.3, 0.6), Color3.fromRGB(40, 38, 36), Enum.Material.Metal)
end

-- A two-storey house front facing the square: stone ground floor, timber-framed plaster upstairs, a steep
-- roof, a door, and warm lit windows. `name` goes on its sign (nil for a plain house).
local function house(parent: Instance, frame: CFrame, width: number, name: string?)
	local m = Instance.new("Model")
	m.Name = name or "House"
	local depth = 16
	local lower, upper = 10, 9
	part(m, "Ground", Vector3.new(width, lower, depth), frame * CFrame.new(0, lower / 2, depth / 2), STONE, Enum.Material.Cobblestone)
	part(m, "Upper", Vector3.new(width, upper, depth - 1), frame * CFrame.new(0, lower + upper / 2, depth / 2 - 0.6), PLASTER, Enum.Material.Plaster)
	-- timber frame on the upper front
	for x = -width / 2 + 0.4, width / 2 - 0.4, width / 4 do
		part(m, "Beam", Vector3.new(0.7, upper, 0.4), frame * CFrame.new(x, lower + upper / 2, -1.2), TIMBER, Enum.Material.Wood)
	end
	part(m, "Beam", Vector3.new(width, 0.7, 0.5), frame * CFrame.new(0, lower + 0.3, -1.2), TIMBER, Enum.Material.Wood)
	part(m, "Beam", Vector3.new(width, 0.7, 0.5), frame * CFrame.new(0, lower + upper - 0.3, -1.2), TIMBER, Enum.Material.Wood)
	-- the roof: two slopes meeting over the middle
	local roofH = 7
	for _, side in { -1, 1 } do
		wedge(m, "Roof", Vector3.new(width + 1.2, roofH, depth / 2 + 0.6), frame * CFrame.new(0, lower + upper + roofH / 2, depth / 2 + side * (depth / 4 + 0.3)) * CFrame.Angles(0, if side < 0 then math.pi else 0, 0), ROOF, Enum.Material.Slate)
	end
	-- door and windows
	part(m, "Door", Vector3.new(4, 7, 0.4), frame * CFrame.new(0, 3.5, -0.1), Color3.fromRGB(46, 30, 20), Enum.Material.WoodPlanks)
	for _, x in { -width / 2 + 4, width / 2 - 4 } do
		local win = part(m, "Window", Vector3.new(3, 3, 0.2), frame * CFrame.new(x, 5, -0.05), WARM, Enum.Material.Neon)
		win.Transparency = 0.35
		win.CastShadow = false
	end
	for _, x in { -width / 4, width / 4 } do
		local win = part(m, "Window", Vector3.new(2.6, 3, 0.2), frame * CFrame.new(x, lower + upper / 2, -1.45), WARM, Enum.Material.Neon)
		win.Transparency = 0.4
		win.CastShadow = false
		light(win, WARM, 14, 0.6)
	end
	if name then
		sign(m, name, frame * CFrame.new(0, 8.6, -1.6) * CFrame.Angles(0, math.pi, 0))
	end
	m.Parent = parent
end

-- An iron lamp post with a burning lantern.
local function lampPost(parent: Instance, position: Vector3)
	part(parent, "LampPost", Vector3.new(0.5, 11, 0.5), CFrame.new(position + Vector3.new(0, 5.5, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	part(parent, "LampFoot", Vector3.new(1.4, 0.8, 1.4), CFrame.new(position + Vector3.new(0, 0.4, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local lantern = part(parent, "Lantern", Vector3.new(1, 1.4, 1), CFrame.new(position + Vector3.new(0, 11.4, 0)), WARM, Enum.Material.Neon)
	lantern.Transparency = 0.15
	lantern.CastShadow = false
	part(parent, "LanternCap", Vector3.new(1.4, 0.4, 1.4), CFrame.new(position + Vector3.new(0, 12.3, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	light(lantern, WARM, 30, 1.4, true)
end

-- A fire bowl on a stone stand, its fire and warm light.
local function brazier(parent: Instance, position: Vector3)
	part(parent, "BrazierStand", Vector3.new(1.6, 3, 1.6), CFrame.new(position + Vector3.new(0, 1.5, 0)), DARK_STONE, Enum.Material.Slate)
	local bowl = part(parent, "Brazier", Vector3.new(0.8, 3, 3), CFrame.new(position + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 36, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 8
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = bowl
	light(bowl, Color3.fromRGB(255, 150, 80), 28, 1.5, true)
end

-- A stand-in figure (until the Tripo character is rigged): a robed body and a head, facing `cframe`'s front.
local function standIn(parent: Instance, name: string, cframe: CFrame, height: number, color: Color3): BasePart
	local m = Instance.new("Model")
	m.Name = name
	local body = part(m, "Body", Vector3.new(height * 0.4, height * 0.7, height * 0.28), cframe * CFrame.new(0, height * 0.35, 0), color, Enum.Material.Fabric)
	part(m, "Head", Vector3.new(height * 0.24, height * 0.24, height * 0.24), cframe * CFrame.new(0, height * 0.82, 0), Color3.fromRGB(196, 150, 120), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	m.Parent = parent
	return body
end

local function setLighting()
	Lighting.ClockTime = 18.4
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(60, 50, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 80, 86)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.5
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(150, 120, 120)
	atmosphere.Decay = Color3.fromRGB(90, 60, 70)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.TintColor = Color3.fromRGB(255, 236, 222)
	grade.Contrast = 0.12
	grade.Saturation = -0.05
	grade.Parent = Lighting
end

-- Brakka's Forge: an open-fronted smithy on the north side of the square, with the forge glowing at the back,
-- the anvil out front, a rack of weapons, and Brakka behind the anvil. Returns where she stands.
local function forge(parent: Instance, frame: CFrame): BasePart
	local m = Instance.new("Model")
	m.Name = "BrakkasForge"
	local w, d, h = 26, 16, 12
	-- back and side walls of stone, a timber front beam, a sloped roof
	part(m, "BackWall", Vector3.new(w, h, 1.5), frame * CFrame.new(0, h / 2, d), STONE, Enum.Material.Cobblestone)
	for _, side in { -1, 1 } do
		part(m, "SideWall", Vector3.new(1.5, h, d), frame * CFrame.new(side * w / 2, h / 2, d / 2), STONE, Enum.Material.Cobblestone)
		part(m, "Post", Vector3.new(1.2, h, 1.2), frame * CFrame.new(side * (w / 2 - 0.6), h / 2, 0), TIMBER, Enum.Material.Wood)
	end
	part(m, "FrontBeam", Vector3.new(w, 1.2, 1.2), frame * CFrame.new(0, h - 0.6, 0), TIMBER, Enum.Material.Wood)
	local roof = part(m, "Roof", Vector3.new(w + 2, 0.8, d + 4), frame * CFrame.new(0, h + 1.6, d / 2) * CFrame.Angles(math.rad(-12), 0, 0), ROOF, Enum.Material.Slate)
	roof.CastShadow = true
	part(m, "Floor", Vector3.new(w, 0.3, d), frame * CFrame.new(0, 0.15, d / 2), DARK_STONE, Enum.Material.Slate)
	sign(m, "Brakka's Forge", frame * CFrame.new(0, h + 0.2, -0.8) * CFrame.Angles(0, math.pi, 0))

	-- the forge at the back, the anvil in front of Brakka, the weapon rack by the wall
	local back = frame * CFrame.new(-5, 0, d - 3.5)
	local forgeModel = prop("Forge", m, back * CFrame.Angles(0, math.pi, 0))
	local glowAt: BasePart
	if forgeModel then
		glowAt = forgeModel:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		part(m, "ForgeBody", Vector3.new(7, 5, 5), back * CFrame.new(0, 2.5, 0), DARK_STONE, Enum.Material.Brick)
		glowAt = part(m, "ForgeCoals", Vector3.new(4, 0.6, 3), back * CFrame.new(0, 4.6, -0.5), Color3.fromRGB(255, 110, 40), Enum.Material.Neon)
		part(m, "Chimney", Vector3.new(3, 8, 3), back * CFrame.new(0, 9, 0.5), DARK_STONE, Enum.Material.Brick)
	end
	local ember = part(m, "ForgeGlow", Vector3.new(1, 1, 1), back * CFrame.new(0, 3.5, -2.5), Color3.new(), Enum.Material.SmoothPlastic)
	ember.Transparency = 1
	ember.CanCollide = false
	light(ember, Color3.fromRGB(255, 120, 50), 26, 2.2, true)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.12, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 14
	sparks.Parent = ember
	local _ = glowAt

	local anvilSpot = frame * CFrame.new(2, 0, 4)
	if not prop("Anvil", m, anvilSpot * CFrame.Angles(0, math.rad(90), 0)) then
		part(m, "Anvil", Vector3.new(3, 1.2, 1.4), anvilSpot * CFrame.new(0, 2.4, 0), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		part(m, "AnvilStump", Vector3.new(1.6, 1.8, 1.6), anvilSpot * CFrame.new(0, 0.9, 0), TIMBER, Enum.Material.Wood)
	end
	if not prop("WeaponRack", m, frame * CFrame.new(w / 2 - 3.5, 0, d / 2) * CFrame.Angles(0, math.rad(90), 0)) then
		part(m, "Rack", Vector3.new(0.6, 5, 6), frame * CFrame.new(w / 2 - 3.5, 2.5, d / 2), TIMBER, Enum.Material.Wood)
	end

	-- Brakka, behind the anvil and facing the square
	local brakkaAt = frame * CFrame.new(2, 0, 7) * CFrame.Angles(0, math.pi, 0)
	local figure = prop("Brakka", m, brakkaAt)
	local spot: BasePart
	if figure then
		spot = figure:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		spot = standIn(m, "Brakka", brakkaAt, 4.6, Color3.fromRGB(80, 50, 36))
	end
	m.Parent = parent
	return spot
end

function TownBuilder.Build(): Town
	setLighting()
	local old = workspace:FindFirstChild("Town")
	if old then
		old:Destroy()
	end
	local base = workspace:FindFirstChild("Baseplate") :: BasePart?
	if base then
		base.Color = Color3.fromRGB(46, 40, 34)
		base.Material = Enum.Material.Ground
	end
	local model = Instance.new("Model")
	model.Name = "Town"

	-- the square: big cobbles, a ring of paler stones round the well
	part(model, "Square", Vector3.new(SQUARE, 1, SQUARE), CFrame.new(0, -0.45, 0), Color3.fromRGB(70, 64, 58), Enum.Material.Cobblestone)
	part(model, "WellRing", Vector3.new(0.2, 34, 34), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(96, 90, 82), Enum.Material.Slate, Enum.PartType.Cylinder)

	-- The Great Well in the middle: the way down into the Depths
	local wellModel = prop("GreatWell", model, CFrame.new(0, 0, 0))
	local rim: BasePart
	if wellModel then
		rim = wellModel:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		rim = part(model, "WellRim", Vector3.new(4, 16, 16), CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
		local hole = part(model, "WellDark", Vector3.new(4.2, 12, 12), CFrame.new(0, 2.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		hole.CanCollide = false
	end
	-- a faint warm glow rising from deep inside
	local depthsGlow = part(model, "DepthsGlow", Vector3.new(1, 1, 1), CFrame.new(0, -1, 0), Color3.new(), Enum.Material.SmoothPlastic)
	depthsGlow.Transparency = 1
	depthsGlow.CanCollide = false
	light(depthsGlow, Color3.fromRGB(255, 120, 60), 20, 1.4)
	for _, a in { 45, 135, 225, 315 } do
		local r = math.rad(a)
		brazier(model, Vector3.new(math.cos(r) * 15, 0, math.sin(r) * 15))
	end

	-- the gate guard keeps watch at the well, on the side facing the town's entrance (south)
	local guardAt = CFrame.lookAt(Vector3.new(9, 0, 11), Vector3.new(9, 0, 30))
	local guard = prop("GateGuard", model, guardAt)
	if not guard then
		standIn(model, "GateGuard", guardAt, 6.4, Color3.fromRGB(110, 30, 30))
	end

	-- Brakka's Forge on the north side
	local brakka = forge(model, CFrame.new(0, 0, -SQUARE / 2 + 2))

	-- the other shops and houses around the square (opening in later updates)
	local h = SQUARE / 2 - 2
	house(model, CFrame.new(-44, 0, -h), 30, "Guild Hall")
	house(model, CFrame.new(44, 0, -h), 30, "Ironhide Armory")
	house(model, CFrame.new(-h, 0, -20) * CFrame.Angles(0, math.rad(90), 0), 28, "The Gilded Tome")
	house(model, CFrame.new(-h, 0, 20) * CFrame.Angles(0, math.rad(90), 0), 28, nil)
	house(model, CFrame.new(h, 0, -20) * CFrame.Angles(0, math.rad(-90), 0), 28, "The Sunken Tankard")
	house(model, CFrame.new(h, 0, 20) * CFrame.Angles(0, math.rad(-90), 0), 28, nil)
	house(model, CFrame.new(-44, 0, h) * CFrame.Angles(0, math.pi, 0), 30, nil)
	house(model, CFrame.new(44, 0, h) * CFrame.Angles(0, math.pi, 0), 30, nil)

	-- lamp posts round the square
	for _, at in { Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30), Vector3.new(0, 0, 40), Vector3.new(-50, 0, 0), Vector3.new(50, 0, 0) } do
		lampPost(model, at)
	end

	model.Parent = workspace

	-- players arrive at the south end of the square, looking at the well
	local spawn = CFrame.lookAt(Vector3.new(0, 3, 52), Vector3.new(0, 3, 0))
	local spawnPart = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnPart then
		spawnPart.CFrame = CFrame.new(0, 0.5, 52)
		spawnPart.Transparency = 1
		spawnPart.CanCollide = false
		local decal = spawnPart:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end
	return { Model = model, Spawn = spawn, Well = rim, Brakka = brakka }
end

return TownBuilder
