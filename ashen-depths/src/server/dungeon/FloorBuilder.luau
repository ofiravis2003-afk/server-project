--!strict
-- Builds a floor's stone rooms and corridors out of parts, from a FloorLayout plan.
-- Chapter I look (The Drowned Catacombs): damp grey-green stone, torches, sarcophagi, bones and puddles.
-- Until the KayKit pieces arrive, everything here is plain parts; the game logic doesn't care.


local FloorLayout = require(script.Parent.FloorLayout)

local PITCH = 76 -- distance between room centers
local WALL_HEIGHT = 18
local WALL = 2 -- wall thickness
local DOOR_WIDTH = 10
local DOOR_HEIGHT = 12
local HOLE = 10 -- the stairwell opening in the Stairs room

local FLOOR_COLOR = Color3.fromRGB(58, 58, 60)
local WALL_COLOR = Color3.fromRGB(72, 76, 73)
local CEILING_COLOR = Color3.fromRGB(38, 40, 40)
local IRON = Color3.fromRGB(42, 40, 40)
local BONE = Color3.fromRGB(205, 196, 172)
local SARCOPHAGUS = Color3.fromRGB(112, 108, 98)

export type Gate = { Part: BasePart, Open: CFrame, Closed: CFrame }

export type BuiltRoom = {
	Plan: FloorLayout.RoomPlan,
	Center: Vector3, -- center of the room at floor height
	Size: number,
	Model: Model,
	Gates: { Gate }, -- combat rooms: iron gates in every doorway, open at the start
	SecretWall: Gate?, -- the combat room in front of a secret room: the fake wall a lever opens
	Lever: Model?,
	StairsPart: BasePart?, -- stairs room: where the "Descend" prompt goes
	Doorways: { Vector3 }, -- floor-level centers of the doorways, so nothing is placed in the way
}

export type BuiltCorridor = { Frame: CFrame, Length: number }

local FloorBuilder = {}

FloorBuilder.DoorWidth = DOOR_WIDTH
FloorBuilder.TierColors = {
	Bronze = Color3.fromRGB(176, 110, 60),
	Silver = Color3.fromRGB(200, 205, 215),
	Gold = Color3.fromRGB(240, 195, 70),
}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function attached(parent: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = block(parent, name, size, cframe, color, material)
	p.Anchored = false
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	return p
end

local function flat(d: Vector2): Vector3
	return Vector3.new(d.X, 0, d.Y)
end

-- A frame standing at `center`, looking out through the wall on side `dir`.
local function sideFrame(center: Vector3, dir: Vector2): CFrame
	return CFrame.lookAt(center, center + flat(dir))
end

function FloorBuilder.Torch(parent: Instance, position: Vector3, facing: Vector3, shadows: boolean)
	local base = CFrame.lookAt(position, position + facing)
	block(parent, "Bracket", Vector3.new(0.4, 0.4, 1.2), base * CFrame.new(0, 0, -0.5), IRON, Enum.Material.Metal)
	local stick = block(
		parent,
		"TorchStick",
		Vector3.new(0.35, 1.8, 0.35),
		base * CFrame.new(0, 0.6, -1.0) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(80, 55, 35),
		Enum.Material.Wood
	)
	local flame = block(parent, "Flame", Vector3.new(0.5, 0.7, 0.5), stick.CFrame * CFrame.new(0, 1.1, 0), Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
	flame.CanCollide = false
	flame.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 24
	light.Brightness = 1.25
	light.Shadows = shadows
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 90)
	fire.Parent = flame
end

-- An iron portcullis filling a doorway. Starts open (sunk into the floor).
local function buildGate(parent: Instance, closed: CFrame): Gate
	local open = closed - Vector3.new(0, DOOR_HEIGHT + 1, 0)
	local gate = block(parent, "Gate", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6), closed, IRON, Enum.Material.Metal)
	gate.Transparency = 1
	for i = 0, 6 do
		local x = -DOOR_WIDTH / 2 + 0.4 + i * (DOOR_WIDTH - 0.8) / 6
		attached(gate, "Bar", Vector3.new(0.35, DOOR_HEIGHT, 0.35), closed * CFrame.new(x, 0, 0), IRON, Enum.Material.Metal)
	end
	for _, y in { -DOOR_HEIGHT / 2 + 2, 0, DOOR_HEIGHT / 2 - 1.5 } do
		attached(gate, "Rail", Vector3.new(DOOR_WIDTH, 0.4, 0.4), closed * CFrame.new(0, y, 0), IRON, Enum.Material.Metal)
	end
	gate.CFrame = open
	return { Part = gate, Open = open, Closed = closed }
