--!strict
-- Builds Emberhold when the server starts: a village on a grass meadow, late in the afternoon, with the Great Well (the
-- way down, The Descent) in the middle and the gate guard beside it, Brakka's Forge on the north side, the
-- other shops' houses around it (closed for now), lamp posts, and the lighting and fog of a mining town at dusk.
-- Tripo models come from ServerStorage.TownProps (GreatWell, Anvil, Forge, WeaponRack, Brakka, GateGuard,
-- GuardSpear); anything missing is built from plain parts.
-- Returns the spots other services hang their prompts on.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)

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

local SQUARE = 150 -- the square's width (as laid out; everything is then spread out by SPREAD)
local SPREAD = 1.25 -- how far apart the village is drawn: every piece's place from the Well times this

-- The townsfolk's standing animations (published from ServerStorage.TownClips).
local IDLE: { [string]: number } = {
	Brakka = 92067081387599, -- Mixamo "Standing W/ Briefcase Idle"
	GateGuard = 77116071943805, -- Mixamo "Standing Idle"
	Aldric = 110153111695731, -- Mixamo "Unarmed Idle"
	Thorne = 91422294151634, -- Mixamo "Dwarf Idle"
	Seraphine = 89523763247665, -- Mixamo "Happy Idle"
	OldPip = 106330872617044, -- Mixamo "Breathing Idle"
}

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
-- A Tripo building from TownProps with its front on the frame's front line (the frame's -Z faces the square),
-- optionally scaled to a width. Nil if there's no such model.
local function building(name: string, parent: Instance, frame: CFrame, width: number?): Model?
	local made = prop(name, parent, frame)
	if not made then
		return nil
	end
	local _, size = made:GetBoundingBox()
	if width then
		made:ScaleTo(made:GetScale() * width / size.X)
		made:PivotTo(frame)
		local box, scaled = made:GetBoundingBox()
		made:PivotTo(made:GetPivot() + (frame.Position - (box.Position - Vector3.new(0, scaled.Y / 2, 0))))
		size = scaled
	end
	made:PivotTo(made:GetPivot() * CFrame.new(0, 0, size.Z / 2 - 0.5))
	return made
end

local HOUSE_MODELS = { ["Guild Hall"] = "GuildHall", ["Ironhide Armory"] = "Armory", ["The Gilded Tome"] = "MagicShop", ["The Sunken Tankard"] = "Tavern" }
local plainHouse = 0

local function house(parent: Instance, frame: CFrame, width: number, name: string?)
	-- the real building when there is one (plain houses take turns between the two house models)
	local modelName = if name then HOUSE_MODELS[name] else nil
	if not modelName then
		plainHouse += 1
		modelName = if plainHouse % 2 == 1 then "HouseA" else "HouseB"
	end
	if building(modelName :: string, parent, frame) then
		return
	end
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

