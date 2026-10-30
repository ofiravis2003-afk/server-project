--!strict
-- Builds Emberhold when the server starts: a walled village on a grass meadow, late in the afternoon, with the Great
-- Well (the way down, The Descent) in the middle and the gate guard beside it, and a quarter on each side of the
-- plaza: the Guild Hall to the north, the Market Square with every shop to the east, the Training Yard to the
-- west, homes to the south along the road in from the gate.
-- Tripo models come from ServerStorage.TownProps (GreatWell, Anvil, Forge, WeaponRack, Brakka, GateGuard,
-- GuardSpear); anything missing is built from plain parts.
-- Returns the spots other services hang their prompts on.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fonts = require(ReplicatedStorage.Shared.Fonts)

local TownBuilder = {}

export type Town = {
	Model: Model,
	Spawn: CFrame,
	Well: BasePart, -- the well's rim (for the Descend prompt)
	Brakka: BasePart, -- where Brakka stands (for the Trade prompt)
	Training: CFrame, -- the Training Yard's middle on the ground, looking out to the plaza (TrainingService)
}

local STONE = Color3.fromRGB(78, 74, 70)
local DARK_STONE = Color3.fromRGB(52, 50, 48)
local TIMBER = Color3.fromRGB(58, 40, 28)
local PLASTER = Color3.fromRGB(150, 132, 108)
local ROOF = Color3.fromRGB(64, 44, 38)
local WARM = Color3.fromRGB(255, 176, 96)

local SQUARE = 150 -- the square's width (as laid out; everything is then spread out by SPREAD)
local SPREAD = 1.25 -- how far apart the village is drawn: every piece's place from the Well times this
local MARKET_AT = Vector3.new(66, 0, 0) -- the Market Square's middle (as laid out)
-- The news board by the plaza: the latest updates, newest first (one line each). A line with `Until` (a UTC
-- time) comes down by itself once that day comes.
local NEWS: { { Text: string, Until: number? } } = {
	{ Text = "- Emberhold flies its colours: banners, flags and torches on the walls" },
	{ Text = "- Special moves: every weapon learns one at level 3 (press Q)" },
	{ Text = "- Titles: earn them, wear them (click your panel, top left)" },
	{ Text = "- The Training Yard: test your weapons on the dummies" },
	{ Text = "- Halloween: find the lost Jack-o'-Lanterns (until Nov 2)", Until = DateTime.fromUniversalTime(2026, 11, 2).UnixTimestamp },
}
local YARD_AT = Vector3.new(-68, 0, 0) -- the Training Yard's middle (as laid out)

