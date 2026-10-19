--!strict
-- Dresses a room in one of the Drowned Catacombs themes, so no two rooms in a row look alike.
--   Crypt:     sarcophagi with candles on the lids
--   Flooded:   dark water over the whole floor, stepping stones, a cold light
--   Ossuary:   walls lined with shelves of skulls, a faint green glow
--   Collapsed: broken pillars, rubble, a fallen slab, and a beam of light through a cracked ceiling
--   Chapel:    an altar with candles, red banners, old pews
--   Prison:    barred cells along a wall, chains and remains inside
--   Vault:     heaps of gold coins and banners (treasure rooms)
--   Graveyard: the Gravekeeper's lair. Its tomb (Mausoleum) stands against the back wall between two weeping
--              angels, with skulls heaped at their feet; the Gravekeeper waits at the tomb's door. Rows of leaning
--              headstones and dead trees along the other walls, open graves fenced with iron, coffins, chains
--              and hanging cages, a ring of runes on the floor (they light up when the fight starts), a beam of
--              moonlight over the middle, and a low grave mist over everything. The middle stays clear.
-- Big pieces only go along walls without a doorway, so paths and the middle of the room stay clear.
-- Tripo-made props (Coffin, Barrel, Banner, Candles, and for the lair Mausoleum, AngelStatue, DeadTree, IronFence,
-- SkullPile in ServerStorage.DungeonProps) are used when present.

export type Context = {
	Model: Model,
	Center: Vector3,
	Size: number,
	Height: number,
	PlainWalls: { CFrame }, -- frames at the center, looking out through each wall without a doorway
	Doorways: { Vector3 }?, -- the first one is the way in
	Rng: Random,
}

local Props = require(script.Parent.Props)

local RoomDecor = {}

RoomDecor.CombatThemes = { "Crypt", "Flooded", "Ossuary", "Collapsed", "Chapel", "Prison" }

local BONE = Color3.fromRGB(140, 132, 112)
local STONE = Color3.fromRGB(72, 76, 73)
local IRON = Color3.fromRGB(42, 40, 40)
local WOOD = Color3.fromRGB(70, 48, 32)
local CLOTH = Color3.fromRGB(96, 22, 24)
local GOLD = Color3.fromRGB(214, 170, 64)
local WAX = Color3.fromRGB(220, 208, 180)

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

local function deco(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = part(parent, name, size, cframe, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

-- A spot against wall `frame`: `along` across the wall, `out` studs into the room from it.
local function onWall(ctx: Context, frame: CFrame, along: number, out: number): CFrame
	-- Turned so the piece's front (-Z) faces into the room.
	return frame * CFrame.new(along, 0, -(ctx.Size / 2 - out)) * CFrame.Angles(0, math.pi, 0)
end

local function tint(ctx: Context, wall: Color3?, floor: Color3?, floorMaterial: Enum.Material?)
	for _, child in ctx.Model:GetChildren() do
		if child:IsA("BasePart") then
			if wall and (child.Name == "Wall" or child.Name == "Lintel" or child.Name == "Pillar") then
				child.Color = wall
			elseif floor and child.Name == "Floor" then
				child.Color = floor
				if floorMaterial then
					child.Material = floorMaterial
				end
			end
		end
	end
end

local function candle(ctx: Context, position: Vector3, withLight: boolean)
	local height = ctx.Rng:NextNumber(0.5, 1.1)
	part(ctx.Model, "Candle", Vector3.new(height, 0.32, 0.32), CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), WAX, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder).CanCollide = false
	local flame = deco(ctx.Model, "CandleFlame", Vector3.new(0.14, 0.24, 0.14), CFrame.new(position + Vector3.new(0, height + 0.14, 0)), Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	flame.CastShadow = false
	if withLight then
		light(flame, Color3.fromRGB(255, 170, 90), 14, 0.9)
	end
end

local function bonePile(ctx: Context, spot: Vector3, size: number)
	local rng = ctx.Rng
	if Props.Place("BonePile", ctx.Model, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), size * rng:NextNumber(0.8, 1.1)) then
		return
	end
	for _ = 1, math.floor(4 * size) do
		deco(ctx.Model, "Bone", Vector3.new(0.3, 0.3, rng:NextNumber(1, 2)), CFrame.new(spot + Vector3.new(rng:NextNumber(-1.2, 1.2) * size, 0.2, rng:NextNumber(-1.2, 1.2) * size)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), BONE, Enum.Material.Limestone)
	end
	if rng:NextNumber() < 0.6 then
		deco(ctx.Model, "Skull", Vector3.new(0.9, 0.9, 0.9), CFrame.new(spot + Vector3.new(0, 0.45, 0)), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
	end
end

-- A cluster of wax candles (the Tripo prop) standing at `position`, with a warm light.
local function candleCluster(ctx: Context, position: Vector3, withLight: boolean): boolean
	local prop = Props.Place("Candles", ctx.Model, CFrame.new(position) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0), ctx.Rng:NextNumber(1.2, 1.5))
	if not prop then
		return false
	end
	for _, d in prop:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if withLight then
		local glow = deco(ctx.Model, "CandleGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(0, 1.8, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		glow.Transparency = 1
		light(glow, Color3.fromRGB(255, 170, 90), 14, 0.9)
	end
	return true
end

-- One to three old barrels huddled at `spot`.
local function barrels(ctx: Context, spot: Vector3)
	local rng = ctx.Rng
	for i = 1, rng:NextInteger(1, 3) do
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-2.4, 2.4))
		local tipped = i > 1 and rng:NextNumber() < 0.3
		local cf = CFrame.new(spot + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		if tipped then
			cf *= CFrame.Angles(0, 0, math.rad(90))
		end
		if not Props.Place("Barrel", ctx.Model, cf, rng:NextNumber(0.85, 1.05)) then
			return
		end
	end
end

local function cornerSpot(ctx: Context): Vector3
	local rng = ctx.Rng
	local S = ctx.Size
	local sx = if rng:NextNumber() < 0.5 then -1 else 1
	local sz = if rng:NextNumber() < 0.5 then -1 else 1
	return ctx.Center + Vector3.new(sx * rng:NextNumber(S / 2 - 8, S / 2 - 3.5), 0, sz * rng:NextNumber(S / 2 - 8, S / 2 - 3.5))
end

local function rubble(ctx: Context, spot: Vector3, pieces: number)
	local rng = ctx.Rng
	for _ = 1, pieces do
		deco(ctx.Model, "Rubble", Vector3.new(rng:NextNumber(0.8, 2.4), rng:NextNumber(0.5, 1.4), rng:NextNumber(0.8, 2.4)), CFrame.new(spot + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.35, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)), STONE, Enum.Material.Slate)
	end