end

function FloorBuilder.Chest(parent: Instance, cframe: CFrame, tier: string): Model
	local model = Instance.new("Model")
	model.Name = `{tier}Chest`
	local wood = Color3.fromRGB(96, 62, 38)
	local metal = FloorBuilder.TierColors[tier] or FloorBuilder.TierColors.Bronze
	local base = block(model, "Base", Vector3.new(3.2, 1.6, 2.2), cframe * CFrame.new(0, 0.8, 0), wood, Enum.Material.Wood)
	for _, x in { -1.1, 1.1 } do
		attached(base, "Band", Vector3.new(0.25, 1.64, 2.26), base.CFrame * CFrame.new(x, 0, 0), metal, Enum.Material.Metal)
	end
	attached(base, "Lock", Vector3.new(0.55, 0.6, 0.2), base.CFrame * CFrame.new(0, 0.4, -1.15), metal, Enum.Material.Metal)
	local lid = block(model, "Lid", Vector3.new(3.2, 0.7, 2.2), cframe * CFrame.new(0, 1.95, 0), wood, Enum.Material.Wood)
	for _, x in { -1.1, 1.1 } do
		attached(lid, "LidBand", Vector3.new(0.25, 0.74, 2.26), lid.CFrame * CFrame.new(x, 0, 0), metal, Enum.Material.Metal)
	end
	model.PrimaryPart = base
	model.Parent = parent
	return model
end

-- Swings a chest's lid open on its back hinge.
function FloorBuilder.ChestOpenCFrame(lid: BasePart): CFrame
	local hinge = lid.CFrame * CFrame.new(0, -lid.Size.Y / 2, lid.Size.Z / 2)
	return hinge * CFrame.Angles(math.rad(100), 0, 0) * (hinge:Inverse() * lid.CFrame)
end