-- The townsfolk's standing animations (published from ServerStorage.TownClips).
local IDLE: { [string]: number } = {
	Brakka = 92067081387599, -- Mixamo "Standing W/ Briefcase Idle"
	GateGuard = 77116071943805, -- Mixamo "Standing Idle"
	Aldric = 110153111695731, -- Mixamo "Unarmed Idle"
	Thorne = 106330872617044, -- Mixamo "Breathing Idle" (the "Dwarf Idle" leaned him to one side)
	Seraphine = 89523763247665, -- Mixamo "Happy Idle"
	OldPip = 106330872617044, -- Mixamo "Breathing Idle"
	MiraFell = 117963004734144, -- Mixamo "Sword And Shield Idle"
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

-- A name board floating over a shop, seen from across the town: its name and what it sells.
local SHOP_SIGNS: { [string]: { string } } = {
	["Guild Hall"] = { "Guild Hall", "Quests and the Guild" },
	["Ironhide Armory"] = { "Ironhide Armory", "Armor" },
	["The Gilded Tome"] = { "The Gilded Tome", "Potions and brews" },
	["The Sunken Hearth"] = { "The Sunken Hearth", "Tavern and quests" },
	["Brakka's Forge"] = { "Brakka's Forge", "Weapons and upgrades" },
}
local function shopSign(building: Model, name: string)
	local words = SHOP_SIGNS[name]
	if not words then
		return
	end
	local box, size = building:GetBoundingBox()
	local anchor = part(building, "ShopSign", Vector3.new(0.5, 0.5, 0.5), CFrame.new(box.Position + Vector3.new(0, size.Y / 2 + 3, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(16, 4.2) -- (in studs: it shrinks with distance)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(34, 24, 18)
	back.BackgroundTransparency = 0.2
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(196, 150, 84)
	stroke.Thickness = 2
	stroke.Parent = back
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.92, 0.58)
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Fondamento
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 140)
	title.Text = words[1]
	title.Parent = back
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(0.92, 0.32)
	sub.Position = UDim2.fromScale(0.04, 0.62)
	sub.BackgroundTransparency = 1
	sub.FontFace = Fonts.Text
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(226, 208, 180)
	sub.Text = words[2]
	sub.Parent = back
	gui.Parent = anchor
end

-- A painted board (for the signpost and the news board): text on both faces.
local function board(parent: Instance, name: string, size: Vector3, cframe: CFrame, text: string, pixels: number, xAlign: Enum.TextXAlignment?): Part
	local p = part(parent, name, size, cframe, TIMBER, Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixels
		gui.LightInfluence = 1
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.86)
		label.Position = UDim2.fromScale(0.04, 0.07)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fondamento
		label.TextScaled = true
		label.TextWrapped = true
		label.TextXAlignment = xAlign or Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextColor3 = Color3.fromRGB(240, 212, 150)
		label.Text = text
		label.Parent = gui
		gui.Parent = p
	end
	return p
end

-- The signpost at the plaza where newcomers come in: a post with an arrow board pointing to each quarter.
local function signpost(parent: Instance, at: Vector3, places: { { Name: string, Toward: Vector3 } })
	local m = Instance.new("Model")
	m.Name = "Signpost"
	part(m, "Post", Vector3.new(0.7, 9, 0.7), CFrame.new(at + Vector3.new(0, 4.5, 0)), Color3.fromRGB(70, 48, 32), Enum.Material.Wood)
	part(m, "PostCap", Vector3.new(1.1, 0.5, 1.1), CFrame.new(at + Vector3.new(0, 9.2, 0)), Color3.fromRGB(40, 38, 36), Enum.Material.Metal)
	for i, place in places do
		local dir = Vector3.new(place.Toward.X - at.X, 0, place.Toward.Z - at.Z).Unit
		local y = 8.2 - (i - 1) * 1.35
		-- the board sticks out from the post toward the place
		local center = at + dir * 2.4 + Vector3.new(0, y, 0)
		local frame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0)
		board(m, "Arrow", Vector3.new(4.2, 1.1, 0.2), frame, place.Name, 60)
	end
	m.Parent = parent
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

local HOUSE_MODELS = { ["Guild Hall"] = "GuildHall", ["Ironhide Armory"] = "Armory", ["The Gilded Tome"] = "MagicShop", ["The Sunken Hearth"] = "Tavern" }
local plainHouse = 0

local function house(parent: Instance, frame: CFrame, width: number, name: string?)
	-- the real building when there is one (plain houses take turns between the two house models)
	local modelName = if name then HOUSE_MODELS[name] else nil
	if not modelName then
		plainHouse += 1
		modelName = if plainHouse % 2 == 1 then "HouseA" else "HouseB"
	end
	local made = building(modelName :: string, parent, frame)
	if made then
		-- (the plain house models are small next to the shops: a home is a size up; the Guild Hall, the heart
		-- of the town, bigger still)
		local scale = if not name then 1.4 elseif name == "Guild Hall" then 1.3 else 1
		if scale ~= 1 then
			made:ScaleTo(made:GetScale() * scale)
			made:PivotTo(frame)
			local box, size = made:GetBoundingBox()
			made:PivotTo(made:GetPivot() + (frame.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
			made:PivotTo(made:GetPivot() * CFrame.new(0, 0, size.Z / 2 - 0.5))
		end
		if name then
			shopSign(made, name)
		end
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
-- The Wall of the Fallen on the lawn before the Guild Hall: a slab of dark stone carved with the names of adventurers
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
		if c == 0 then
			names[2] = "Mira Fell" -- lost with the Ninth Patrol, six years ago
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
	oldest.Text = "Odo Harrow   ·   Edda Holt   ·   A. Vane   ·   Bram Ashby   ·   Kael Rook"
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
		track:Play(0, 1, if name == "Thorne" then 0.75 else 1) -- (Thorne takes his time)
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
	-- (a block's surface shows 2 studs higher than a cylinder's of the same height: at -4 it's level with the lawn)
	terrain:FillBlock(CFrame.lookAt(Vector3.new(mid.X, -4, mid.Z), Vector3.new(to.X, -4, to.Z)), Vector3.new(width, 8, length + width * 0.6), material)
end

local function landscape(): number
	local terrain = workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(88, 120, 56))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(92, 124, 58))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(110, 86, 62))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(122, 114, 104))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(110, 106, 98))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(176, 150, 112)) -- the Training Yard's packed sand
	pcall(function()
		(terrain :: any).Decoration = true -- grass blades out in the fields
	end)
	-- the meadow (its top at y = 0, where everything stands)
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1024, 12, 1024), Enum.Material.Grass)
	-- inside the village a mown lawn (LeafyGrass grows no tall blades), so paths and feet show
	terrain:FillCylinder(CFrame.new(0, -6, 0), 8, 130 * SPREAD, Enum.Material.LeafyGrass)
	terrain:FillBlock(CFrame.new(0, -6, 190), Vector3.new(44, 8, 140), Enum.Material.LeafyGrass)
	-- the plaza round the Well, and a road from it to each quarter (laid out like the village, then spread)
	terrain:FillCylinder(CFrame.new(0, -6, 0), 8, 30 * SPREAD, Enum.Material.Cobblestone)
	local function road(from: Vector3, to: Vector3, width: number, material: Enum.Material)
		path(terrain, from * SPREAD, to * SPREAD, width, material)
	end
	road(Vector3.new(0, 0, -26), Vector3.new(0, 0, -72), 12, Enum.Material.Cobblestone) -- north, to the Guild
	road(Vector3.new(26, 0, 0), Vector3.new(44, 0, 0), 12, Enum.Material.Cobblestone) -- east, to the Market Square
	terrain:FillCylinder(CFrame.new(MARKET_AT * SPREAD + Vector3.new(0, -6, 0)), 8, 30 * SPREAD, Enum.Material.Cobblestone)
	road(Vector3.new(-26, 0, 0), Vector3.new(-50, 0, 0), 10, Enum.Material.Ground) -- west, to the Training Yard
	terrain:FillBlock(CFrame.new(YARD_AT * SPREAD + Vector3.new(0, -4, 0)), Vector3.new(36 * SPREAD, 8, 36 * SPREAD), Enum.Material.Sand)
	path(terrain, Vector3.new(0, 0, 26 * SPREAD), Vector3.new(0, 0, 420), 14, Enum.Material.Cobblestone) -- south, out of the gate
	-- earth paths from the south road to the homes' doors
	for _, door in { Vector3.new(-30, 0, 62), Vector3.new(30, 0, 62), Vector3.new(-60, 0, 42), Vector3.new(55, 0, 68) } do
		road(Vector3.new(0, 0, door.Z - 8), door, 8, Enum.Material.Ground)
	end
	-- hills all round, the road leaving through a gap between them
	local rng = Random.new(7)
	for i = 0, 35 do
		local angle = math.rad(i * 10 + rng:NextNumber(-3, 3))
		local southGap = math.abs(math.deg(angle) - 90) < 9 -- +Z is south, where the road goes
		if not southGap then
			local radius = rng:NextNumber(45, 80)
			-- (every hill's foot stays well out past the town wall and low, so none looms over it into the town)
			local reach = math.max(rng:NextNumber(250, 310), radius + 250)
			local centre = Vector3.new(math.cos(angle) * reach, rng:NextNumber(-radius * 0.85, -radius * 0.6), math.sin(angle) * reach)
			terrain:FillBall(centre, radius, Enum.Material.Grass)
			if rng:NextNumber() < 0.45 then
				terrain:FillBall(centre + Vector3.new(rng:NextNumber(-12, 12), radius * 0.55, rng:NextNumber(-12, 12)), radius * 0.4, Enum.Material.Rock)
			end
		end
	end
	-- low rolling ground between the town wall and the hills
	for i = 0, 15 do
		local angle = math.rad(i * 22.5 + 11)
		if math.abs(math.deg(angle) - 90) > 14 then
			local centre = Vector3.new(math.cos(angle) * 210, -26, math.sin(angle) * 210)
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

-- Brakka's Forge: an open-fronted smithy on the north side of the Market Square, with the forge glowing at the back,
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
	shopSign(m, "Brakka's Forge")
	m.Parent = parent
	return spot
end

TownBuilder.Spread = SPREAD

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

	-- The town in quarters round the Well, each reached by its own road from the plaza (laid out here, then
	-- spread out by SPREAD): the Guild to the north, the Market Square to the east (every shop round it), the
	-- Training Yard to the west, and homes to the south either side of the road in from the gate.
	local function facingFrom(at: Vector3, toward: Vector3): CFrame
		-- a building's frame: its front (-Z) looks toward `toward`
		return CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
	end
	local function infront(frame: CFrame, out: number, side: number?): CFrame
		-- a spot `out` studs in front of a frame's front line, looking the way the frame looks
		local spot = (frame * CFrame.new(side or 0, 0, -out)).Position
		return CFrame.lookAt(spot, spot + frame.LookVector)
	end

	-- North: the Guild quarter. The Guild Hall faces the plaza up its road; Aldric at its door, the quest board
	-- beside him, and the Wall of the Fallen (with the Deepest Descents board) on the lawn to the west.
	local guildFrame = facingFrom(Vector3.new(0, 0, -72), Vector3.new(0, 0, 0))
	house(model, guildFrame, 50, "Guild Hall")
	townsperson("Aldric", model, infront(guildFrame, 5, 4))
	prop("QuestBoard", model, infront(guildFrame, 6, -10))
	wallOfTheFallen(model, facingFrom(Vector3.new(-30, 0, -44), Vector3.new(-30, 0, 0)))

	-- East: the Market Square, a cobbled square of its own with every shop round it and stalls in the middle.
	local MARKET = MARKET_AT
	local brakka = forge(model, facingFrom(MARKET + Vector3.new(0, 0, -30), MARKET))
	local armoryFrame = facingFrom(MARKET + Vector3.new(0, 0, 30), MARKET)
	house(model, armoryFrame, 50, "Ironhide Armory")
	townsperson("Thorne", model, infront(armoryFrame, 5))
	prop("ArmorStand", model, infront(armoryFrame, 3, -9))
	prop("ArmorStand", model, infront(armoryFrame, 3, 9))
	local tomeFrame = facingFrom(MARKET + Vector3.new(26, 0, -8), MARKET + Vector3.new(0, 0, -8))
	house(model, tomeFrame, 45, "The Gilded Tome")
	townsperson("Seraphine", model, infront(tomeFrame, 5))
	prop("PotionShelf", model, infront(tomeFrame, 2.5, 8))
	local tavernFrame = facingFrom(MARKET + Vector3.new(26, 0, 18), MARKET + Vector3.new(0, 0, 18))
	house(model, tavernFrame, 45, "The Sunken Hearth")
	townsperson("OldPip", model, infront(tavernFrame, 5))
	if Config.ChapterII then
		-- (seen only by those who brought her home: client/hub/MiraInTown)
		townsperson("MiraFell", model, facingFrom(Vector3.new(26, 0, -30), Vector3.new(0, 0, 0)))
	end
	prop("MarketStall", model, facingFrom(MARKET + Vector3.new(-8, 0, -9), MARKET + Vector3.new(-30, 0, -9)))
	prop("MarketStall", model, facingFrom(MARKET + Vector3.new(-8, 0, 10), MARKET + Vector3.new(-30, 0, 10)))

	-- West: the Training Yard, a fenced square of packed sand with the dummies (TrainingService), an archery
	-- target, weapon racks along the back and benches for whoever is watching.
	local YARD = YARD_AT
	local YARD_SIZE = 36
	local yardMark = part(model, "TrainingYard", Vector3.new(1, 1, 1), CFrame.lookAt(YARD, YARD + Vector3.new(1, 0, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	yardMark.Transparency = 1
	yardMark.CanCollide = false
	yardMark.CanQuery = false
	local half = YARD_SIZE / 2
	local function fence(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local folder = ServerStorage:FindFirstChild("TownProps")
		local section = folder and folder:FindFirstChild("FenceSection")
		-- (sections of about 3.4 studs: the fence model is short, and scaling it to a longer gap would make it tall)
		local count = math.max(1, math.floor(length / 3.4 + 0.5))
		for i = 0, count - 1 do
			local a = from + (to - from) * (i / count)
			local b = from + (to - from) * ((i + 1) / count)
			local mid = (a + b) / 2
			if section and section:IsA("Model") then
				-- (the fence model runs along its X)
				local piece = prop("FenceSection", model, CFrame.lookAt(mid, mid + (b - a).Unit) * CFrame.Angles(0, math.rad(90), 0))
				if piece then
					local _, size = piece:GetBoundingBox()
					piece:ScaleTo(piece:GetScale() * ((b - a).Magnitude + 0.4) / size.X)
					local box, scaled = piece:GetBoundingBox()
					piece:PivotTo(piece:GetPivot() + (mid - (box.Position - Vector3.new(0, scaled.Y / 2, 0))))
				end
			else
				local frame = CFrame.lookAt(mid, mid + (b - a).Unit)
				part(model, "FencePost", Vector3.new(0.6, 3.6, 0.6), CFrame.new(a + Vector3.new(0, 1.8, 0)), TIMBER, Enum.Material.Wood)
				for _, y in { 1.2, 2.6 } do
					part(model, "FenceRail", Vector3.new(0.35, 0.35, (b - a).Magnitude), frame * CFrame.new(0, y, 0), TIMBER, Enum.Material.Wood)
				end
			end
		end
	end
	-- (the side facing the plaza is left open in the middle: the way in)
	local c = YARD
	fence(c + Vector3.new(-half, 0, -half), c + Vector3.new(half, 0, -half))
	fence(c + Vector3.new(-half, 0, half), c + Vector3.new(half, 0, half))
	fence(c + Vector3.new(-half, 0, -half), c + Vector3.new(-half, 0, half))
	fence(c + Vector3.new(half, 0, -half), c + Vector3.new(half, 0, -5))
	fence(c + Vector3.new(half, 0, 5), c + Vector3.new(half, 0, half))
	prop("WeaponRack", model, facingFrom(c + Vector3.new(-half + 2.5, 0, -8), c + Vector3.new(0, 0, -8)))
	prop("WeaponRack", model, facingFrom(c + Vector3.new(-half + 2.5, 0, 8), c + Vector3.new(0, 0, 8)))
	prop("ArcheryTarget", model, facingFrom(c + Vector3.new(-6, 0, -half + 3), c + Vector3.new(-6, 0, 0)))
	prop("ArcheryTarget", model, facingFrom(c + Vector3.new(6, 0, -half + 3), c + Vector3.new(6, 0, 0)))
	for _, x in { -8, 8 } do
		prop("Bench", model, facingFrom(c + Vector3.new(x, 0, half - 2.5), c + Vector3.new(x, 0, 0)))
	end
	prop("Barrels", model, CFrame.new(c + Vector3.new(-half + 3, 0, half - 3)))

	-- South: homes either side of the road in from the gate, each facing the plaza
	for _, at in { Vector3.new(-30, 0, 66), Vector3.new(30, 0, 66), Vector3.new(-64, 0, 46), Vector3.new(58, 0, 72) } do
		house(model, facingFrom(at, Vector3.new(0, 0, 0)), 42, nil)
	end
	prop("MarketStall", model, facingFrom(Vector3.new(-18, 0, 44), Vector3.new(0, 0, 44)))
	prop("MarketStall", model, facingFrom(Vector3.new(18, 0, 44), Vector3.new(0, 0, 44)))

	-- the green round the village: oaks inside the wall (not over the Market Square or the road south), flower
	-- boxes by the doors
	local function scaled(name: string, cframe: CFrame, scale: number, sink: number?)
		local p = prop(name, model, cframe)
		if p then
			p:ScaleTo(p:GetScale() * scale)
			local box, size = p:GetBoundingBox()
			p:PivotTo(p:GetPivot() + (cframe.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))) - Vector3.new(0, sink or 0, 0))
		end
	end
	-- (an oak only where its crown clears every building already standing)
	local function clearOfBuildings(at: Vector3, crown: number): boolean
		for _, piece in model:GetChildren() do
			if piece:IsA("Model") and piece.Name ~= "OakTree" then
				local box, size = piece:GetBoundingBox()
				local reach = math.max(size.X, size.Z) / 2
				if reach > 4 and Vector3.new(box.X - at.X, 0, box.Z - at.Z).Magnitude < crown + reach then
					return false
				end
			end
		end
		return true
	end
	local rng = Random.new(31)
	for i = 0, 17 do
		local deg = i * 20 + rng:NextNumber(-6, 6)
		local angle = math.rad(deg)
		local clearOfRoad = math.abs(deg - 90) > 14
		local clearOfMarket = deg > 40 and deg < 320
		local reach = rng:NextNumber(96, 112)
		local at = Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
		if clearOfRoad and clearOfMarket and clearOfBuildings(at, 16) then
			scaled("OakTree", CFrame.new(math.cos(angle) * reach, 0, math.sin(angle) * reach) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.85, 1.25), 1.6)
		end
	end
	for _, side in { -1, 1 } do
		for z = 150, 230, 40 do -- (out along the road past the gate)
			local at = Vector3.new(side * rng:NextNumber(22, 30), 0, z + rng:NextNumber(-8, 8))
			local turn = rng:NextNumber(0, math.pi * 2)
			local scale = rng:NextNumber(0.8, 1.1)
			if clearOfBuildings(at, 14) then
				scaled("OakTree", CFrame.new(at) * CFrame.Angles(0, turn, 0), scale, 1.6)
			end
		end
	end
	for _, frame in { guildFrame, armoryFrame, tomeFrame, tavernFrame } do
		for _, side in { -1, 1 } do
			scaled("FlowerBox", infront(frame, 1.5, side * 13), 1.2)
		end
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
	scaled("Gatehouse", CFrame.new(0, 0, WALL_RADIUS), 1.9, 0.3) -- (its towers run along its X like the wall, banners facing the town)

	-- life round the doors: two seating corners on the lawns either side of the south road, barrels and a hay
	-- cart by the homes
	for _, corner in { Vector3.new(-34, 0, 34), Vector3.new(34, 0, 34) } do
		local out = Vector3.new(corner.X, 0, corner.Z).Unit
		local along = Vector3.new(-out.Z, 0, out.X)
		for _, side in { -1, 1 } do
			local seat = corner + along * side * 3.2
			scaled("Bench", CFrame.lookAt(seat, corner), 1.4)
		end
		scaled("FlowerBox", CFrame.lookAt(corner + out * 4.5, corner), 1.2)
		scaled("Barrels", CFrame.new(corner - out * 4.5) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1.3)
	end
	for _, at in { MARKET + Vector3.new(-14, 0, -22), MARKET + Vector3.new(14, 0, 26), Vector3.new(-46, 0, 60), Vector3.new(14, 0, -54) } do
		scaled("Barrels", CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1.6)
	end
	scaled("HayCart", CFrame.new(-50, 0, 78) * CFrame.Angles(0, math.rad(20), 0), 1.4)
	scaled("HayCart", CFrame.new(MARKET.X - 16, 0, -20) * CFrame.Angles(0, math.rad(-70), 0), 1.4)

	-- where newcomers walk in from the gate: a signpost to every quarter, and the news board
	signpost(model, Vector3.new(9, 0, 30), {
		{ Name = "Guild Hall", Toward = Vector3.new(0, 0, -72) },
		{ Name = "Market Square", Toward = MARKET },
		{ Name = "Training Yard", Toward = YARD },
		{ Name = "Town Gate", Toward = Vector3.new(0, 0, 126) },
	})
	local newsAt = CFrame.lookAt(Vector3.new(-13, 0, 32), Vector3.new(-13, 0, 60))
	local newsModel = Instance.new("Model")
	newsModel.Name = "NewsBoard"
	local panel = part(newsModel, "Board", Vector3.new(11, 7, 0.3), newsAt * CFrame.new(0, 5, 0), TIMBER, Enum.Material.WoodPlanks)
	local newsGui = Instance.new("SurfaceGui")
	newsGui.Face = Enum.NormalId.Front
	newsGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	newsGui.PixelsPerStud = 70
	newsGui.LightInfluence = 1
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.fromScale(0.9, 0.2)
	heading.Position = UDim2.fromScale(0.05, 0.04)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.Fondamento
	heading.TextScaled = true
	heading.TextColor3 = Color3.fromRGB(255, 214, 140)
	heading.Text = "What's new in Emberwell"
	heading.Parent = newsGui
	local list = Instance.new("Frame")
	list.Size = UDim2.fromScale(0.9, 0.7)
	list.Position = UDim2.fromScale(0.05, 0.27)
	list.BackgroundTransparency = 1
	list.Parent = newsGui
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0.03, 0)
	listLayout.Parent = list
	local lines = {}
	for _, line in NEWS do
		if not line.Until or os.time() < line.Until then
			table.insert(lines, line.Text)
		end
	end
	for _, line in lines do
		local item = Instance.new("TextLabel")
		item.Size = UDim2.fromScale(1, 1 / #lines - 0.03)
		item.BackgroundTransparency = 1
		item.Font = Enum.Font.Fondamento
		item.TextScaled = true
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextColor3 = Color3.fromRGB(236, 214, 170)
		item.Text = line
		item.Parent = list
	end
	newsGui.Parent = panel
	for _, side in { -1, 1 } do
		part(newsModel, "Leg", Vector3.new(0.6, 9, 0.6), newsAt * CFrame.new(side * 5.1, 4.5, 0.3), Color3.fromRGB(70, 48, 32), Enum.Material.Wood)
	end
	part(newsModel, "Roof", Vector3.new(12.2, 0.4, 1.6), newsAt * CFrame.new(0, 8.8, 0.2), Color3.fromRGB(64, 44, 38), Enum.Material.Slate)
	newsModel.Parent = model

	-- lamp posts round the plaza and along each road
	for _, at in { Vector3.new(-24, 0, -24), Vector3.new(24, 0, -24), Vector3.new(-24, 0, 24), Vector3.new(24, 0, 24),
		Vector3.new(-9, 0, -46), Vector3.new(9, 0, -46), Vector3.new(40, 0, -9), Vector3.new(40, 0, 9),
		Vector3.new(-42, 0, -9), Vector3.new(-42, 0, 9), Vector3.new(-10, 0, 46), Vector3.new(10, 0, 46),
		MARKET + Vector3.new(-12, 0, -20), MARKET + Vector3.new(-12, 0, 20) } do
		lampPost(model, at)
	end

	-- spread the village out: every piece keeps its size and turn, its place from the Well grows
	for _, piece in model:GetChildren() do
		if piece:IsA("Model") or piece:IsA("BasePart") then
			local pos = piece:GetPivot().Position
			piece:PivotTo(piece:GetPivot() + Vector3.new(pos.X, 0, pos.Z) * (SPREAD - 1))
		end
	end
	-- the arch is shut by tall oak doors with iron bands, and an unseen wall round the ring keeps everyone in,
	-- however they jump
	local wallRadius = WALL_RADIUS * SPREAD
	part(model, "GateDoors", Vector3.new(12.5, 21, 1.2), CFrame.new(0, 10.5, wallRadius), Color3.fromRGB(72, 46, 28), Enum.Material.WoodPlanks)
	for _, y in { 4, 11, 18 } do
		part(model, "GateBand", Vector3.new(12.7, 0.8, 1.4), CFrame.new(0, y, wallRadius), Color3.fromRGB(42, 40, 40), Enum.Material.Metal)
	end
	part(model, "GateSeam", Vector3.new(0.3, 21, 1.4), CFrame.new(0, 10.5, wallRadius), Color3.fromRGB(30, 22, 16), Enum.Material.Wood)
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
	local yard = model:FindFirstChild("TrainingYard") :: BasePart
	return { Model = model, Spawn = spawn, Well = rim, Brakka = brakka, Training = yard.CFrame }
end

return TownBuilder