end

local function banner(ctx: Context, frame: CFrame, along: number)
	local cf = onWall(ctx, frame, along, 0.3)
	-- Hung clear of the wall: the rod sticks out about a stud.
	local prop = Props.Place("Banner", ctx.Model, onWall(ctx, frame, along, 1.2) * CFrame.new(0, 5.5, 0), 1.25)
	if prop then
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		return
	end
	part(ctx.Model, "BannerRod", Vector3.new(4, 0.2, 0.2), cf * CFrame.new(0, 12.2, 0), IRON, Enum.Material.Metal).CanCollide = false
	deco(ctx.Model, "Banner", Vector3.new(3.4, 7.5, 0.12), cf * CFrame.new(0, 8.3, 0), CLOTH, Enum.Material.Fabric)
	deco(ctx.Model, "BannerEmblem", Vector3.new(1.1, 1.1, 0.14), cf * CFrame.new(0, 9.2, -0.02) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	deco(ctx.Model, "BannerTail", Vector3.new(3.4, 0.6, 0.12), cf * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(70, 16, 18), Enum.Material.Fabric)
end

-- The hall's one great banner: the banner itself `scale` times its model size, its bottom `height` above the floor,
-- lit warm from below.
local function royalBanner(ctx: Context, frame: CFrame, along: number, scale: number, height: number)
	local base = onWall(ctx, frame, along, 1.4)
	local width, top = 3.4 * scale, height + 6 * scale
	local prop = Props.Place("Banner", ctx.Model, base * CFrame.new(0, height, 0), scale)
	if prop then
		local _, size = prop:GetBoundingBox()
		width, top = size.X, height + size.Y
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	else
		deco(ctx.Model, "Banner", Vector3.new(width, top - height, 0.15), base * CFrame.new(0, (height + top) / 2, 0), CLOTH, Enum.Material.Fabric)
		deco(ctx.Model, "BannerEmblem", Vector3.new(width * 0.35, width * 0.35, 0.17), base * CFrame.new(0, top - (top - height) * 0.35, -0.02) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	end
	local wash = deco(ctx.Model, "BannerLight", Vector3.new(1, 1, 1), onWall(ctx, frame, along, 4) * CFrame.new(0, height + 1, 0), Color3.new(), Enum.Material.SmoothPlastic)
	wash.Transparency = 1
	light(wash, Color3.fromRGB(255, 160, 90), 9 + 2 * scale, 0.9)
end

local themes: { [string]: (Context) -> () } = {}

themes.Crypt = function(ctx)
	local rng = ctx.Rng
	local lit = false
	for i = 1, math.min(2, #ctx.PlainWalls) do
		local frame = ctx.PlainWalls[i]
		local positions = if ctx.Size >= 40 then { -ctx.Size / 5, ctx.Size / 5 } else { rng:NextNumber(-3, 3) }
		for _, along in positions do
			local cf = onWall(ctx, frame, along, 2.5)
			local top = 3.0
			-- Half of them the carved-knight coffin (it lies along its Z, so it's turned to run along the wall).
			local useCoffin = Props.Has("Coffin") and rng:NextNumber() < 0.5
			local prop = if useCoffin
				then Props.Place("Coffin", ctx.Model, onWall(ctx, frame, along, 3) * CFrame.Angles(0, math.rad(90), 0))
				else Props.Place("Sarcophagus", ctx.Model, cf)
			if useCoffin and prop then
				-- Its lid is a carved figure: the candles stand on the floor beside it instead.
				candleCluster(ctx, (cf * CFrame.new(4.6, 0, 0)).Position, not lit)
				lit = true
				continue
			end
			if prop then
				local _, size = prop:GetBoundingBox()
				top = size.Y
			else
				part(ctx.Model, "Sarcophagus", Vector3.new(7, 2.4, 3), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(112, 108, 98), Enum.Material.Limestone)
				part(ctx.Model, "SarcophagusLid", Vector3.new(7.4, 0.6, 3.4), cf * CFrame.new(0, 2.7, 0), Color3.fromRGB(98, 94, 86), Enum.Material.Limestone)
				deco(ctx.Model, "LidCarving", Vector3.new(4.5, 0.3, 1.2), cf * CFrame.new(0, 3.1, 0), Color3.fromRGB(88, 84, 76), Enum.Material.Limestone)
			end
			for c = 1, rng:NextInteger(1, 3) do
				candle(ctx, (cf * CFrame.new(-3 + c * 0.7, top, 1.1)).Position, not lit)
				lit = true
			end
		end
	end
	for _ = 1, 2 do
		bonePile(ctx, cornerSpot(ctx), 1)
	end
	candleCluster(ctx, cornerSpot(ctx), false)
end

themes.Flooded = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(58, 68, 66), Color3.fromRGB(36, 42, 42))
	local water = deco(ctx.Model, "Water", Vector3.new(S, 0.7, S), CFrame.new(ctx.Center + Vector3.new(0, 0.35, 0)), Color3.fromRGB(30, 54, 58), Enum.Material.SmoothPlastic)
	water.Transparency = 0.35
	water.Reflectance = 0.15
	water.CastShadow = false
	for _ = 1, rng:NextInteger(7, 11) do
		local spot = ctx.Center + Vector3.new(rng:NextNumber(-S / 2 + 4, S / 2 - 4), 0, rng:NextNumber(-S / 2 + 4, S / 2 - 4))
		part(ctx.Model, "SteppingStone", Vector3.new(rng:NextNumber(2.5, 4), 0.9, rng:NextNumber(2.5, 4)), CFrame.new(spot + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(70, 72, 70), Enum.Material.Slate)
	end
	local glow = deco(ctx.Model, "ColdLight", Vector3.new(1, 1, 1), CFrame.new(ctx.Center + Vector3.new(0, ctx.Height - 3, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(110, 160, 190), 34, 0.5)
	for _ = 1, 2 do
		rubble(ctx, cornerSpot(ctx), 3)
	end
end

themes.Ossuary = function(ctx)
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(86, 84, 76), Color3.fromRGB(64, 62, 58))
	for i = 1, math.min(3, #ctx.PlainWalls) do
		local frame = ctx.PlainWalls[i]
		for _, y in { 2.2, 4.8 } do
			local along = -S / 2 + 6
			while along <= S / 2 - 6 do
				local cf = onWall(ctx, frame, along, 0.25)
				deco(ctx.Model, "Niche", Vector3.new(2.8, 2.2, 0.5), cf * CFrame.new(0, y, 0), Color3.fromRGB(26, 24, 22), Enum.Material.Slate)
				deco(ctx.Model, "NicheSkull", Vector3.new(0.95, 0.95, 0.95), cf * CFrame.new(ctx.Rng:NextNumber(-0.5, 0.5), y - 0.5, -0.45), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
				if ctx.Rng:NextNumber() < 0.5 then
					deco(ctx.Model, "NicheBone", Vector3.new(1.8, 0.25, 0.25), cf * CFrame.new(0, y - 0.9, -0.4) * CFrame.Angles(0, 0, ctx.Rng:NextNumber(-0.2, 0.2)), BONE, Enum.Material.Limestone)
				end
				along += 3.5
			end
			deco(ctx.Model, "Shelf", Vector3.new(S - 10, 0.25, 0.9), onWall(ctx, frame, 0, 0.45) * CFrame.new(0, y - 1.15, 0), Color3.fromRGB(60, 58, 54), Enum.Material.Slate)
		end
	end
	local glow = deco(ctx.Model, "GhostLight", Vector3.new(1, 1, 1), CFrame.new(ctx.Center + Vector3.new(0, 4, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(130, 210, 150), 30, 0.35)
	for _ = 1, 4 do
		bonePile(ctx, cornerSpot(ctx), 1.3)
	end
	candleCluster(ctx, cornerSpot(ctx), false)
end

themes.Collapsed = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	for _ = 1, rng:NextInteger(2, 3) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(S / 4, S / 2 - 6)
		local base = ctx.Center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(2.5, 7)
		if Props.Place("BrokenPillar", ctx.Model, CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), height / 5) then
			rubble(ctx, base + Vector3.new(2, 0, 1), 3)
			continue
		end
		part(ctx.Model, "BrokenPillar", Vector3.new(height, 3, 3), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, math.rad(90) + rng:NextNumber(-0.12, 0.12)), STONE, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
		rubble(ctx, base + Vector3.new(2, 0, 1), 3)
	end
	if #ctx.PlainWalls > 0 then
		local cf = onWall(ctx, ctx.PlainWalls[1], rng:NextNumber(-S / 5, S / 5), 3)
		part(ctx.Model, "FallenSlab", Vector3.new(9, 1.2, 5), cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(28), 0, 0), Color3.fromRGB(60, 62, 62), Enum.Material.Slate)
	end
	-- A crack in the ceiling lets a cold beam of light fall into the room.
	local spot = ctx.Center + Vector3.new(rng:NextNumber(-S / 5, S / 5), 0, rng:NextNumber(-S / 5, S / 5))
	local beam = deco(ctx.Model, "LightBeam", Vector3.new(ctx.Height, 4.5, 4.5), CFrame.new(spot + Vector3.new(0, ctx.Height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 215, 235), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	beam.Transparency = 0.9
	beam.CastShadow = false
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 4
	dust.Lifetime = NumberRange.new(5, 8)
	dust.Speed = NumberRange.new(0.3, 0.8)
	dust.Size = NumberSequence.new(0.12)
	dust.Transparency = NumberSequence.new(0.4)
	dust.LightEmission = 0.6
	dust.Color = ColorSequence.new(Color3.fromRGB(230, 235, 240))
	dust.Parent = beam
	local lamp = deco(ctx.Model, "BeamLight", Vector3.new(1, 1, 1), CFrame.new(spot + Vector3.new(0, ctx.Height - 0.6, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	lamp.Transparency = 1
	local spotLight = Instance.new("SpotLight")
	spotLight.Face = Enum.NormalId.Bottom
	spotLight.Color = Color3.fromRGB(180, 200, 230)
	spotLight.Range = 30
	spotLight.Angle = 40
	spotLight.Brightness = 3
	spotLight.Parent = lamp
	rubble(ctx, spot, 5)
	barrels(ctx, cornerSpot(ctx))
end

themes.Chapel = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(76, 70, 66), Color3.fromRGB(62, 58, 56), Enum.Material.Pavement)
	if #ctx.PlainWalls == 0 then
		return themes.Crypt(ctx)
	end
	local frame = ctx.PlainWalls[1]
	local altar = onWall(ctx, frame, 0, 2.5)
	part(ctx.Model, "Altar", Vector3.new(7, 3.2, 3), altar * CFrame.new(0, 1.6, 0), Color3.fromRGB(96, 92, 86), Enum.Material.Limestone)
	deco(ctx.Model, "AltarCloth", Vector3.new(7.2, 0.15, 3.2), altar * CFrame.new(0, 3.25, 0), CLOTH, Enum.Material.Fabric)
	deco(ctx.Model, "AltarDrape", Vector3.new(3, 2.4, 0.12), altar * CFrame.new(0, 2.1, -1.6), CLOTH, Enum.Material.Fabric)
	if not candleCluster(ctx, (altar * CFrame.new(0, 3.3, 0)).Position, true) then
		for i = 1, 7 do
			candle(ctx, (altar * CFrame.new(rng:NextNumber(-3.2, 3.2), 3.3, rng:NextNumber(-1, 1))).Position, i == 1)
		end
	end
	banner(ctx, frame, -6)
	banner(ctx, frame, 6)
	-- Old pews facing the altar, some knocked askew
	for row = 1, 2 do
		for _, side in { -1, 1 } do
			local tilt = if rng:NextNumber() < 0.35 then rng:NextNumber(-0.5, 0.5) else 0
			local cf = onWall(ctx, frame, side * 5, 6 + row * 4.5) * CFrame.Angles(0, tilt, 0)
			part(ctx.Model, "Pew", Vector3.new(6, 1.1, 1.6), cf * CFrame.new(0, 0.9, 0), WOOD, Enum.Material.Wood)
			part(ctx.Model, "PewBack", Vector3.new(6, 1.8, 0.3), cf * CFrame.new(0, 1.6, 0.8), WOOD, Enum.Material.Wood)
		end
	end
	bonePile(ctx, cornerSpot(ctx), 0.8)
end

themes.Prison = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(64, 64, 66), Color3.fromRGB(52, 52, 54), Enum.Material.Concrete)
	if #ctx.PlainWalls == 0 then
		return themes.Crypt(ctx)
	end
	local frame = ctx.PlainWalls[1]
	local cells = if S >= 40 then 3 else 2
	local width = (S - 12) / cells
	local depth = 6
	local left = -(S - 12) / 2
	for i = 0, cells do
		local along = left + i * width
		part(ctx.Model, "CellWall", Vector3.new(0.8, 9, depth), onWall(ctx, frame, along, depth / 2) * CFrame.new(0, 4.5, 0), Color3.fromRGB(60, 60, 62), Enum.Material.Cobblestone)
	end
	for c = 0, cells - 1 do
		local cellCenter = left + (c + 0.5) * width
		local front = onWall(ctx, frame, cellCenter, depth)
		local open = rng:NextNumber() < 0.35
		local bars = Instance.new("Model")
		bars.Name = "CellBars"
		local count = math.floor(width / 0.9)
		for b = 0, count do
			local x = -width / 2 + 0.4 + b * (width - 0.8) / count
			part(bars, "Bar", Vector3.new(0.2, 9, 0.2), front * CFrame.new(x, 4.5, 0), IRON, Enum.Material.Metal)
		end
		part(bars, "Rail", Vector3.new(width, 0.35, 0.35), front * CFrame.new(0, 8.8, 0), IRON, Enum.Material.Metal)
		part(bars, "Rail", Vector3.new(width, 0.35, 0.35), front * CFrame.new(0, 1, 0), IRON, Enum.Material.Metal)
		bars.Parent = ctx.Model
		if open then
			-- This cell's door hangs open: swing the bars aside.
			local hinge = front * CFrame.new(-width / 2, 0, 0)
			bars:PivotTo(hinge * CFrame.Angles(0, math.rad(-70), 0) * hinge:Inverse() * bars:GetPivot())
		end
		local inside = onWall(ctx, frame, cellCenter, depth / 2)
		bonePile(ctx, inside.Position, 0.8)
		for _, side in { -1, 1 } do
			local chainTop = onWall(ctx, frame, cellCenter + side * 1.5, 0.3)
			for link = 0, 4 do
				deco(ctx.Model, "Chain", Vector3.new(0.18, 0.5, 0.35), chainTop * CFrame.new(0, 7 - link * 0.45, 0) * CFrame.Angles(0, if link % 2 == 0 then 0 else math.rad(90), 0), IRON, Enum.Material.Metal)
			end
			deco(ctx.Model, "Shackle", Vector3.new(0.6, 0.3, 0.6), chainTop * CFrame.new(0, 4.6, -0.1), IRON, Enum.Material.Metal)
		end
	end
	rubble(ctx, cornerSpot(ctx), 2)
	barrels(ctx, cornerSpot(ctx))
end

themes.Vault = function(ctx)
	local rng = ctx.Rng
	tint(ctx, Color3.fromRGB(74, 70, 64), Color3.fromRGB(60, 56, 50), Enum.Material.Pavement)
	for _ = 1, rng:NextInteger(3, 4) do
		local spot = cornerSpot(ctx)
		for _ = 1, rng:NextInteger(12, 18) do
			local r = rng:NextNumber(0, 1.6)
			local a = rng:NextNumber(0, math.pi * 2)
			local height = math.max(0.06, (1.6 - r) * 0.5) + rng:NextNumber(0, 0.15)
			deco(ctx.Model, "Coins", Vector3.new(0.12, 0.7, 0.7), CFrame.new(spot + Vector3.new(math.cos(a) * r, height, math.sin(a) * r)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, math.rad(90) + rng:NextNumber(-0.3, 0.3)), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	if #ctx.PlainWalls > 0 then
		banner(ctx, ctx.PlainWalls[1], -5)
		banner(ctx, ctx.PlainWalls[1], 5)
	end
	local glow = deco(ctx.Model, "GoldGlow", Vector3.new(1, 1, 1), CFrame.new(ctx.Center + Vector3.new(0, 3, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(255, 200, 110), 22, 0.5)
	barrels(ctx, cornerSpot(ctx))
end

-- A lighter touch for rooms with no theme of their own (stairs, secret rooms).
local EARTH = Color3.fromRGB(58, 46, 36)
local GRAVE_STONE = Color3.fromRGB(96, 98, 94)

local function headstone(ctx: Context, cframe: CFrame)
	local rng = ctx.Rng
	local height = rng:NextNumber(2.6, 3.8)
	local width = rng:NextNumber(1.8, 2.4)
	local lean = CFrame.Angles(rng:NextNumber(-0.18, 0.12), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.12, 0.12))
	local base = cframe * lean
	local slab = part(ctx.Model, "Headstone", Vector3.new(width, height - width / 2, 0.55), base * CFrame.new(0, (height - width / 2) / 2 - 0.3, 0), GRAVE_STONE, Enum.Material.Slate)
	part(ctx.Model, "HeadstoneTop", Vector3.new(0.55, width, width), base * CFrame.new(0, height - width / 2 - 0.3, 0) * CFrame.Angles(0, math.rad(90), 0), GRAVE_STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
	-- an engraved cross on the face
	deco(ctx.Model, "Engraving", Vector3.new(0.18, height * 0.45, 0.08), slab.CFrame * CFrame.new(0, 0.2, -0.3), Color3.fromRGB(60, 62, 60), Enum.Material.Slate)
	deco(ctx.Model, "Engraving", Vector3.new(width * 0.45, 0.18, 0.08), slab.CFrame * CFrame.new(0, height * 0.12, -0.3), Color3.fromRGB(60, 62, 60), Enum.Material.Slate)
	-- a little heap of earth in front of it
	deco(ctx.Model, "GraveMound", Vector3.new(width * 1.1, 0.7, 4.2), cframe * CFrame.new(0, 0.05, -2.4), EARTH, Enum.Material.Ground, Enum.PartType.Ball)
end

local function openGrave(ctx: Context, spot: Vector3, turn: number)
	local rng = ctx.Rng
	local frame = CFrame.new(spot) * CFrame.Angles(0, turn, 0)
	-- the dark pit, the stone edge round it and the earth dug out beside it
	deco(ctx.Model, "GravePit", Vector3.new(3.4, 0.1, 6.6), frame * CFrame.new(0, 0.06, 0), Color3.fromRGB(14, 11, 9), Enum.Material.Ground)
	for _, side in { -1, 1 } do
		part(ctx.Model, "GraveEdge", Vector3.new(0.5, 0.4, 7.4), frame * CFrame.new(side * 1.95, 0.2, 0), Color3.fromRGB(74, 72, 68), Enum.Material.Cobblestone)
	end
	part(ctx.Model, "DugEarth", Vector3.new(3.6, 2.2, 5.2), frame * CFrame.new(3.9, 0.3, 0.4) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), EARTH, Enum.Material.Ground, Enum.PartType.Ball)
	-- a shovel left stuck in the heap
	local shovel = Props.Place("GravekeeperShovel", ctx.Model, frame * CFrame.new(3.6, 0.6, 0.2) * CFrame.Angles(math.rad(rng:NextNumber(-25, -12)), 0, math.rad(rng:NextNumber(-15, 15))) * CFrame.Angles(math.rad(180), 0, 0), 0.55)
	if shovel then
		for _, d in shovel:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	headstone(ctx, frame * CFrame.new(0, 0, -4.4) * CFrame.Angles(0, math.pi, 0))
end

-- A lair prop stood against a wall: placed at `along`, then pushed out so its back sits `gap` studs off the wall.
-- The stored props are turned so their front is -Z and sized for the lair, so no scale is needed.
local function againstWall(ctx: Context, name: string, frame: CFrame, along: number, gap: number, turn: number?): (Model?, number)
	local cf = onWall(ctx, frame, along, 0) * CFrame.Angles(0, turn or 0, 0)
	local prop = Props.Place(name, ctx.Model, cf)
	if not prop then
		return nil, 0
	end
	local _, size = prop:GetBoundingBox()
	local inward = -frame.LookVector
	prop:PivotTo(prop:GetPivot() + inward * (size.Z / 2 + gap))
	return prop, size.Z + gap
end

-- Takes the collision off a prop the players should walk through (fences, skulls, branches overhead).
local function ghost(prop: Model?)
	if prop then
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
end

-- The plain wall facing the way in: the back of the lair.
local function backWall(ctx: Context): CFrame?
	local entry = ctx.Doorways and ctx.Doorways[1]
	local inward = if entry then (ctx.Center - entry) * Vector3.new(1, 0, 1) else Vector3.zero
	local best, bestDot = nil, -math.huge
	for _, frame in ctx.PlainWalls do
		local dot = if inward.Magnitude > 0.1 then frame.LookVector:Dot(inward.Unit) else 0
		if dot > bestDot then
			best, bestDot = frame, dot
		end
	end
	return best
end

local RUNE_DARK = Color3.fromRGB(34, 38, 36)

-- The fighting ring: a dark stone circle edged with runes (parts named "LairRune", lit by FloorService).
local function runeCircle(ctx: Context, radius: number)
	local rng = ctx.Rng
	local c = ctx.Center
	deco(ctx.Model, "ArenaStone", Vector3.new(0.14, radius * 2 + 3, radius * 2 + 3), CFrame.new(c + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(52, 54, 52), Enum.Material.Slate, Enum.PartType.Cylinder)
	-- two thin rings, outer and inner, of short curved segments
	for _, r in { radius + 1.1, radius - 1.1, 3.2 } do
		local count = math.max(math.floor(r * 2.2), 10)
		local length = 2 * math.pi * r / count + 0.05
		for i = 1, count do
			local a = (i / count) * math.pi * 2
			local p = c + Vector3.new(math.cos(a) * r, 0.16, math.sin(a) * r)
			deco(ctx.Model, "LairRune", Vector3.new(length, 0.06, 0.22), CFrame.lookAt(p, c + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, math.rad(90), 0), RUNE_DARK, Enum.Material.Slate)
		end
	end
	-- glyphs between the rings: a stem with a couple of crossing strokes each, never two alike
	local glyphs = 16
	for i = 1, glyphs do
		local a = (i / glyphs) * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * radius, 0.17, math.sin(a) * radius)
		local frame = CFrame.lookAt(p, c + Vector3.new(0, 0.17, 0))
		deco(ctx.Model, "LairRune", Vector3.new(0.18, 0.06, 1.3), frame, RUNE_DARK, Enum.Material.Slate)
		for _ = 1, rng:NextInteger(1, 3) do
			deco(ctx.Model, "LairRune", Vector3.new(0.16, 0.06, rng:NextNumber(0.5, 0.9)), frame * CFrame.new(0, 0, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, math.rad(rng:NextNumber(35, 145)), 0), RUNE_DARK, Enum.Material.Slate)
		end
	end
	-- the sigil in the middle: a cross of strokes inside the small ring
	for k = 0, 3 do
		deco(ctx.Model, "LairRune", Vector3.new(0.2, 0.06, 5.4), CFrame.new(c + Vector3.new(0, 0.17, 0)) * CFrame.Angles(0, k * math.pi / 4, 0), RUNE_DARK, Enum.Material.Slate)
	end
end

-- A chain hanging from the ceiling at `top`, `links` long; returns where it ends.
local function chain(ctx: Context, top: Vector3, links: number): Vector3
	for link = 0, links - 1 do
		deco(ctx.Model, "Chain", Vector3.new(0.2, 0.55, 0.4), CFrame.new(top - Vector3.new(0, link * 0.48 + 0.3, 0)) * CFrame.Angles(0, if link % 2 == 0 then 0 else math.rad(90), 0), IRON, Enum.Material.Metal)
	end
	return top - Vector3.new(0, links * 0.48 + 0.3, 0)
end

-- An iron cage hanging on a chain, with what's left of its prisoner inside.
local function hangingCage(ctx: Context, spot: Vector3, links: number)
	local rng = ctx.Rng
	local bottom = chain(ctx, Vector3.new(spot.X, ctx.Center.Y + ctx.Height, spot.Z), links)
	local h, r = 4.6, 1.6
	local frame = CFrame.new(bottom - Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-6, 6)))
	for _, y in { h / 2, -h / 2 } do
		deco(ctx.Model, "CageRing", Vector3.new(0.25, r * 2 + 0.3, r * 2 + 0.3), frame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		deco(ctx.Model, "CageBar", Vector3.new(0.14, h, 0.14), frame * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), IRON, Enum.Material.Metal)
	end
	deco(ctx.Model, "CageDome", Vector3.new(r * 2, 1.2, r * 2), frame * CFrame.new(0, h / 2 + 0.3, 0), IRON, Enum.Material.Metal, Enum.PartType.Ball)
	deco(ctx.Model, "Skull", Vector3.new(0.8, 0.8, 0.8), frame * CFrame.new(0.3, -h / 2 + 0.55, 0.2), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
	for _ = 1, 3 do
		deco(ctx.Model, "Bone", Vector3.new(0.22, 0.22, rng:NextNumber(1, 1.6)), frame * CFrame.new(rng:NextNumber(-0.7, 0.7), -h / 2 + 0.3, rng:NextNumber(-0.7, 0.7)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), BONE, Enum.Material.Limestone)
	end
end

-- Cold moonlight falling through a crack over the middle, with dust turning in it.
local function moonBeam(ctx: Context)
	local spot = ctx.Center
	local beam = deco(ctx.Model, "MoonBeam", Vector3.new(ctx.Height, 9, 9), CFrame.new(spot + Vector3.new(0, ctx.Height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 215, 235), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	beam.Transparency = 0.93
	beam.CastShadow = false
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 7
	dust.Lifetime = NumberRange.new(6, 9)
	dust.Speed = NumberRange.new(0.2, 0.6)
	dust.Size = NumberSequence.new(0.12)
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.LightEmission = 0.7
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 235, 245))
	dust.Parent = beam
	local lamp = deco(ctx.Model, "MoonLight", Vector3.new(1, 1, 1), CFrame.new(spot + Vector3.new(0, ctx.Height - 0.6, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	lamp.Transparency = 1
	local spotLight = Instance.new("SpotLight")
	spotLight.Face = Enum.NormalId.Bottom
	spotLight.Color = Color3.fromRGB(170, 195, 235)
	spotLight.Range = 30
	spotLight.Angle = 50
	spotLight.Brightness = 2.5
	spotLight.Shadows = true
	spotLight.Parent = lamp
	-- the crack itself, pale against the dark ceiling
	for i = 1, 5 do
		deco(ctx.Model, "CeilingCrack", Vector3.new(ctx.Rng:NextNumber(2, 5), 0.1, 0.4), CFrame.new(spot + Vector3.new(0, ctx.Height - 0.05, 0)) * CFrame.Angles(0, i * 1.25 + ctx.Rng:NextNumber(-0.3, 0.3), 0) * CFrame.new(2.5, 0, 0), Color3.fromRGB(150, 170, 190), Enum.Material.Neon).Transparency = 0.4
	end
end

-- The Gravekeeper's tomb against the back wall, an angel weeping on each side and skulls heaped at their feet.
-- Leaves BossDoor (where it waits) and BossSpot (where it steps out to) on the room for FloorService.
local function tomb(ctx: Context, back: CFrame)
	local inward = -back.LookVector
	local floorAtWall = onWall(ctx, back, 0, 0).Position
	local tombModel, depth = againstWall(ctx, "Mausoleum", back, 0, 0.6)
	local width = 14
	if tombModel then
		local _, size = tombModel:GetBoundingBox()
		width = size.X
		-- a green glow and grave mist spilling out through its gate
		local door = deco(ctx.Model, "TombGlow", Vector3.new(1, 1, 1), CFrame.lookAt(floorAtWall + inward * (depth - 1.5) + Vector3.new(0, 0.6, 0), floorAtWall + inward * depth + Vector3.new(0, 0.6, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		door.Transparency = 1
		light(door, Color3.fromRGB(110, 230, 150), 16, 1.6)
		local seep = Instance.new("ParticleEmitter")
		seep.Color = ColorSequence.new(Color3.fromRGB(150, 200, 165))
		seep.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		seep.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) })
		seep.Lifetime = NumberRange.new(4, 6)
		seep.Speed = NumberRange.new(1, 2)
		seep.SpreadAngle = Vector2.new(25, 5)
		seep.EmissionDirection = Enum.NormalId.Front
		seep.Rate = 5
		seep.LightInfluence = 1
		seep.Parent = door
	else
		depth = 3
	end
	ctx.Model:SetAttribute("BossDoor", floorAtWall + inward * (depth + 2.5))
	ctx.Model:SetAttribute("BossSpot", floorAtWall + inward * (depth + 10))

	for _, side in { -1, 1 } do
		local along = side * (width / 2 + 5.5)
		local angel, angelDepth = againstWall(ctx, "AngelStatue", back, along, 0.8, side * math.rad(-14))
		if angel then
			local skulls = Props.Place("SkullPile", ctx.Model, onWall(ctx, back, along - side * 1.5, angelDepth + 2.2) * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0))
			ghost(skulls)
		end
		-- candles with a warm light on the tomb steps
		candleCluster(ctx, onWall(ctx, back, side * (width / 2 - 1), depth + 1.2).Position, true)
	end
end

themes.Graveyard = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(62, 60, 58), Color3.fromRGB(46, 40, 34), Enum.Material.Ground)
	local back = backWall(ctx)
	if back then
		tomb(ctx, back)
	end
	-- Rows of headstones along the other walls without doorways, a second row a step further in,
	-- and a dead tree reaching over them.
	for _, frame in ctx.PlainWalls do
		if frame == back then
			continue
		end
		local tree = if Props.Has("DeadTree") then rng:NextNumber(-S / 6, S / 6) else nil
		if tree then
			ghost((againstWall(ctx, "DeadTree", frame, tree, 1.5, rng:NextNumber(-0.6, 0.6))))
		end
		local along = -S / 2 + 6
		while along <= S / 2 - 6 do
			if not tree or math.abs(along - tree) > 3.5 then
				headstone(ctx, onWall(ctx, frame, along + rng:NextNumber(-0.8, 0.8), 2.2))
			end
			if rng:NextNumber() < 0.6 and (not tree or math.abs(along + 2.5 - tree) > 4.5) then
				headstone(ctx, onWall(ctx, frame, along + 2.5 + rng:NextNumber(-0.6, 0.6), 7.5))
			end
			if rng:NextNumber() < 0.35 then
				candleCluster(ctx, (onWall(ctx, frame, along + 1.4, 4.2)).Position, false)
			end
			along += 5.5
		end
		-- a coffin left out against each wall
		if Props.Has("Coffin") then
			Props.Place("Coffin", ctx.Model, onWall(ctx, frame, (if tree and tree < 0 then 1 else -1) * rng:NextNumber(S / 8, S / 4), 3.2) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	-- Open graves in the four corners of the clear middle, each fenced with iron on its open side.
	for i, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local spot = ctx.Center + corner * (S / 2 - 12)
		local turn = math.rad(45) + i * math.pi / 2
		openGrave(ctx, spot, turn)
		ghost(Props.Place("IronFence", ctx.Model, CFrame.new(spot) * CFrame.Angles(0, turn, 0) * CFrame.new(-3.1, 0, -0.4) * CFrame.Angles(0, math.rad(90), 0)))
	end
	for _ = 1, 3 do
		bonePile(ctx, cornerSpot(ctx), 1.1)
	end
	runeCircle(ctx, 15)
	moonBeam(ctx)
	-- Chains hanging from the ceiling round the ring, two of them holding cages.
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local spot = ctx.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(17, 21)
		if i == 2 or i == 6 then
			hangingCage(ctx, spot, rng:NextInteger(6, 10))
		else
			local ends = chain(ctx, Vector3.new(spot.X, ctx.Center.Y + ctx.Height, spot.Z), rng:NextInteger(5, 12))
			deco(ctx.Model, "Hook", Vector3.new(0.25, 0.9, 0.25), CFrame.new(ends - Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(20)), IRON, Enum.Material.Metal)
		end
	end
	-- A low grave mist drifting over the whole floor, and a sickly green glow from the graves.
	local mist = deco(ctx.Model, "GraveMist", Vector3.new(S - 4, 0.2, S - 4), CFrame.new(ctx.Center + Vector3.new(0, 0.4, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	mist.Transparency = 1
	local fog = Instance.new("ParticleEmitter")
	fog.Color = ColorSequence.new(Color3.fromRGB(170, 185, 175))
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 8) })
	fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.86), NumberSequenceKeypoint.new(1, 1) })
	fog.Lifetime = NumberRange.new(7, 10)
	fog.Speed = NumberRange.new(0.3, 0.9)
	fog.SpreadAngle = Vector2.new(180, 10)
	fog.Acceleration = Vector3.new(0, 0.05, 0)
	fog.Rate = 9
	fog.LightInfluence = 1
	fog.Parent = mist
	local glow = deco(ctx.Model, "GraveGlow", Vector3.new(1, 1, 1), CFrame.new(ctx.Center + Vector3.new(0, 2, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	glow.Transparency = 1
	light(glow, Color3.fromRGB(110, 200, 140), 40, 0.4)
end

-- The Bone Warden's throne room: the sealed gate to the king on the back wall, the bone throne before it,
-- a red carpet from the way in up to the throne, knight statues standing guard along the walls, broken
-- royal pillars, braziers round a ring of runes that burn red when the fight starts (RuneColor), and banners.
themes.ThroneRoom = function(ctx)
	local rng = ctx.Rng
	local S = ctx.Size
	tint(ctx, Color3.fromRGB(48, 46, 50), Color3.fromRGB(40, 38, 42), Enum.Material.Slate)
	ctx.Model:SetAttribute("RuneColor", Color3.fromRGB(230, 60, 50))
	local back = backWall(ctx)
	if back then
		local inward = -back.LookVector
		local floorAtWall = onWall(ctx, back, 0, 0).Position
		local gate, gateDepth = againstWall(ctx, "SealedGate", back, 0, 0.3)
		local gateWidth = 20
		if gate then
			local _, size = gate:GetBoundingBox()
			gateWidth = size.X
			-- a dull red glow through the cracks of the gate
			local seep = deco(ctx.Model, "GateGlow", Vector3.new(1, 1, 1), CFrame.new(floorAtWall + inward * (gateDepth + 1) + Vector3.new(0, 6, 0)), Color3.new(), Enum.Material.SmoothPlastic)
			seep.Transparency = 1
			light(seep, Color3.fromRGB(255, 70, 50), 22, 1.4)
		else
			gateDepth = 2
		end
		-- the throne before the gate, and where its keeper waits
		local throneAt = gateDepth + 4
		local throne = Props.Place("BoneThrone", ctx.Model, onWall(ctx, back, 0, throneAt))
		local throneDepth = 6
		if throne then
			local _, size = throne:GetBoundingBox()
			throneDepth = size.Z
		end
		ctx.Model:SetAttribute("BossDoor", floorAtWall + inward * (throneAt + throneDepth / 2 + 3))
		ctx.Model:SetAttribute("BossSpot", floorAtWall + inward * (throneAt + throneDepth / 2 + 11))
		-- two knights flanking the gate
		for _, side in { -1, 1 } do
			againstWall(ctx, "KnightStatue", back, side * (gateWidth / 2 + 4), 0.6)
		end
		-- the red carpet up to the throne
		local length = S - throneAt - throneDepth - 6
		local carpetMid = floorAtWall + inward * (throneAt + throneDepth + length / 2)
		-- (it lies over the arena stone, whose top is 0.14 up)
		deco(ctx.Model, "Carpet", Vector3.new(7, 0.1, length), CFrame.lookAt(carpetMid + Vector3.new(0, 0.13, 0), carpetMid + Vector3.new(0, 0.13, 0) + inward), Color3.fromRGB(110, 18, 22), Enum.Material.Fabric)
		for _, side in { -1, 1 } do
			deco(ctx.Model, "CarpetHem", Vector3.new(0.5, 0.12, length), CFrame.lookAt(carpetMid, carpetMid + inward) * CFrame.new(side * 3.7, 0.14, 0), Color3.fromRGB(200, 160, 60), Enum.Material.Fabric)
		end
	end
	-- knights and broken pillars along the side walls, a great banner between them
	for _, frame in ctx.PlainWalls do
		if frame == back then
			continue
		end
		for _, side in { -1, 1 } do
			againstWall(ctx, "KnightStatue", frame, side * S / 5, 0.8)
			ghost((againstWall(ctx, "BrokenPillarRoyal", frame, side * S / 2.6, 1.5, rng:NextNumber(0, math.pi * 2))))
		end
		royalBanner(ctx, frame, 0, 3, 1.2)
	end
	-- royal braziers round the fighting ring
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local spot = ctx.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * 18
		local brazier = Props.Place("RoyalBrazier", ctx.Model, CFrame.new(spot))
		local glowAt = deco(ctx.Model, "BrazierFire", Vector3.new(1, 1, 1), CFrame.new(spot + Vector3.new(0, 6.2, 0)), Color3.new(), Enum.Material.SmoothPlastic)
		glowAt.Transparency = 1
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Color = Color3.fromRGB(255, 120, 50)
		fire.SecondaryColor = Color3.fromRGB(200, 40, 20)
		fire.Parent = glowAt
		light(glowAt, Color3.fromRGB(255, 130, 70), 26, 1.4)
		local _ = brazier
	end
	runeCircle(ctx, 14)
	-- a cold, dim air over the hall
	local air = deco(ctx.Model, "HallGlow", Vector3.new(1, 1, 1), CFrame.new(ctx.Center + Vector3.new(0, ctx.Height - 3, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	air.Transparency = 1
	light(air, Color3.fromRGB(150, 140, 190), 50, 0.5)
end

themes.Plain = function(ctx)
	bonePile(ctx, cornerSpot(ctx), 1)
	rubble(ctx, cornerSpot(ctx), 3)
	barrels(ctx, cornerSpot(ctx))
end

function RoomDecor.Decorate(ctx: Context, theme: string)
	local build = themes[theme] or themes.Plain
	build(ctx)
end

return RoomDecor