function FloorBuilder.KeyPedestal(parent: Instance, position: Vector3, tier: string): Model
	local model = Instance.new("Model")
	model.Name = `{tier}KeyPedestal`
	local stone = block(model, "Pedestal", Vector3.new(2.2, 3, 2.2), CFrame.new(position + Vector3.new(0, 1.5, 0)), Color3.fromRGB(70, 70, 74), Enum.Material.Slate)
	local metal = FloorBuilder.TierColors[tier]
	local keyCenter = CFrame.new(position + Vector3.new(0, 4.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local shaft = block(model, "Key", Vector3.new(1.6, 0.22, 0.22), keyCenter, metal, Enum.Material.Metal)
	shaft.CanCollide = false
	attached(shaft, "Bow", Vector3.new(0.2, 0.75, 0.75), keyCenter * CFrame.new(-0.95, 0, 0), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	attached(shaft, "Bit", Vector3.new(0.3, 0.45, 0.14), keyCenter * CFrame.new(0.65, -0.3, 0), metal, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 210, 255)
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = shaft
	model.Parent = parent
	return model
end

-- Builds one room. `openings` lists the sides that lead somewhere, and whether that side hides a secret.
local function buildRoom(
	floorModel: Model,
	plan: FloorLayout.RoomPlan,
	center: Vector3,
	openings: { { Dir: Vector2, SecretHere: boolean } },
	rng: Random
): BuiltRoom
	local model = Instance.new("Model")
	model.Name = `{plan.Type}_{plan.Key}`
	local S = plan.Size
	local outer = S + WALL * 2

	local built: BuiltRoom = {
		Plan = plan,
		Center = center,
		Size = S,
		Model = model,
		Gates = {},
		SecretWall = nil,
		Lever = nil,
		StairsPart = nil,
		Doorways = {},
	}

	-- Floor (the Stairs room leaves a hole in the middle for the stairwell)
	if plan.Type == "Stairs" then
		local w = (outer - HOLE) / 2
		block(model, "Floor", Vector3.new(outer, 2, w), CFrame.new(center + Vector3.new(0, -1, -(HOLE / 2 + w / 2))), FLOOR_COLOR, Enum.Material.Slate)
		block(model, "Floor", Vector3.new(outer, 2, w), CFrame.new(center + Vector3.new(0, -1, HOLE / 2 + w / 2)), FLOOR_COLOR, Enum.Material.Slate)
		block(model, "Floor", Vector3.new(w, 2, HOLE), CFrame.new(center + Vector3.new(-(HOLE / 2 + w / 2), -1, 0)), FLOOR_COLOR, Enum.Material.Slate)
		block(model, "Floor", Vector3.new(w, 2, HOLE), CFrame.new(center + Vector3.new(HOLE / 2 + w / 2, -1, 0)), FLOOR_COLOR, Enum.Material.Slate)
		-- The shaft and steps going down into the dark (entered from the +Z side)
		local depth = 14
		for _, side in { { Vector3.new(0, 0, -(HOLE / 2 + 0.5)), Vector3.new(HOLE + 2, depth, 1) }, { Vector3.new(-(HOLE / 2 + 0.5), 0, 0), Vector3.new(1, depth, HOLE) }, { Vector3.new(HOLE / 2 + 0.5, 0, 0), Vector3.new(1, depth, HOLE) } } do
			block(model, "Shaft", side[2], CFrame.new(center + side[1] + Vector3.new(0, -depth / 2, 0)), WALL_COLOR, Enum.Material.Cobblestone)
		end
		local steps = 7
		for i = 1, steps do
			local stepDepth = HOLE / steps
			block(model, "Step", Vector3.new(HOLE, 1, stepDepth), CFrame.new(center + Vector3.new(0, -1.6 * i + 0.5, HOLE / 2 - stepDepth * (i - 0.5))), Color3.fromRGB(64, 62, 64), Enum.Material.Slate)
		end
		local dark = block(model, "Darkness", Vector3.new(HOLE, 1, HOLE), CFrame.new(center + Vector3.new(0, -depth, 0)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		dark.CanCollide = true
		-- A low stone rim around the three open sides of the hole
		for _, rim in { { Vector3.new(0, 1, -(HOLE / 2 + 0.6)), Vector3.new(HOLE + 2.4, 2, 1.2) }, { Vector3.new(-(HOLE / 2 + 0.6), 1, 0), Vector3.new(1.2, 2, HOLE) }, { Vector3.new(HOLE / 2 + 0.6, 1, 0), Vector3.new(1.2, 2, HOLE) } } do
			block(model, "Rim", rim[2], CFrame.new(center + rim[1]), Color3.fromRGB(80, 78, 80), Enum.Material.Slate)
		end
		local stairsPart = block(model, "StairsPrompt", Vector3.new(2, 2, 2), CFrame.new(center + Vector3.new(0, 2, HOLE / 2)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		stairsPart.Transparency = 1
		stairsPart.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 90, 50)
		glow.Range = 14
		glow.Brightness = 1.2
		glow.Parent = dark
		built.StairsPart = stairsPart
	else
		block(model, "Floor", Vector3.new(outer, 2, outer), CFrame.new(center + Vector3.new(0, -1, 0)), FLOOR_COLOR, Enum.Material.Slate)
	end
	block(model, "Ceiling", Vector3.new(outer, 2, outer), CFrame.new(center + Vector3.new(0, WALL_HEIGHT + 1, 0)), CEILING_COLOR, Enum.Material.Slate)

	-- Walls, doorways, gates and torches, side by side
	local openSides: { [string]: { Dir: Vector2, SecretHere: boolean } } = {}
	for _, opening in openings do
		openSides[`{opening.Dir.X},{opening.Dir.Y}`] = opening
	end
	local plainWalls: { CFrame } = {}
	for _, dir in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
		local frame = sideFrame(center, dir)
		local wallZ = -(S / 2 + WALL / 2)
		local opening = openSides[`{dir.X},{dir.Y}`]
		local inward = -flat(dir)
		if not opening then
			block(model, "Wall", Vector3.new(outer, WALL_HEIGHT, WALL), frame * CFrame.new(0, WALL_HEIGHT / 2, wallZ), WALL_COLOR, Enum.Material.Cobblestone)
			for _, x in { -S / 4, S / 4 } do
				FloorBuilder.Torch(model, (frame * CFrame.new(x, 9, -S / 2)).Position, inward, true)
			end
			table.insert(plainWalls, frame)
		else
			local segment = (S - DOOR_WIDTH) / 2 + WALL
			for _, sign in { -1, 1 } do
				block(model, "Wall", Vector3.new(segment, WALL_HEIGHT, WALL), frame * CFrame.new(sign * (DOOR_WIDTH / 2 + segment / 2), WALL_HEIGHT / 2, wallZ), WALL_COLOR, Enum.Material.Cobblestone)
			end
			block(model, "Lintel", Vector3.new(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL), frame * CFrame.new(0, DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) / 2, wallZ), WALL_COLOR, Enum.Material.Cobblestone)
			table.insert(built.Doorways, (frame * CFrame.new(0, 0, -S / 2)).Position)
			FloorBuilder.Torch(model, (frame * CFrame.new(DOOR_WIDTH / 2 + 3, 9, -S / 2)).Position, inward, true)

			local doorway = frame * CFrame.new(0, DOOR_HEIGHT / 2, wallZ)
			if opening.SecretHere then
				-- Looks like the rest of the wall, with faint cracks. A lever beside it lowers it.
				local fake = block(model, "SecretWall", Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, WALL), doorway, Color3.fromRGB(68, 72, 69), Enum.Material.Cobblestone)
				for i = 1, 3 do
					attached(fake, "Crack", Vector3.new(0.15, rng:NextNumber(2, 4), 0.1), doorway * CFrame.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), -WALL / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-40, 40))), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
				end
				built.SecretWall = { Part = fake, Closed = doorway, Open = doorway - Vector3.new(0, DOOR_HEIGHT + 1, 0) }

				local leverModel = Instance.new("Model")
				leverModel.Name = "Lever"
				local plate = block(leverModel, "Plate", Vector3.new(1.4, 2, 0.3), frame * CFrame.new(-(DOOR_WIDTH / 2 + 4), 4, -S / 2 + 0.15), IRON, Enum.Material.Metal)
				local handle = block(leverModel, "Handle", Vector3.new(0.3, 1.8, 0.3), plate.CFrame * CFrame.new(0, 0.6, 0.5) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(90, 62, 40), Enum.Material.Wood)
				handle.CanCollide = false
				block(leverModel, "Knob", Vector3.new(0.5, 0.5, 0.5), handle.CFrame * CFrame.new(0, 0.9, 0), IRON, Enum.Material.Metal).Shape = Enum.PartType.Ball
				leverModel.Parent = model
				built.Lever = leverModel
			elseif plan.Type == "Combat" then
				table.insert(built.Gates, buildGate(model, doorway))
			end
		end
	end

	-- Big rooms get pillars in the corners
	if S >= 40 then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = center + Vector3.new(sx * (S / 2 - 3), 0, sz * (S / 2 - 3))
				block(model, "Pillar", Vector3.new(3, WALL_HEIGHT, 3), CFrame.new(p + Vector3.new(0, WALL_HEIGHT / 2, 0)), WALL_COLOR, Enum.Material.Cobblestone)
				block(model, "PillarBase", Vector3.new(4, 1.2, 4), CFrame.new(p + Vector3.new(0, 0.6, 0)), Color3.fromRGB(50, 50, 52), Enum.Material.Slate)
			end
		end
	end

	-- Catacomb clutter along the walls and in the corners: sarcophagi, bones, rubble, puddles
	if (plan.Type == "Combat" and S >= 40) or plan.Type == "Entrance" then
		for i = 1, math.min(2, #plainWalls) do
			local frame = plainWalls[i]
			local cf = frame * CFrame.new(rng:NextNumber(-S / 5, S / 5), 0, -(S / 2 - 2.5))
			block(model, "Sarcophagus", Vector3.new(7, 2.4, 3), cf * CFrame.new(0, 1.2, 0), SARCOPHAGUS, Enum.Material.Limestone)
			block(model, "SarcophagusLid", Vector3.new(7.4, 0.6, 3.4), cf * CFrame.new(0, 2.7, 0), Color3.fromRGB(98, 94, 86), Enum.Material.Limestone)
		end
	end
	local function cornerSpot(): Vector3
		local sx = if rng:NextNumber() < 0.5 then -1 else 1
		local sz = if rng:NextNumber() < 0.5 then -1 else 1
		return center + Vector3.new(sx * rng:NextNumber(S / 2 - 7, S / 2 - 3), 0, sz * rng:NextNumber(S / 2 - 7, S / 2 - 3))
	end
	for _ = 1, rng:NextInteger(1, 3) do
		local spot = cornerSpot()
		for _ = 1, rng:NextInteger(4, 7) do
			local bone = block(model, "Bone", Vector3.new(0.3, 0.3, rng:NextNumber(1, 2)), CFrame.new(spot + Vector3.new(rng:NextNumber(-1.2, 1.2), 0.2, rng:NextNumber(-1.2, 1.2))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), BONE, Enum.Material.Limestone)
			bone.CanCollide = false
		end
		if rng:NextNumber() < 0.5 then
			block(model, "Skull", Vector3.new(0.9, 0.9, 0.9), CFrame.new(spot + Vector3.new(0, 0.45, 0)), BONE, Enum.Material.Limestone).Shape = Enum.PartType.Ball
		end
	end
	for _ = 1, rng:NextInteger(1, 3) do
		local rubble = block(model, "Rubble", Vector3.new(rng:NextNumber(1, 2.5), rng:NextNumber(0.6, 1.4), rng:NextNumber(1, 2.5)), CFrame.new(cornerSpot() + Vector3.new(0, 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), WALL_COLOR, Enum.Material.Slate)
		rubble.CanCollide = false
	end
	if plan.Type ~= "Stairs" and rng:NextNumber() < 0.45 then
		local puddle = block(model, "Puddle", Vector3.new(S * rng:NextNumber(0.3, 0.5), 0.12, S * rng:NextNumber(0.25, 0.4)), CFrame.new(center + Vector3.new(rng:NextNumber(-S / 6, S / 6), 0.06, rng:NextNumber(-S / 6, S / 6))), Color3.fromRGB(32, 52, 56), Enum.Material.Glass)
		puddle.Transparency = 0.3
		puddle.Reflectance = 0.2
		puddle.CanCollide = false
		puddle.CastShadow = false
	end

	model.Parent = floorModel
	return built
end

local function buildCorridor(floorModel: Model, from: Vector3, to: Vector3): BuiltCorridor
	local direction = (to - from).Unit
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local frame = CFrame.lookAt(mid, mid + direction)
	local model = Instance.new("Model")
	model.Name = "Corridor"
	local width = DOOR_WIDTH + WALL * 2
	block(model, "Floor", Vector3.new(width, 2, length), frame * CFrame.new(0, -1, 0), FLOOR_COLOR, Enum.Material.Slate)
	block(model, "Ceiling", Vector3.new(width, 2, length), frame * CFrame.new(0, DOOR_HEIGHT + 1, 0), CEILING_COLOR, Enum.Material.Slate)
	for _, sign in { -1, 1 } do
		block(model, "Wall", Vector3.new(WALL, DOOR_HEIGHT, length), frame * CFrame.new(sign * (DOOR_WIDTH / 2 + WALL / 2), DOOR_HEIGHT / 2, 0), WALL_COLOR, Enum.Material.Cobblestone)
	end
	FloorBuilder.Torch(model, (frame * CFrame.new(DOOR_WIDTH / 2, 8, 0)).Position, -frame.RightVector, false)
	model.Parent = floorModel
	return { Frame = frame, Length = length }
end

-- Builds the whole floor at `origin`. Returns the floor model, the rooms by key, and the corridors.
function FloorBuilder.Build(layout: FloorLayout.Layout, origin: Vector3, rng: Random): (Model, { [string]: BuiltRoom }, { BuiltCorridor })
	local floorModel = Instance.new("Model")
	floorModel.Name = "Floor"

	local function centerOf(plan: FloorLayout.RoomPlan): Vector3
		return origin + Vector3.new(plan.X * PITCH, 0, plan.Z * PITCH)
	end

	local openings: { [string]: { { Dir: Vector2, SecretHere: boolean } } } = {}
	for key in layout.Rooms do
		openings[key] = {}
	end
	for _, link in layout.Links do
		local a, b = layout.Rooms[link.A], layout.Rooms[link.B]
		local dir = Vector2.new(b.X - a.X, b.Z - a.Z)
		table.insert(openings[link.A], { Dir = dir, SecretHere = link.Secret })
		table.insert(openings[link.B], { Dir = -dir, SecretHere = false })
	end

	local rooms: { [string]: BuiltRoom } = {}
	for key, plan in layout.Rooms do
		rooms[key] = buildRoom(floorModel, plan, centerOf(plan), openings[key], rng)
	end

	local corridors = {}
	for _, link in layout.Links do
		local a, b = layout.Rooms[link.A], layout.Rooms[link.B]
		local dir = flat(Vector2.new(b.X - a.X, b.Z - a.Z))
		local from = centerOf(a) + dir * (a.Size / 2 + WALL)
		local to = centerOf(b) - dir * (b.Size / 2 + WALL)
		table.insert(corridors, buildCorridor(floorModel, from, to))
	end

	return floorModel, rooms, corridors
end

return FloorBuilder