-- An iron lamp post with a burning lantern (the Tripo LampPost when there is one).
local function lampPost(parent: Instance, position: Vector3)
	local made = prop("LampPost", parent, CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	if made then
		local _, size = made:GetBoundingBox()
		local glow = part(parent, "LampGlow", Vector3.new(0.5, 0.5, 0.5), CFrame.new(position + Vector3.new(0, size.Y - 1.6, 0)), WARM, Enum.Material.SmoothPlastic)
		glow.Transparency = 1
		glow.CanCollide = false
		light(glow, WARM, 30, 1.4, true)
		return
	end
	part(parent, "LampPost", Vector3.new(0.5, 11, 0.5), CFrame.new(position + Vector3.new(0, 5.5, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	part(parent, "LampFoot", Vector3.new(1.4, 0.8, 1.4), CFrame.new(position + Vector3.new(0, 0.4, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local lantern = part(parent, "Lantern", Vector3.new(1, 1.4, 1), CFrame.new(position + Vector3.new(0, 11.4, 0)), WARM, Enum.Material.Neon)
	lantern.Transparency = 0.15
	lantern.CastShadow = false
	part(parent, "LanternCap", Vector3.new(1.4, 0.4, 1.4), CFrame.new(position + Vector3.new(0, 12.3, 0)), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	light(lantern, WARM, 30, 1.4, true)
end

-- A fire bowl on a stone stand, its fire and warm light.
-- The Wall of the Fallen beside the Guild Hall: a slab of dark stone carved with the names of adventurers
-- who never came back up. Far too many for a town this size. The oldest row, worn almost smooth, says A. Vane.
local FIRST = { "Ser", "Bram", "Edda", "Tomas", "Iska", "Rolf", "Mira", "Gault", "Wren", "Osric", "Lena", "Corin", "Hale", "Ysolde", "Dunn", "Petra", "Alis", "Fenn", "Garrick", "Nell", "Odo", "Rhea", "Sten", "Tilda", "Ulric", "Vera", "Jory", "Kael", "Mags", "Brin" }
local LAST = { "Ashby", "Morrow", "Crane", "Holt", "Vey", "Thatch", "Pike", "Marsh", "Rook", "Fell", "Stone", "Harrow", "Quill", "Barrow", "Lark", "Dunmore", "Wick", "Gale", "Cobb", "Penn" }

local function wallOfTheFallen(parent: Instance, frame: CFrame)
	local wall = Instance.new("Model")
	wall.Name = "WallOfTheFallen"
	part(wall, "Base", Vector3.new(11, 1, 2.6), frame * CFrame.new(0, 0.5, 0), DARK_STONE, Enum.Material.Slate)
	local slab = part(wall, "Slab", Vector3.new(10, 8, 1.4), frame * CFrame.new(0, 5, 0), Color3.fromRGB(58, 56, 58), Enum.Material.Slate)
	part(wall, "Cornice", Vector3.new(10.8, 0.7, 2), frame * CFrame.new(0, 9.35, 0), DARK_STONE, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		part(wall, "Pillar", Vector3.new(1, 8.5, 1.8), frame * CFrame.new(side * 5.3, 5.25, 0), DARK_STONE, Enum.Material.Slate)
	end
	-- the names, carved into the front
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.Parent = slab
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Position = UDim2.new(0, 0, 0, 14)
	head.Size = UDim2.new(1, 0, 0, 40)
	head.FontFace = Fonts.Title
	head.TextSize = 34
	head.TextColor3 = Color3.fromRGB(196, 186, 166)
	head.Text = "THEY WENT BELOW"
	head.Parent = gui
	local rng = Random.new(1040)
	local columns = 4
	local rows = 13
	for c = 0, columns - 1 do
		local names = {}
		for r = 1, rows do
			table.insert(names, `{FIRST[rng:NextInteger(1, #FIRST)]} {LAST[rng:NextInteger(1, #LAST)]}`)
		end
		local column = Instance.new("TextLabel")
		column.BackgroundTransparency = 1
		column.Position = UDim2.new(c / columns, 6, 0, 66)
		column.Size = UDim2.new(1 / columns, -12, 1, -120)
		column.FontFace = Fonts.Title -- carved
		column.TextSize = 17
		column.LineHeight = 1.05
		column.TextColor3 = Color3.fromRGB(176, 168, 152)
		column.TextTransparency = 0.1 + 0.08 * c
		column.TextYAlignment = Enum.TextYAlignment.Top
		column.Text = table.concat(names, "\n")
		column.Parent = gui
	end
	-- the oldest row, nearly worn away
	local oldest = Instance.new("TextLabel")
	oldest.BackgroundTransparency = 1
	oldest.AnchorPoint = Vector2.new(0, 1)
	oldest.Position = UDim2.new(0, 0, 1, -14)
	oldest.Size = UDim2.new(1, 0, 0, 30)
	oldest.FontFace = Fonts.Title
	oldest.TextSize = 16
	oldest.TextColor3 = Color3.fromRGB(150, 144, 132)
	oldest.TextTransparency = 0.55
	oldest.Text = "Odo Harrow   ·   Mira Fell   ·   A. Vane   ·   Bram Ashby   ·   Kael Rook"
	oldest.Parent = gui
	-- candles and a little light at its foot
	for _, x in { -3.6, -2.9, 3.1 } do
		local candle = part(wall, "Candle", Vector3.new(0.6, 0.3, 0.3), frame * CFrame.new(x, 1.3, -0.9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(225, 212, 180), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local flame = Instance.new("Fire")
		flame.Size = 0.7
		flame.Heat = 2
		flame.Parent = candle
	end
	local glow = part(wall, "WallGlow", Vector3.new(1, 1, 1), frame * CFrame.new(0, 2, -3), WARM, Enum.Material.SmoothPlastic)
	glow.Transparency = 1
	glow.CanCollide = false
	light(glow, WARM, 15, 1.3)
	wall.Parent = parent
	return wall
end

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

-- A rigged Tripo townsperson from TownProps, standing on `cframe` and breathing in their idle animation.
local function townsperson(name: string, parent: Instance, cframe: CFrame): Model?
	local person = prop(name, parent, cframe)
	if not person then
		return nil
	end
	local id = IDLE[name]
	local controller = person:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if animator and id and id ~= 0 then
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{id}`
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		-- not everyone breathes in step
		track:Play(0, 1, 1)
		task.defer(function()
			track.TimePosition = math.random() * math.max(track.Length - 0.1, 0)
		end)
	end
	return person
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
	-- late afternoon, golden and warm: the village looks lived in, the Well's glow still shows
	Lighting.ClockTime = 16.8
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(86, 78, 72)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 132, 118)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(214, 186, 150)
	atmosphere.Decay = Color3.fromRGB(120, 100, 90)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.TintColor = Color3.fromRGB(255, 240, 222)
	grade.Contrast = 0.1
	grade.Saturation = 0.08
	grade.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- The land the village stands on, in terrain: a grass meadow far past the houses, a round cobbled plaza
-- round the Well, paths of packed earth from the plaza to every door, the old road leaving south, and green
-- hills all round (rock showing on their crowns) so the world doesn't end at the last house.
local function path(terrain: Terrain, from: Vector3, to: Vector3, width: number, material: Enum.Material)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	terrain:FillBlock(CFrame.lookAt(Vector3.new(mid.X, -6, mid.Z), Vector3.new(to.X, -6, to.Z)), Vector3.new(width, 8, length + width * 0.6), material)
end

local function landscape(): number
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(88, 120, 56))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 124, 58))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(110, 86, 62))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(122, 114, 104))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(110, 106, 98))
	pcall(function()
		(terrain :: any).Decoration = true -- grass blades out in the fields
	end)
	-- the meadow (its top at y = 0, where everything stands)
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1024, 12, 1024), Enum.Material.Grass)
	-- inside the village a mown lawn (LeafyGrass grows no tall blades), so paths and feet show
	terrain:FillCylinder(CFrame.new(0, -6, 0), 8, 130 * SPREAD, Enum.Material.LeafyGrass)
	terrain:FillBlock(CFrame.new(0, -6, 190), Vector3.new(44, 8, 140), Enum.Material.LeafyGrass)
	-- the plaza round the Well
	terrain:FillCylinder(CFrame.new(0, -6, 0), 8, 30 * SPREAD, Enum.Material.Cobblestone)
	-- earth paths to every door, a cobbled road to the forge and out of town to the south
	local plaza = 26 * SPREAD
	path(terrain, Vector3.new(0, 0, -plaza), Vector3.new(0, 0, -52 * SPREAD), 12, Enum.Material.Cobblestone)
	path(terrain, Vector3.new(0, 0, plaza), Vector3.new(0, 0, 420), 14, Enum.Material.Cobblestone)
	for _, laid in { Vector3.new(-44, 0, -50), Vector3.new(44, 0, -50), Vector3.new(-50, 0, -20), Vector3.new(-50, 0, 20), Vector3.new(50, 0, -20), Vector3.new(50, 0, 20), Vector3.new(-44, 0, 50), Vector3.new(44, 0, 50) } do
		local door = laid * SPREAD
		local dir = Vector3.new(door.X, 0, door.Z).Unit
		path(terrain, dir * (plaza - 2), door, 9, Enum.Material.Ground)
		terrain:FillBlock(CFrame.new(door.X, -6, door.Z), Vector3.new(14, 8, 10), Enum.Material.Ground)
	end
	-- hills all round, the road leaving through a gap between them
	local rng = Random.new(7)
	for i = 0, 35 do
		local angle = math.rad(i * 10 + rng:NextNumber(-3, 3))
		local southGap = math.abs(math.deg(angle) - 90) < 9 -- +Z is south, where the road goes
		if not southGap then
			local reach = rng:NextNumber(185, 245)
			local radius = rng:NextNumber(45, 80)
			local centre = Vector3.new(math.cos(angle) * reach, rng:NextNumber(-radius * 0.75, -radius * 0.35), math.sin(angle) * reach)
			terrain:FillBall(centre, radius, Enum.Material.Grass)
			if rng:NextNumber() < 0.45 then
				terrain:FillBall(centre + Vector3.new(rng:NextNumber(-12, 12), radius * 0.55, rng:NextNumber(-12, 12)), radius * 0.4, Enum.Material.Rock)
			end
		end
	end
	-- low rolling ground nearer in, between the houses and the hills
	for i = 0, 15 do
		local angle = math.rad(i * 22.5 + 11)
		if math.abs(math.deg(angle) - 90) > 14 then
			local centre = Vector3.new(math.cos(angle) * 120 * SPREAD, -26, math.sin(angle) * 120 * SPREAD)
			terrain:FillBall(centre, 30, Enum.Material.LeafyGrass)
		end
	end
	-- where the ground really shows (the terrain snaps to its 4-stud grid): the whole village is lifted onto it
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	-- (the new terrain can take a few frames to be hit by rays; if it never is, the plaza shows at about 1.8)
	for _ = 1, 30 do
		local hit = workspace:Raycast(Vector3.new(0, 60, 20), Vector3.new(0, -120, 0), params)
		if hit then
			return hit.Position.Y
		end
		task.wait()
	end
	return 1.8
end

-- Brakka's Forge: an open-fronted smithy on the north side of the square, with the forge glowing at the back,
-- the anvil out front, a rack of weapons, and Brakka behind the anvil. Returns where she stands.
local function forge(parent: Instance, frame: CFrame): BasePart
	local m = Instance.new("Model")
	m.Name = "BrakkasForge"
	local w, d, h = 26, 16, 12
	local shell = building("ForgeBuilding", m, frame * CFrame.new(0, 0, -1), w + 2)
	if shell then
		part(m, "Floor", Vector3.new(w, 0.3, d), frame * CFrame.new(0, 0.15, d / 2), DARK_STONE, Enum.Material.Slate)
	else
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
	end

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
	local brakkaAt = frame * CFrame.new(2, 0, 7) -- (the frame's front, -Z, already looks out over the square)
	local figure = townsperson("Brakka", m, brakkaAt)
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
		base:Destroy() -- the terrain is the ground now
	end
	local groundY = landscape()
	local model = Instance.new("Model")
	model.Name = "Town"

	-- a ring of paler stones round the well, on the plaza
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
	local guardAt = CFrame.lookAt(Vector3.new(3, 0, 10.5), Vector3.new(3, 0, 30))
	local guard = townsperson("GateGuard", model, guardAt)
	if not guard then
		standIn(model, "GateGuard", guardAt, 6.4, Color3.fromRGB(110, 30, 30))
	end
	-- his spear stands planted by his right hand
	local folder = ServerStorage:FindFirstChild("TownProps")
	local spearSource = folder and folder:FindFirstChild("GuardSpear")
	if spearSource and spearSource:IsA("Model") then
		local spear = spearSource:Clone()
		for _, d in spear:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		-- (the spear's pivot is its middle; 9 studs long as stored, a little shorter here). Players' screens
		-- then put it in his right hand and keep it there as he breathes (TownFolk on the client).
		spear:ScaleTo(spear:GetScale() * 0.85)
		spear:PivotTo(guardAt * CFrame.new(1.6, 3.8, -0.4))
		spear:SetAttribute("HeldBy", "GateGuard")
		spear:SetAttribute("Bone", "mixamorig:RightHand")
		spear:SetAttribute("Grip", 0.42)
		spear:SetAttribute("Length", 9 * 0.85)
		spear.Parent = model
	end

	-- Brakka's Forge on the north side
	-- (a building's front is its frame's -Z; each frame stands on the square's edge, turned to face the middle)
	local edge = SQUARE / 2 - 1
	local brakka = forge(model, CFrame.new(0, 0, -edge + 17) * CFrame.Angles(0, math.pi, 0))

	-- the other shops and houses around the square (opening in later updates)
	local inset = edge - 16
	house(model, CFrame.new(-44, 0, -inset) * CFrame.Angles(0, math.pi, 0), 44, "Guild Hall")
	house(model, CFrame.new(44, 0, -inset) * CFrame.Angles(0, math.pi, 0), 44, "Ironhide Armory")
	house(model, CFrame.new(-inset, 0, -20) * CFrame.Angles(0, math.rad(-90), 0), 39, "The Gilded Tome")
	house(model, CFrame.new(-inset, 0, 20) * CFrame.Angles(0, math.rad(-90), 0), 35, nil)
	house(model, CFrame.new(inset, 0, -20) * CFrame.Angles(0, math.rad(90), 0), 39, "The Sunken Tankard")
	house(model, CFrame.new(inset, 0, 20) * CFrame.Angles(0, math.rad(90), 0), 35, nil)
	house(model, CFrame.new(-44, 0, inset), 39, nil)
	house(model, CFrame.new(44, 0, inset), 39, nil)

	-- the shops' wares out front, and market stalls in the square (each facing the middle)
	local function facing(at: Vector3): CFrame
		return CFrame.lookAt(at, Vector3.new(0, 0, 0))
	end
	prop("QuestBoard", model, CFrame.lookAt(Vector3.new(-44, 0, -50), Vector3.new(-44, 0, 0)))
	wallOfTheFallen(model, CFrame.lookAt(Vector3.new(-53.5, 0, -50.5), Vector3.new(-53.5, 0, 0)))
	prop("ArmorStand", model, CFrame.lookAt(Vector3.new(36, 0, -51), Vector3.new(36, 0, 0)))
	prop("ArmorStand", model, CFrame.lookAt(Vector3.new(52, 0, -51), Vector3.new(52, 0, 0)))
	prop("PotionShelf", model, CFrame.lookAt(Vector3.new(-51, 0, -26), Vector3.new(0, 0, -26)))
	prop("MarketStall", model, facing(Vector3.new(-20, 0, 40)))
	prop("MarketStall", model, facing(Vector3.new(20, 0, 40)))

	-- the other townsfolk at their doors, facing the square (their shops open in later updates)
	townsperson("Aldric", model, CFrame.lookAt(Vector3.new(-36, 0, -51), Vector3.new(-36, 0, 0)))
	townsperson("Thorne", model, CFrame.lookAt(Vector3.new(44, 0, -51), Vector3.new(44, 0, 0)))
	townsperson("Seraphine", model, CFrame.lookAt(Vector3.new(-52, 0, -16), Vector3.new(0, 0, -16)))
	townsperson("OldPip", model, CFrame.lookAt(Vector3.new(52, 0, -20), Vector3.new(0, 0, -20)))

	-- the green round the village: oaks behind the houses and along the road out, fences along the road,
	-- flower boxes under the shop windows
	local function scaled(name: string, cframe: CFrame, scale: number, sink: number?)
		local p = prop(name, model, cframe)
		if p then
			p:ScaleTo(p:GetScale() * scale)
			local box, size = p:GetBoundingBox()
			p:PivotTo(p:GetPivot() + (cframe.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))) - Vector3.new(0, sink or 0, 0))
		end
	end
	local rng = Random.new(31)
	for i = 0, 17 do
		local angle = math.rad(i * 20 + rng:NextNumber(-6, 6))
		if math.abs(math.deg(angle) - 90) > 14 then -- not on the road south
			local reach = rng:NextNumber(92, 112)
			scaled("OakTree", CFrame.new(math.cos(angle) * reach, 0, math.sin(angle) * reach) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.85, 1.25), 1.6)
		end
	end
	for _, side in { -1, 1 } do
		for z = 80, 200, 40 do
			scaled("OakTree", CFrame.new(side * rng:NextNumber(22, 30), 0, z + rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.8, 1.1), 1.6)
		end
	end
	for _, at in { CFrame.lookAt(Vector3.new(-40, 0, -50.5), Vector3.new(-40, 0, 0)), CFrame.lookAt(Vector3.new(48, 0, -50.5), Vector3.new(48, 0, 0)),
		CFrame.lookAt(Vector3.new(-51, 0, -12), Vector3.new(0, 0, -12)), CFrame.lookAt(Vector3.new(51, 0, -26), Vector3.new(0, 0, -26)),
		CFrame.lookAt(Vector3.new(51, 0, -14), Vector3.new(0, 0, -14)), CFrame.lookAt(Vector3.new(-51, 0, 26), Vector3.new(0, 0, 26)),
		CFrame.lookAt(Vector3.new(51, 0, 26), Vector3.new(0, 0, 26)), CFrame.lookAt(Vector3.new(-38, 0, 50.5), Vector3.new(-38, 0, 0)),
		CFrame.lookAt(Vector3.new(38, 0, 50.5), Vector3.new(38, 0, 0)) } do
		scaled("FlowerBox", at, 1.3)
	end

	-- the town wall: stone sections in a ring, a tower every few sections, and the gatehouse where the road
	-- leaves to the south. The oaks stand inside it.
	local WALL_RADIUS, SECTIONS = 126, 46 -- (enough sections to close the ring once it is spread out)
	for i = 0, SECTIONS - 1 do
		local angle = (i + 0.5) / SECTIONS * math.pi * 2
		local deg = math.deg(angle)
		local at = Vector3.new(math.cos(angle) * WALL_RADIUS, 0, math.sin(angle) * WALL_RADIUS)
		if math.abs(deg - 90) > 4 then -- only the section right behind the gatehouse is left out
			scaled("TownWall", CFrame.lookAt(at, Vector3.new(0, 0, 0)), 0.95, 0.3)
		end
		if i % 4 == 0 and math.abs(deg - 90) > 18 then
			local corner = (i / SECTIONS) * math.pi * 2
			scaled("WallTower", CFrame.new(math.cos(corner) * WALL_RADIUS, 0, math.sin(corner) * WALL_RADIUS), 1.75, 0.3)
		end
	end
	scaled("Gatehouse", CFrame.new(0, 0, WALL_RADIUS), 1.9, 0.3) -- (its arch runs along its X, like the wall)

	-- life round the plaza and the doors: benches by the Well, barrels and crates by the shops, hay carts,
	-- two more market stalls
	for _, deg in { 20, 160, 200, 340 } do
		local a = math.rad(deg)
		scaled("Bench", CFrame.lookAt(Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24), Vector3.new(0, 0, 0)), 1.4)
	end
	for _, at in { Vector3.new(-30, 0, -56), Vector3.new(56, 0, -30), Vector3.new(-56, 0, 32), Vector3.new(14, 0, -52) } do
		scaled("Barrels", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1.6)
	end
	scaled("HayCart", CFrame.new(-26, 0, 60) * CFrame.Angles(0, math.rad(20), 0), 1.4)
	scaled("HayCart", CFrame.new(62, 0, 4) * CFrame.Angles(0, math.rad(-70), 0), 1.4)
	prop("MarketStall", model, facing(Vector3.new(-40, 0, 36)))
	prop("MarketStall", model, facing(Vector3.new(40, 0, 36)))

	-- lamp posts round the square
	for _, at in { Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30), Vector3.new(0, 0, 40), Vector3.new(-50, 0, 0), Vector3.new(50, 0, 0), Vector3.new(30, 0, -48) } do
		lampPost(model, at)
	end

	-- spread the village out: every piece keeps its size and turn, its place from the Well grows
	for _, piece in model:GetChildren() do
		if piece:IsA("Model") or piece:IsA("BasePart") then
			local pos = piece:GetPivot().Position
			piece:PivotTo(piece:GetPivot() + Vector3.new(pos.X, 0, pos.Z) * (SPREAD - 1))
		end
	end
	-- the gate is shut (heavy oak doors in the arch), and an unseen wall round the ring keeps everyone in,
	-- however they jump
	local wallRadius = WALL_RADIUS * SPREAD
	local gateDoor = part(model, "GateDoors", Vector3.new(16, 22, 1.4), CFrame.new(0, 11, wallRadius - 1.5), Color3.fromRGB(70, 46, 28), Enum.Material.WoodPlanks)
	for _, y in { 5, 15 } do
		part(model, "GateBand", Vector3.new(16.2, 1, 1.6), CFrame.new(0, y, wallRadius - 1.6), Color3.fromRGB(40, 38, 38), Enum.Material.Metal)
	end
	local _ = gateDoor
	local barrier = Instance.new("Model")
	barrier.Name = "TownBarrier"
	local count = 64
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		local at = Vector3.new(math.cos(angle) * (wallRadius + 3), 50, math.sin(angle) * (wallRadius + 3))
		local b = part(barrier, "Barrier", Vector3.new(2 * math.pi * (wallRadius + 3) / count + 2, 120, 2), CFrame.lookAt(at, Vector3.new(0, 50, 0)), Color3.new(), Enum.Material.SmoothPlastic)
		b.Transparency = 1
		b.CanQuery = false
		b.CastShadow = false
	end
	barrier.Parent = model

	-- everything was laid out at y = 0; lift it onto the ground as the terrain shows it
	model:PivotTo(model:GetPivot() + Vector3.new(0, groundY, 0))
	model.Parent = workspace

	-- players arrive at the south end of the square, looking at the well
	local spawn = CFrame.lookAt(Vector3.new(0, 3 + groundY, 52 * SPREAD), Vector3.new(0, 3 + groundY, 0))
	local spawnPart = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnPart then
		spawnPart.CFrame = CFrame.new(0, 0.5 + groundY, 52 * SPREAD)
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
