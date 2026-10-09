--!strict
-- Dresses a room in one of the Drowned Catacombs themes, so no two rooms in a row look alike.
--   Crypt:     sarcophagi with candles on the lids
--   Flooded:   dark water over the whole floor, stepping stones, a cold light
--   Ossuary:   walls lined with shelves of skulls, a faint green glow
--   Collapsed: broken pillars, rubble, a fallen slab, and a beam of light through a cracked ceiling
--   Chapel:    an altar with candles, red banners, old pews
--   Prison:    barred cells along a wall, chains and remains inside
--   Vault:     heaps of gold coins and banners (treasure rooms)
-- Big pieces only go along walls without a doorway, so paths and the middle of the room stay clear.

export type Context = {
	Model: Model,
	Center: Vector3,
	Size: number,
	Height: number,
	PlainWalls: { CFrame }, -- frames at the center, looking out through each wall without a doorway
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
	part(ctx.Model, "BannerRod", Vector3.new(4, 0.2, 0.2), cf * CFrame.new(0, 12.2, 0), IRON, Enum.Material.Metal).CanCollide = false
	deco(ctx.Model, "Banner", Vector3.new(3.4, 7.5, 0.12), cf * CFrame.new(0, 8.3, 0), CLOTH, Enum.Material.Fabric)
	deco(ctx.Model, "BannerEmblem", Vector3.new(1.1, 1.1, 0.14), cf * CFrame.new(0, 9.2, -0.02) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
	deco(ctx.Model, "BannerTail", Vector3.new(3.4, 0.6, 0.12), cf * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(70, 16, 18), Enum.Material.Fabric)
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
			local prop = Props.Place("Sarcophagus", ctx.Model, cf)
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
	for i = 1, 7 do
		candle(ctx, (altar * CFrame.new(rng:NextNumber(-3.2, 3.2), 3.3, rng:NextNumber(-1, 1))).Position, i == 1)
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
end

-- A lighter touch for rooms with no theme of their own (stairs, secret rooms).
themes.Plain = function(ctx)
	bonePile(ctx, cornerSpot(ctx), 1)
	rubble(ctx, cornerSpot(ctx), 3)
end

function RoomDecor.Decorate(ctx: Context, theme: string)
	local build = themes[theme] or themes.Plain
	build(ctx)
end

return RoomDecor
