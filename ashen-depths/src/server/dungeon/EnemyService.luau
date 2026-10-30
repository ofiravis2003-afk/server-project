--!strict
-- Spawns enemies, runs their simple AI (chase, wind up, hit), takes their damage and pays out rewards.
--
-- The dungeon floors spawn enemies with EnemyService.Spawn. The test room also spawns one at every
-- part tagged "EnemySpawn" (attribute Enemy = "Skeleton"), and those come back after dying in test mode.
-- Elite enemies are bigger, have golden eyes, hit harder and drop a Bronze Key (see FloorService).
-- An enemy shows its attack coming (red eyes flare + swing) for `Windup` seconds before it lands,
-- so a player who steps away in time takes no damage.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArmorService = require(script.Parent.Parent.Common.ArmorService)
local BlightService = require(script.Parent.Parent.Common.BlightService)
local InventoryService = require(script.Parent.Parent.Common.InventoryService)
local QuestService = require(script.Parent.Parent.Common.QuestService)
local DailyService = require(script.Parent.Parent.Common.DailyService)
local TitleService = require(script.Parent.Parent.Common.TitleService)
local Items = require(ReplicatedStorage.Shared.Items)
local ProgressService = require(script.Parent.Parent.Common.ProgressService)
local Props = require(script.Parent.Props)

local SPAWN_TAG = "EnemySpawn"
local ENEMY_TAG = "Enemy"
local THINK_INTERVAL = 0.15

-- Roblox's own default R15 animations (idle, walk, tool slash), for enemies built from a plain avatar body.
local R15_ANIMATIONS = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Attack = "rbxassetid://522635514",
}

local BONE = Color3.fromRGB(150, 141, 118)
local EYE = Color3.fromRGB(255, 40, 30)
local ELITE_EYE = Color3.fromRGB(255, 190, 40)

local ELITE = { Scale = 1.3, Health = 3.5, Damage = 1.5, Rewards = 3 }

export type SpawnOptions = {
	MinionMultiplier: number?, -- bosses: how tough the monsters they summon are (the floor's usual strength)
	HealthMultiplier: number?,
	DamageMultiplier: number?,
	Elite: boolean?,
	-- A named champion (the Guardians' Skeleton Captain): bigger by ExtraScale, its name over it and in the
	-- big bar at the top of the screen like a boss.
	Title: string?,
	ExtraScale: number?,
	OnDied: ((Enemy) -> ())?,
}

export type Enemy = {
	Name: string,
	Def: Enemies.EnemyDef,
	Damage: number,
	Elite: boolean,
	EyeColor: Color3,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Eyes: { BasePart },
	EyeLight: PointLight,
	Flash: Highlight,
	HealthFill: Frame,
	Tracks: { [string]: AnimationTrack },
	AttackTracks: { { Track: AnimationTrack, HitAt: number } },
	Custom: boolean, -- built from a real 3D model (not the plain avatar body)
	Damagers: { [Player]: number },
	LastAttack: number,
	Attacking: boolean,
	Dead: boolean,
	Boss: BossState?,
	Options: SpawnOptions,
	Burrowed: boolean?, -- (Rot Crawler) under the floor: no blow reaches it
	LastSprout: number?, -- (Mycelid) when it last sprouted mushrooms
	GroundY: number?, -- (Rot Crawler) the root's height when it stands up out of the floor
	FloorY: number?, -- (Rot Crawler) the floor's height, where its circles and dust show
}

export type BossState = {
	Slam: AnimationTrack,
	Kick: AnimationTrack,
	Summon: AnimationTrack,
	NextSlam: number,
	NextKick: number,
	SummonsDone: number,
	Minions: { Enemy },
	Pose: AnimationTrack?, -- the intro clip (else Summon)
	Rage: AnimationTrack?,
	Raged: boolean,
	Pace: number, -- multiplies its cooldowns (lower in its rage)
	SlamMove: any?, -- the move its Slam uses now (its rage lunge replaces the leap)
}

local EnemyService = {}

local enemies: { [Model]: Enemy } = {}
local templates: { [string]: Model } = {}
local folder: Folder
-- A floor's curse (the Ember Altar event in FloorService): every monster that rises after it is tougher, and
-- pays more. Back to normal on the next floor.
local floorModifier = { Health = 1, Damage = 1, Rewards = 1 }
local infect: (Model, number?) -> ()
local sink: (any) -> ()
local PARTY_BONUS = 1.1 -- kills pay 10% more XP and gold when adventuring together
local VIP_BONUS = 1.2 -- and 20% more for a VIP
local damageNumberRemote = Remotes.Event("DamageNumber")
local effectRemote = Remotes.Event("Effect")
local soundRemote = Remotes.Event("Sound")

local function weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function buildSkeleton(): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = BONE
	desc.TorsoColor = BONE
	desc.LeftArmColor = BONE
	desc.RightArmColor = BONE
	desc.LeftLegColor = BONE
	desc.RightLegColor = BONE
	desc.WidthScale = 0.7
	desc.DepthScale = 0.7
	desc.HeadScale = 0.95
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0

	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	for _, child in model:GetDescendants() do
		if child:IsA("Decal") or child:IsA("LuaSourceContainer") or child:IsA("Accessory") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Material = Enum.Material.Limestone
		end
	end

	local head = model:FindFirstChild("Head") :: BasePart
	local eyes = {}
	for _, side in { -1, 1 } do
		local socket = Instance.new("Part")
		socket.Name = "Socket"
		socket.Size = Vector3.new(0.3, 0.24, 0.05)
		socket.Color = Color3.fromRGB(15, 10, 10)
		socket.Material = Enum.Material.SmoothPlastic
		socket.CanCollide = false
		socket.Massless = true
		socket.CFrame = head.CFrame * CFrame.new(side * 0.22, 0.12, -head.Size.Z / 2 + 0.02)
		weld(head, socket)
		socket.Parent = head

		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.14, 0.1, 0.05)
		eye.Color = EYE
		eye.Material = Enum.Material.Neon
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = socket.CFrame * CFrame.new(0, 0, -0.02)
		weld(head, eye)
		eye.Parent = head
		table.insert(eyes, eye)
	end
	local light = Instance.new("PointLight")
	light.Name = "EyeLight"
	light.Color = EYE
	light.Range = 5
	light.Brightness = 0.6
	light.Parent = head

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = true
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.4
	flash.OutlineTransparency = 1
	flash.Enabled = false
	flash.Parent = model

	local bar = Instance.new("BillboardGui")
	bar.Name = "HealthBar"
	bar.Size = UDim2.fromScale(3.2, 0.32)
	bar.StudsOffset = Vector3.new(0, 1.9, 0)
	bar.MaxDistance = 70
	bar.Adornee = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 14, 14)
	back.BorderSizePixel = 0
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 40, 35)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = back
	bar.Parent = head

	model.Name = "Skeleton"
	return model
end

-- Until a real slime model exists: a glossy green blob.
local function slimeBlob(): Model
	local model = Instance.new("Model")
	local blob = Instance.new("Part")
	blob.Name = "Blob"
	blob.Shape = Enum.PartType.Ball
	blob.Size = Vector3.new(4, 4, 4)
	blob.Color = Color3.fromRGB(90, 190, 80)
	blob.Material = Enum.Material.Glass
	blob.Transparency = 0.25
	blob.Parent = model
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "BlobEye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Color = Color3.fromRGB(20, 30, 15)
		eye.CFrame = CFrame.new(side * 0.7, 0.6, -1.75)
		eye.Parent = model
	end
	return model
end

-- Stand-in bodies for chapter II's own monsters, until their Tripo models are in EnemyModels.
local function standIn(parts: { { Shape: Enum.PartType, Size: Vector3, At: CFrame, Color: Color3, Material: Enum.Material, Glow: boolean? } }): Model
	local model = Instance.new("Model")
	for i, spec in parts do
		local p = Instance.new("Part")
		p.Name = `Part{i}`
		p.Shape = spec.Shape
		p.Size = spec.Size
		p.CFrame = spec.At
		p.Color = spec.Color
		p.Material = spec.Material
		p.Parent = model
		if spec.Glow then
			local light = Instance.new("PointLight")
			light.Color = spec.Color
			light.Range = 8
			light.Brightness = 1.2
			light.Parent = p
		end
	end
	return model
end

local TEAL = Color3.fromRGB(60, 200, 170)
local STALK = Color3.fromRGB(196, 186, 160)
local ROT = Color3.fromRGB(70, 58, 44)

local STAND_INS: { [string]: () -> Model } = {
	SporeWisp = function()
		return standIn({
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.6, 2.6), At = CFrame.new(0, 2, 0), Color = TEAL, Material = Enum.Material.Glass, Glow = true },
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.2, 0.2), At = CFrame.new(0.5, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = TEAL, Material = Enum.Material.Neon },
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.2, 0.2), At = CFrame.new(-0.5, 0.8, 0.3) * CFrame.Angles(0, 0, math.rad(90)), Color = TEAL, Material = Enum.Material.Neon },
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.7, 0.2, 0.2), At = CFrame.new(0, 0.75, -0.5) * CFrame.Angles(0, 0, math.rad(90)), Color = TEAL, Material = Enum.Material.Neon },
		})
	end,
	CapSpitter = function()
		return standIn({
			{ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 1.6, 1.6), At = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STALK, Material = Enum.Material.SmoothPlastic },
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(4, 1.8, 4), At = CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(110, 40, 50), Material = Enum.Material.SmoothPlastic },
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 0.6), At = CFrame.new(0, 2.2, -0.7), Color = Color3.fromRGB(30, 12, 12), Material = Enum.Material.SmoothPlastic },
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), At = CFrame.new(0.9, 2.1, 0.2), Color = Color3.fromRGB(120, 255, 140), Material = Enum.Material.Neon, Glow = true },
			{ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), At = CFrame.new(-0.9, 1.7, 0.1), Color = Color3.fromRGB(120, 255, 140), Material = Enum.Material.Neon },
		})
	end,
	RotCrawler = function()
		local segments = {}
		for i = 0, 4 do
			local r = 2.2 - i * 0.25
			table.insert(segments, { Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), At = CFrame.new(0, 1.2 + i * 1.3, 0), Color = ROT, Material = Enum.Material.Slate })
		end
		table.insert(segments, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), At = CFrame.new(0, 6.6, -0.5), Color = Color3.fromRGB(120, 255, 140), Material = Enum.Material.Neon, Glow = true })
		return standIn(segments)
	end,
}

local BUILDERS: { [string]: () -> Model } = {
	Skeleton = buildSkeleton,
	SkeletonArcher = buildSkeleton,
}

-- Turns an imported, rigged 3D model (ServerStorage.EnemyModels.<name>, e.g. from Tripo) into an enemy:
-- an invisible root part the Humanoid walks with, the skinned mesh welded on top, an invisible "Head"
-- for the health bar, and the eye glow on the model's head bone.
local function buildFromModel(source: Model, def: Enemies.EnemyDef): Model
	local model = source:Clone()
	for _, child in model:GetChildren() do
		if child:IsA("AnimationController") or child.Name == "InitialPoses" or child.Name == "AnimSaves" then
			child:Destroy()
		end
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	local height = boxSize.Y

	-- The root part looks where the model's face looks (worked out from the toes, which point forward),
	-- so turning the root to face a player turns the whole body toward them.
	-- (Bone world positions are only right while the model is in the world, so it visits briefly.)
	local forward = Vector3.new(0, 0, -1)
	local foot = model:FindFirstChild("mixamorig:LeftFoot", true) :: Bone?
	local toe = model:FindFirstChild("mixamorig:LeftToeBase", true) :: Bone?
	if foot and toe then
		model.Parent = workspace
		local along = toe.WorldPosition - foot.WorldPosition
		model.Parent = nil
		along = Vector3.new(along.X, 0, along.Z)
		if along.Magnitude > 0.01 then
			forward = along.Unit
		end
	end
	forward = CFrame.Angles(0, math.rad(def.ModelYaw or 0), 0):VectorToWorldSpace(forward)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.lookAt(boxCFrame.Position, boxCFrame.Position + forward)
	root.Parent = model
	model.PrimaryPart = root

	-- Animals moved by code hang their body on a motor (in the root's directions) that players' screens turn.
	local bodyMotor = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			if def.Procedural and not bodyMotor and part:IsA("MeshPart") then
				local relative = root.CFrame:ToObjectSpace(part.CFrame)
				bodyMotor = Instance.new("Motor6D")
				bodyMotor.Name = "BodyMotor"
				bodyMotor.Part0 = root
				bodyMotor.Part1 = part
				bodyMotor.C0 = CFrame.new(relative.Position)
				bodyMotor.C1 = relative.Rotation:Inverse()
				bodyMotor.Parent = root
			else
				weld(root, part)
			end
		end
	end

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Transparency = 1
	head.CanCollide = false
	head.Massless = true
	local headBone = model:FindFirstChild("mixamorig:Head", true) :: Bone?
	head.CFrame = if headBone then CFrame.new(headBone.WorldPosition) else root.CFrame + Vector3.new(0, height / 2 - 0.5, 0)
	weld(root, head)
	head.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "EyeLight"
	light.Color = EYE
	light.Range = 5
	light.Brightness = 0.6
	light.Parent = headBone or head

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = height / 2 - root.Size.Y / 2 - (def.Sink or 0)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = model

	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.4
	flash.OutlineTransparency = 1
	flash.Enabled = false
	flash.Parent = model

	local bar = Instance.new("BillboardGui")
	bar.Name = "HealthBar"
	bar.Size = UDim2.fromScale(3.2, 0.32)
	bar.StudsOffset = Vector3.new(0, 1.6, 0)
	bar.MaxDistance = 70
	bar.Adornee = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 14, 14)
	back.BorderSizePixel = 0
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 40, 35)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = back
	bar.Parent = head

	model:SetAttribute("Custom", true)
	return model
end

-- Puts a dungeon prop (the archer's bow) in a hand: held to the hand bone so it follows the animations.
local function holdProp(model: Model, held: Enemies.HeldProp)
	local bone = model:FindFirstChild(held.Bone, true)
	local props = ServerStorage:FindFirstChild("DungeonProps")
	local source = props and props:FindFirstChild(held.Prop)
	if not bone or not bone:IsA("Bone") or not source or not source:IsA("Model") then
		return
	end
	local prop = source:Clone()
	prop.Name = "Held" .. held.Prop
	if held.Scale then
		prop:ScaleTo(prop:GetScale() * held.Scale)
	end
	local parts = {}
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			table.insert(parts, part)
		end
	end
	local main = parts[1]
	if not main then
		return
	end
	for i = 2, #parts do
		weld(main, parts[i])
	end
	local grip = main:FindFirstChild("Grip") :: Attachment?
	if not grip then
		-- The bone is held at the grip, so the prop sits at bone * offset, turned by the angles.
		local angles = held.GripAngles or { 0, 0, 0 }
		local offset = held.GripOffset or { 0, 0, 0 }
		local made = Instance.new("Attachment")
		made.Name = "Grip"
		made.CFrame = CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
			* CFrame.new(-offset[1], -offset[2], -offset[3])
		made.Parent = main
		grip = made
	end
	local hold = Instance.new("RigidConstraint")
	hold.Attachment0 = bone
	hold.Attachment1 = grip
	hold.Parent = main
	prop.Parent = model
end

-- Chapter II's infected: glowing mushrooms grown onto the body (on its head and back bones when it has a rig,
-- so they move with it), a green glow and a slow drift of spores. The mushrooms are ChapterProps.MushroomCluster
-- (Tripo) once it's there, small caps made of parts until then.
local function mushroom(size: number): Model
	local props = ServerStorage:FindFirstChild("ChapterProps")
	local cluster = props and props:FindFirstChild("MushroomCluster")
	if cluster and cluster:IsA("Model") then
		local copy = cluster:Clone()
		local _, extents = copy:GetBoundingBox()
		copy:ScaleTo(copy:GetScale() * size / math.max(extents.Y, 0.1))
		return copy
	end
	-- (until then: a small pale stalk under a flat dark-teal cap with a few glowing spots; `size` = its height)
	local m = Instance.new("Model")
	local function piece(name: string, shape: Enum.PartType, partSize: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = partSize
		part.CFrame = cf
		part.Color = color
		part.Material = material
		part.Parent = m
		return part
	end
	local stem = piece("Stem", Enum.PartType.Cylinder, Vector3.new(size * 0.7, size * 0.18, size * 0.18), CFrame.new(0, size * 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(205, 198, 175), Enum.Material.SmoothPlastic)
	piece("Cap", Enum.PartType.Ball, Vector3.new(size * 0.75, size * 0.32, size * 0.75), CFrame.new(0, size * 0.75, 0), Color3.fromRGB(28, 84, 74), Enum.Material.SmoothPlastic)
	for i = 1, 3 do
		local angle = i * 2.1
		piece("Spot", Enum.PartType.Ball, Vector3.new(size * 0.12, size * 0.12, size * 0.12), CFrame.new(math.cos(angle) * size * 0.22, size * 0.86, math.sin(angle) * size * 0.22), Color3.fromRGB(120, 255, 190), Enum.Material.Neon)
	end
	m.PrimaryPart = stem
	return m
end

function infect(template: Model, fungusScale: number?)
	local root = template:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local _, extents = template:GetBoundingBox()
	local height = extents.Y
	local spots = {
		{ Bone = "mixamorig:Head", Offset = Vector3.new(0.25, 0.35, 0), Size = 0.32 },
		{ Bone = "mixamorig:Spine2", Offset = Vector3.new(-0.2, 0.2, 0.3), Size = 0.4 },
		{ Bone = "mixamorig:LeftShoulder", Offset = Vector3.new(0, 0.15, 0), Size = 0.25 },
	}
	local placed = false
	for _, spot in spots do
		local bone = template:FindFirstChild(spot.Bone, true)
		if bone and bone:IsA("Bone") then
			placed = true
			local m = mushroom(height * spot.Size * 0.35 * (fungusScale or 1))
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanCollide = false
					p.CanQuery = false
					p.Massless = true
				end
			end
			local base = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
			if base then
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") and p ~= base then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = base
						weld.Part1 = p
						weld.Parent = p
					end
				end
				-- the stalk's foot held on the bone (a little off it, by Offset), so it moves with the body
				m:PivotTo((bone :: Bone).WorldCFrame * CFrame.new(spot.Offset * height * 0.15 * (fungusScale or 1)))
				local a = Instance.new("Attachment")
				a.Parent = base
				a.WorldCFrame = (bone :: Bone).WorldCFrame
				local hold = Instance.new("RigidConstraint")
				hold.Attachment0 = a
				hold.Attachment1 = bone
				hold.Parent = base
			end
			m.Name = "Fungus"
			m.Parent = template
		end
	end
	if not placed then
		-- (no rig: on top of the body, welded to the root)
		for i = 1, 3 do
			local m = mushroom(height * 0.14)
			local angle = i * 2.1
			m:PivotTo(root.CFrame * CFrame.new(math.cos(angle) * extents.X * 0.25, extents.Y * 0.35, math.sin(angle) * extents.Z * 0.25))
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = false
					p.CanCollide = false
					p.CanQuery = false
					p.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = p
					weld.Parent = p
				end
			end
			m.Name = "Fungus"
			m.Parent = template
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(90, 230, 150)
	glow.Range = 8
	glow.Brightness = 0.9
	glow.Parent = root
	local spores = Instance.new("ParticleEmitter")
	spores.Name = "Spores"
	spores.Color = ColorSequence.new(Color3.fromRGB(140, 255, 170), Color3.fromRGB(60, 200, 120))
	spores.LightEmission = 1
	spores.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	spores.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spores.Lifetime = NumberRange.new(1.5, 2.5)
	spores.Speed = NumberRange.new(0.3, 0.8)
	spores.SpreadAngle = Vector2.new(180, 180)
	spores.Acceleration = Vector3.new(0, 0.6, 0)
	spores.Rate = 6
	spores.Parent = root
end

local function getTemplate(name: string): Model
	local template = templates[name]
	if not template then
		local def = Enemies[name]
		local modelsFolder = ServerStorage:FindFirstChild("EnemyModels")
		local source = modelsFolder and modelsFolder:FindFirstChild(def.Model or name)
		if source and source:IsA("Model") then
			template = buildFromModel(source, def)
		elseif BUILDERS[def.Model or name] then
			template = BUILDERS[def.Model or name]()
		elseif STAND_INS[def.Model or name] then
			template = buildFromModel(STAND_INS[def.Model or name](), def)
		else
			template = buildFromModel(slimeBlob(), def)
		end
		-- Props first, so a bigger enemy holds a bigger weapon.
		for _, held in def.HeldProps or {} do
			holdProp(template, held)
		end
		if def.Scale and def.Scale ~= 1 then
			template:ScaleTo(template:GetScale() * def.Scale)
		end
		if def.Infected then
			infect(template, (def :: any).FungusScale)
		end
		template.Name = name
		templates[name] = template
	end
	return template
end

-- An infected blow: its Blight onto the player it hit.
local function spore(humanoid: Humanoid, amount: number?)
	local player = amount and Players:GetPlayerFromCharacter(humanoid.Parent)
	if player then
		BlightService.Add(player, amount :: number)
	end
end

local function setEyes(enemy: Enemy, flaring: boolean)
	for _, eye in enemy.Eyes do
		eye.Color = if flaring then Color3.fromRGB(255, 230, 160) else enemy.EyeColor
		eye.Size = if flaring then Vector3.new(0.18, 0.14, 0.05) else Vector3.new(0.14, 0.1, 0.05)
	end
	enemy.EyeLight.Brightness = if flaring then 1.4 else 0.6
	enemy.EyeLight.Range = if flaring then 6 else 5
end

-- One flying piece of a shattered skeleton: the AI-made "Skull" / "Bone" dungeon props if they exist,
-- otherwise a bone shape built from parts (a shaft with two round knobs at each end).
-- Returns the piece (already in the world) and its main part, for setting its velocity.
local function boneShard(isSkull: boolean, scale: number, cframe: CFrame): (Model, BasePart)
	local folder = ServerStorage:FindFirstChild("DungeonProps")
	local source = folder and folder:FindFirstChild(if isSkull then "Skull" else "Bone")
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
		local size = if isSkull then 1 else math.random(75, 115) / 100
		model:ScaleTo(model:GetScale() * scale * size)
	else
		model = Instance.new("Model")
		local color = Color3.fromRGB(196, 182, 150)
		local function piece(shape: Enum.PartType, size: Vector3, offset: CFrame, pieceColor: Color3?): Part
			local part = Instance.new("Part")
			part.Shape = shape
			part.Size = size * scale
			part.CFrame = cframe * CFrame.new(offset.Position * scale) * offset.Rotation
			part.Color = pieceColor or color
			part.Material = Enum.Material.Limestone
			part.Parent = model
			return part
		end
		if isSkull then
			piece(Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), CFrame.new())
			piece(Enum.PartType.Block, Vector3.new(0.55, 0.3, 0.5), CFrame.new(0, -0.38, -0.12))
			for _, side in { -1, 1 } do
				piece(Enum.PartType.Ball, Vector3.new(0.22, 0.22, 0.22), CFrame.new(side * 0.18, 0.05, -0.37), Color3.fromRGB(25, 20, 18))
			end
		else
			local length = math.random(9, 16) / 10
			piece(Enum.PartType.Cylinder, Vector3.new(length, 0.2, 0.2), CFrame.new())
			for _, x in { -length / 2, length / 2 } do
				for _, y in { -0.08, 0.08 } do
					piece(Enum.PartType.Ball, Vector3.new(0.24, 0.24, 0.24), CFrame.new(x, y, 0))
				end
			end
		end
	end
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanQuery = false
			part.CanTouch = false
			table.insert(parts, part)
		end
	end
	local main = parts[1]
	for i = 2, #parts do
		weld(main, parts[i])
	end
	model.Name = "BoneShard"
	if source then
		model:PivotTo(cframe)
	end
	model.Parent = workspace
	main:SetNetworkOwner(nil)
	return model, main
end

-- A boss's summoned monsters crumble away with it.
local function dismissMinions(enemy: Enemy)
	local boss = enemy.Boss
	if boss then
		for _, minion in boss.Minions do
			if not minion.Dead then
				minion.Humanoid.Health = 0
			end
		end
		boss.Minions = {}
	end
end

local function onDied(enemy: Enemy, options: SpawnOptions, spawnPart: BasePart?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	soundRemote:FireAllClients("EnemyDeath", enemy.Model:GetPivot().Position)
	CollectionService:RemoveTag(enemy.Model, ENEMY_TAG)
	enemies[enemy.Model] = nil
	dismissMinions(enemy)

	for _, eye in enemy.Eyes do
		eye.Material = Enum.Material.SmoothPlastic
		eye.Color = Color3.fromRGB(30, 20, 20)
	end
	enemy.EyeLight.Enabled = false
	local bar = enemy.Model:FindFirstChild("HealthBar", true)
	if bar then
		bar:Destroy()
	end
	if enemy.Custom then
		-- Start the death clip, then (skeletons) burst into dust and leave a pile of bones,
		-- or hold the clip's last frame and fade. With no death clip, topple over.
		for _, track in enemy.Tracks do
			if track ~= enemy.Tracks.Death then
				track:Stop(0.1)
			end
		end
		for _, clip in enemy.AttackTracks do
			clip.Track:Stop(0.1)
		end
		enemy.Root.Anchored = true
		for _, gui in enemy.Model:GetDescendants() do
			if gui:IsA("BillboardGui") then
				gui.Enabled = false
			end
		end
		local crumble = enemy.Def.CrumbleInto
		local death = enemy.Tracks.Death
		local speed = (enemy.Def.AnimationSpeeds or {}).Death or 1
		if enemy.Def.DeathStyle == "Flip" then
			-- Rolls onto its back, then fades.
			local onBack = enemy.Root.CFrame * CFrame.new(0, -enemy.Humanoid.HipHeight * 0.4, 0) * CFrame.Angles(0, 0, math.pi)
			TweenService:Create(enemy.Root, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = onBack }):Play()
			task.delay(1.4, function()
				for _, part in enemy.Model:GetDescendants() do
					if part:IsA("BasePart") and part ~= enemy.Root and part.Name ~= "Head" then
						TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
					end
				end
			end)
		elseif enemy.Def.DeathStyle == "Splat" then
			local burst = enemy.Def.BurstSpores
			if burst then
				-- a cloud of spores where it burst: Blight and a sting for everyone close
				local at = enemy.Root.Position
				effectRemote:FireAllClients("Quake", at, burst.Radius)
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if root and humanoid and humanoid.Health > 0 and (root.Position - at).Magnitude <= burst.Radius then
						local dealt = ArmorService.Hurt(humanoid, enemy.Damage * burst.DamageScale)
						damageNumberRemote:FireAllClients(root.Position + Vector3.new(0, 2.5, 0), dealt, "Hurt")
						BlightService.Add(player, burst.Blight)
					end
				end
			end
			-- Bursts into goo: a splash of green drops, and the body is gone.
			local splash = Instance.new("Part")
			splash.Anchored = true
			splash.CanCollide = false
			splash.CanQuery = false
			splash.Transparency = 1
			splash.Size = Vector3.new(1, 1, 1)
			splash.CFrame = enemy.Root.CFrame
			local goo = Instance.new("ParticleEmitter")
			goo.Color = ColorSequence.new(Color3.fromRGB(110, 210, 90))
			goo.LightEmission = 0.3
			goo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
			goo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			goo.Lifetime = NumberRange.new(0.5, 0.9)
			goo.Speed = NumberRange.new(10, 18)
			goo.SpreadAngle = Vector2.new(180, 180)
			goo.Acceleration = Vector3.new(0, -40, 0)
			goo.Rate = 160
			goo.Parent = splash
			splash.Parent = workspace
			task.delay(0.2, function()
				goo.Enabled = false
			end)
			task.delay(1.5, function()
				splash:Destroy()
			end)
			for _, part in enemy.Model:GetDescendants() do
				if part:IsA("BasePart") and part ~= enemy.Root and part.Name ~= "Head" then
					TweenService:Create(part, TweenInfo.new(0.15), { Transparency = 1 }):Play()
				end
			end
		elseif crumble and crumble.AfterDeathClip and death then
			death:Play(0.1, 1, speed)
		elseif crumble then
			local hit = enemy.Tracks.Hit
			if hit then
				hit:Play(0.05, 1, 1.4)
			end
		elseif death then
			death:Play(0.1, 1, speed)
		else
			local fallen = enemy.Root.CFrame * CFrame.new(0, -enemy.Humanoid.HipHeight, 0) * CFrame.Angles(math.rad(-85), 0, 0)
			TweenService:Create(enemy.Root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = fallen }):Play()
		end
		if crumble then
			task.delay(crumble.At, function()
				if not enemy.Model.Parent then
					return
				end
				local scale = enemy.Model:GetScale() / getTemplate(enemy.Name):GetScale()
				local ground = enemy.Root.Position - Vector3.new(0, enemy.Humanoid.HipHeight + enemy.Root.Size.Y / 2, 0)
				local chestHeight = enemy.Humanoid.HipHeight + 1
				if crumble.AfterDeathClip then
					-- The death clip has laid the body on its back away from the root: shatter there, low down.
					local fall = CFrame.Angles(0, math.rad(crumble.FallAngle or 180), 0):VectorToWorldSpace(enemy.Root.CFrame.LookVector)
					ground += fall * (crumble.FallBack or 0) * scale
					chestHeight = 1
				end
				-- A puff of grey bone dust
				local puff = Instance.new("Part")
				puff.Anchored = true
				puff.CanCollide = false
				puff.CanQuery = false
				puff.Transparency = 1
				puff.Size = Vector3.new(1, 1, 1)
				puff.CFrame = CFrame.new(ground + Vector3.new(0, 1.5, 0))
				local dust = Instance.new("ParticleEmitter")
				dust.Color = ColorSequence.new(Color3.fromRGB(205, 195, 175))
				dust.LightEmission = 0.25
				dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * scale), NumberSequenceKeypoint.new(1, 4 * scale) })
				dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
				dust.Lifetime = NumberRange.new(0.8, 1.4)
				dust.Speed = NumberRange.new(3, 7)
				dust.SpreadAngle = Vector2.new(180, 180)
				dust.Drag = 4
				-- Emit() on the server doesn't reach players' screens, so the emitter runs for a moment instead.
				dust.Rate = 140
				dust.Parent = puff
				puff.Parent = workspace
				task.delay(0.25, function()
					dust.Enabled = false
				end)
				task.delay(2, function()
					puff:Destroy()
				end)
				-- What it held clatters to the floor...
				for _, child in enemy.Model:GetChildren() do
					if child:IsA("Model") and child.Name:sub(1, 4) == "Held" then
						child.Parent = workspace
						for _, part in child:GetDescendants() do
							if part:IsA("RigidConstraint") then
								part:Destroy()
							elseif part:IsA("BasePart") then
								part.Massless = false
								part.CanCollide = true
								part.AssemblyLinearVelocity = Vector3.new(math.random(-6, 6), math.random(4, 9), math.random(-6, 6))
								part.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
							end
						end
						task.delay(5, function()
							for _, part in child:GetDescendants() do
								if part:IsA("BasePart") then
									TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
								end
							end
							task.wait(1.3)
							child:Destroy()
						end)
					end
				end
				-- ...and the body vanishes at once...
				for _, part in enemy.Model:GetDescendants() do
					if part:IsA("BasePart") and part ~= enemy.Root and part.Name ~= "Head" then
						part.Transparency = 1
					end
				end
				-- ...and its bones fly out, bounce and roll across the floor.
				local chest = ground + Vector3.new(0, chestHeight, 0)
				local shards: { Model } = {}
				for i = 1, 11 do
					local cf = CFrame.new(chest + Vector3.new(math.random() - 0.5, (math.random() - 0.3) * 2, math.random() - 0.5))
						* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
					local shard, main = boneShard(i == 1, scale, cf)
					local angle = math.random() * math.pi * 2
					main.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * math.random(8, 16), math.random(12, 22), math.sin(angle) * math.random(8, 16))
					main.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
					table.insert(shards, shard)
				end
				task.delay(4, function()
					for _, shard in shards do
						for _, part in shard:GetDescendants() do
							if part:IsA("BasePart") then
								TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
							end
						end
					end
					task.wait(1.3)
					for _, shard in shards do
						shard:Destroy()
					end
				end)
				enemy.EyeLight.Enabled = false
				local pile = Props.Place(crumble.Prop, workspace, CFrame.new(ground) * CFrame.Angles(0, math.random() * math.pi * 2, 0), scale * 0.6)
				if pile then
					-- Just scenery: players walk straight through it.
					for _, part in pile:GetDescendants() do
						if part:IsA("BasePart") then
							part.CanCollide = false
							part.CanQuery = false
							part.CanTouch = false
						end
					end
					task.delay(6, function()
						for _, part in pile:GetDescendants() do
							if part:IsA("BasePart") then
								TweenService:Create(part, TweenInfo.new(1.5), { Transparency = 1 }):Play()
							end
						end
						task.wait(1.6)
						pile:Destroy()
					end)
				end
			end)
		elseif death then
			local duration = (if death.Length > 0 then death.Length else 5) / speed
			task.delay(math.max(duration - 0.1, 0), function()
				if death.IsPlaying then
					death:AdjustSpeed(0)
				end
			end)
			task.delay(duration + 0.6, function()
				for _, part in enemy.Model:GetDescendants() do
					if part:IsA("BasePart") and part ~= enemy.Root and part.Name ~= "Head" then
						TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
					end
				end
			end)
		end
	else
		-- The bones fall apart and scatter on the floor.
		for _, part in enemy.Model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.CanCollide = true
			end
		end
	end

	local position = enemy.Root.Position
	local rewards = (if enemy.Elite then ELITE.Rewards else 1) * floorModifier.Rewards
	-- a party (more than one adventurer down here) earns PARTY_BONUS more from every kill
	local together = if #Players:GetPlayers() > 1 then PARTY_BONUS else 1
	for player, dealt in enemy.Damagers do
		if player.Parent and dealt > 0 then
			local vip = if player:GetAttribute("VIP") then VIP_BONUS else 1 -- (the VIP pass, MonetizationService)
			local xp = math.ceil(enemy.Def.XP * rewards * together * vip)
			local gold = math.ceil(math.random(enemy.Def.Gold[1], enemy.Def.Gold[2]) * rewards * together * vip)
			ProgressService.AddXP(player, xp)
			ProgressService.AddGold(player, gold)
			local text = `+{xp} XP   +{gold} Gold`
			QuestService.OnKill(player, enemy.Name)
			DailyService.OnKill(player, enemy.Name)
			TitleService.OnKill(player, enemy.Name)
			-- Each player gets their own share of what it leaves behind.
			for _, drop in enemy.Def.Drops or {} do
				if enemy.Elite or math.random() < drop.Chance then
					local count = if drop.Count then math.random(drop.Count[1], drop.Count[2]) else 1
					if enemy.Elite then
						count *= 2
					end
					local got = InventoryService.GiveItem(player, drop.Item, "Common", count)
					if got > 0 then
						text ..= `\n+{got} {Items.Defs[drop.Item].DisplayName}`
					end
				end
			end
			damageNumberRemote:FireClient(player, position + Vector3.new(0, 3, 0), text, "Reward")
		end
	end
	if options.OnDied then
		task.spawn(options.OnDied, enemy)
	end

	task.delay(if enemy.Custom then 5.5 else 4, function()
		enemy.Model:Destroy()
	end)
	if Config.TestMode and spawnPart and spawnPart.Parent then
		task.delay(enemy.Def.RespawnTime, function()
			if spawnPart.Parent then
				EnemyService.Spawn(enemy.Name, spawnPart.CFrame, options, spawnPart)
			end
		end)
	end
end

-- Spawns an enemy standing at `cframe` and returns it (nil if the name is unknown).
-- The first spawn of each kind builds its model, so it can take a moment.
function EnemyService.SetFloorModifier(health: number, damage: number, rewards: number)
	floorModifier = { Health = health, Damage = damage, Rewards = rewards }
end

function EnemyService.Spawn(name: string, cframe: CFrame, options: SpawnOptions?, spawnPart: BasePart?): Enemy?
	local def = Enemies[name]
	if not def then
		warn(`[EnemyService] Unknown enemy "{name}"`)
		return nil
	end
	local opts: SpawnOptions = options or {}
	local elite = opts.Elite == true
	local model = getTemplate(name):Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local health = def.Health * (opts.HealthMultiplier or 1) * (if elite then ELITE.Health else 1) * floorModifier.Health
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = def.WalkSpeed

	local eyeColor = if elite then ELITE_EYE else EYE
	local eyes = {}
	for _, child in head:GetChildren() do
		if child.Name == "Eye" then
			(child :: BasePart).Color = eyeColor
			table.insert(eyes, child :: BasePart)
		end
	end
	local eyeLight = model:FindFirstChild("EyeLight", true) :: PointLight
	eyeLight.Color = eyeColor
	if elite then
		model.Name = `Elite {def.DisplayName}`
		if def.EliteHeldProps then
			for _, child in model:GetChildren() do
				if child:IsA("Model") and child.Name:sub(1, 4) == "Held" then
					child:Destroy()
				end
			end
			for _, held in def.EliteHeldProps do
				holdProp(model, held)
			end
		end
		model:ScaleTo(model:GetScale() * ELITE.Scale) -- relative: imported models are already scaled up
		local aura = Instance.new("PointLight")
		aura.Color = ELITE_EYE
		aura.Range = 9
		aura.Brightness = 0.8
		aura.Parent = root
		local tag = Instance.new("BillboardGui")
		tag.Name = "EliteTag"
		tag.Size = UDim2.fromOffset(160, 22)
		tag.StudsOffset = Vector3.new(0, 2.8, 0)
		tag.MaxDistance = 70
		tag.Adornee = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Fondamento
		text.TextSize = 18
		text.TextColor3 = ELITE_EYE
		text.TextStrokeTransparency = 0.3
		text.Text = `Elite {def.DisplayName}`
		text.Parent = tag
		tag.Parent = head
	end

	if opts.ExtraScale and opts.ExtraScale ~= 1 then
		model:ScaleTo(model:GetScale() * opts.ExtraScale)
	end
	if opts.Title then
		model.Name = opts.Title
		model:SetAttribute("BossTitle", opts.Title)
		CollectionService:AddTag(model, "Boss")
		local bar = head:FindFirstChild("HealthBar") :: BillboardGui?
		if bar then
			bar.Enabled = false
		end
		local tag = head:FindFirstChild("EliteTag")
		local text = tag and tag:FindFirstChildOfClass("TextLabel")
		if text then
			text.Text = opts.Title
		end
	end

	model:PivotTo(cframe + Vector3.new(0, 3, 0))
	if def.Boss then
		-- every player gets the boss at once, wherever they stand (its entrance scene needs it on every screen)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	model.Parent = folder
	root:SetNetworkOwner(nil)

	local custom = model:GetAttribute("Custom") == true
	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	local tracks: { [string]: AnimationTrack } = {}
	for key, id in (if custom then def.Animations or {} else R15_ANIMATIONS) :: { [string]: string } do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		tracks[key] = animator:LoadAnimation(animation)
	end
	if tracks.Idle then
		-- Clips published from Studio come in at Action priority; left there, the idle would override
		-- the walk and the body would glide with its legs still.
		tracks.Idle.Looped = true
		tracks.Idle.Priority = Enum.AnimationPriority.Idle
		tracks.Idle:Play()
	end
	if tracks.Walk then
		tracks.Walk.Looped = true
		tracks.Walk.Priority = Enum.AnimationPriority.Movement
	end
	for _, key in { "Attack", "Hit", "Death" } do
		if tracks[key] then
			tracks[key].Looped = false
			tracks[key].Priority = Enum.AnimationPriority.Action
		end
	end
	local attackTracks = {}
	if custom then
		for _, clip in (if elite and def.EliteAttackClips then def.EliteAttackClips else def.AttackClips) or {} do
			local animation = Instance.new("Animation")
			animation.AnimationId = clip.Id
			local track = animator:LoadAnimation(animation)
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
			table.insert(attackTracks, { Track = track, HitAt = clip.HitAt })
		end
	end

	local barGui = head:FindFirstChild("HealthBar") :: BillboardGui
	local bossState: BossState? = nil
	if def.Boss then
		-- A boss's health is the big bar at the top of the screen, not a little one over its head.
		barGui.Enabled = false
		local function load(id: string): AnimationTrack
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
			return track
		end
		bossState = {
			Slam = load(def.Boss.Slam.Id),
			Kick = load(def.Boss.Kick.Id),
			Summon = load(def.Boss.Summon.Id),
			NextSlam = os.clock() + 5,
			NextKick = 0,
			SummonsDone = 0,
			Minions = {},
			Pose = if def.Boss.Intro.Pose then load(def.Boss.Intro.Pose) else nil,
			Rage = if def.Boss.Rage then load(def.Boss.Rage.Id) else nil,
			Raged = false,
			Pace = 1,
		}
		model:SetAttribute("BossTitle", def.Boss.Title)
		CollectionService:AddTag(model, "Boss")
	end
	local enemy: Enemy = {
		Name = name,
		Def = def,
		Damage = def.Damage * (opts.DamageMultiplier or 1) * (if elite then ELITE.Damage else 1) * floorModifier.Damage,
		Elite = elite,
		EyeColor = eyeColor,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Eyes = eyes,
		EyeLight = eyeLight,
		Flash = model:FindFirstChild("HitFlash") :: Highlight,
		HealthFill = (barGui:FindFirstChildOfClass("Frame") :: Frame):FindFirstChild("Fill") :: Frame,
		Tracks = tracks,
		AttackTracks = attackTracks,
		Custom = custom,
		Damagers = {},
		LastAttack = 0,
		Attacking = false,
		Dead = false,
		Boss = bossState,
		Options = opts,
	}
	if def.Hover then
		humanoid.HipHeight += def.Hover
	end
	if def.Rooted or def.Burrow then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	if def.Burrow then
		-- up out of the floor it stands like anything else (its whole body above the floor)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { folder, model }
		local hit = workspace:Raycast(cframe.Position + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), params)
		local floorY = if hit then hit.Position.Y else cframe.Position.Y - 2.5
		enemy.FloorY = floorY
		enemy.GroundY = floorY + humanoid.HipHeight + root.Size.Y / 2
		task.defer(sink, enemy)
	end
	enemies[model] = enemy
	CollectionService:AddTag(model, ENEMY_TAG)
	if def.Squishy then
		CollectionService:AddTag(model, "Squishy")
	end
	if def.Procedural == "Scurry" then
		CollectionService:AddTag(model, "Scurry")
	end

	humanoid.Running:Connect(function(speed)
		local walk = tracks.Walk
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.1, 1, (def.AnimationSpeeds or {}).Walk or 1)
			end
		elseif walk.IsPlaying then
			walk:Stop()
		end
	end)
	humanoid.HealthChanged:Connect(function(health)
		enemy.HealthFill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
	humanoid.Died:Connect(function()
		onDied(enemy, opts, spawnPart)
	end)
	return enemy
end

-- Takes an enemy away without rewards (a room reset after everyone in it died).
function EnemyService.Remove(enemy: Enemy)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemies[enemy.Model] = nil
	CollectionService:RemoveTag(enemy.Model, ENEMY_TAG)
	if enemy.Boss then
		for _, minion in enemy.Boss.Minions do
			EnemyService.Remove(minion)
		end
		enemy.Boss.Minions = {}
	end
	enemy.Model:Destroy()
end

local function nearestTarget(position: Vector3, range: number): (BasePart?, Humanoid?)
	local best, bestHumanoid, bestDistance = nil, nil, range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestHumanoid, bestDistance = root, humanoid, distance
			end
		end
	end
	return best, bestHumanoid
end

local function face(enemy: Enemy, point: Vector3)
	local from = enemy.Root.Position
	local flat = Vector3.new(point.X, from.Y, point.Z)
	if (flat - from).Magnitude > 0.1 then
		enemy.Root.CFrame = CFrame.lookAt(from, flat)
	end
end

-- Pace of a blow from an AttackClips set: the last STRIKE_CLIP_SECONDS of the clip before the hit play
-- STRIKE_SPEED times as fast, so the blade snaps down; the raise before it never drops below MIN_RAISE_SPEED.
local STRIKE_CLIP_SECONDS = 0.3
local STRIKE_SPEED = 1.7
local MIN_RAISE_SPEED = 0.8
local RECOVER_SPEED = 1.3

local function attack(enemy: Enemy, targetRoot: BasePart, targetHumanoid: Humanoid)
	enemy.Attacking = true
	enemy.LastAttack = os.clock()
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	face(enemy, targetRoot.Position)
	setEyes(enemy, true)
	if #enemy.AttackTracks > 0 then
		-- A random blow from its set, timed so the weapon lands as the Windup ends: the raise plays at an
		-- ordinary pace (starting a little late if the clip is short), the downswing snaps, the recovery is brisk.
		-- Only the clip's pace changes; when the hit lands and how often it attacks stay the same.
		local clip = enemy.AttackTracks[math.random(#enemy.AttackTracks)]
		local windup = enemy.Def.Windup
		local swing = math.min(STRIKE_CLIP_SECONDS, clip.HitAt * 0.6)
		local swingTime = swing / STRIKE_SPEED
		local raiseSpeed = math.max(MIN_RAISE_SPEED, (clip.HitAt - swing) / (windup - swingTime))
		local startAfter = windup - swingTime - (clip.HitAt - swing) / raiseSpeed
		local track = clip.Track
		task.delay(startAfter, function()
			if enemy.Dead then
				return
			end
			track:Play(0.1, 1, raiseSpeed)
			task.delay(windup - startAfter - swingTime, function()
				if track.IsPlaying then
					track:AdjustSpeed(STRIKE_SPEED)
				end
			end)
			task.delay(windup - startAfter, function()
				if track.IsPlaying then
					track:AdjustSpeed(RECOVER_SPEED)
				end
			end)
		end)
	elseif enemy.Tracks.Attack then
		local speeds = enemy.Def.AnimationSpeeds or {}
		enemy.Tracks.Attack:Play(0.1, 1, if enemy.Custom then speeds.Attack or 1 else 0.8)
	end
	if enemy.Def.Procedural then
		enemy.Model:SetAttribute("LungeCount", (enemy.Model:GetAttribute("LungeCount") or 0) + 1)
	end

	task.wait(enemy.Def.Windup)
	if not enemy.Dead then
		setEyes(enemy, false)
		local offset = targetRoot.Position - enemy.Root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local inFront = flat.Magnitude < 1 or enemy.Root.CFrame.LookVector:Dot(flat.Unit) > 0.2
		if targetHumanoid.Health > 0 and flat.Magnitude <= enemy.Def.AttackRange + 1.5 and inFront then
			local damage = ArmorService.Hurt(targetHumanoid, enemy.Damage)
			damageNumberRemote:FireAllClients(targetRoot.Position + Vector3.new(0, 2.5, 0), damage, "Hurt")
			spore(targetHumanoid, enemy.Def.Blight)
		end
	end
	enemy.Attacking = false
end

-- Archers: show a red aiming line, then loose an arrow at where the target stands at that moment.
-- Whoever is still within HitRadius of that spot when the arrow arrives is hit.
local function shoot(enemy: Enemy, targetRoot: BasePart)
	local ranged = enemy.Def.Ranged :: { KeepAway: number, ProjectileSpeed: number, HitRadius: number, Shot: string? }
	enemy.Attacking = true
	enemy.LastAttack = os.clock()
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	face(enemy, targetRoot.Position)
	setEyes(enemy, true)
	if enemy.Tracks.Attack then
		local speeds = enemy.Def.AnimationSpeeds or {}
		enemy.Tracks.Attack:Play(0.1, 1, speeds.Attack or 1)
	end
	local from = enemy.Root.Position + Vector3.new(0, 1.2, 0) + enemy.Root.CFrame.LookVector * 1.5
	effectRemote:FireAllClients("AimLine", from, targetRoot.Position, enemy.Def.Windup)

	task.wait(enemy.Def.Windup)
	if not enemy.Dead then
		setEyes(enemy, false)
		face(enemy, targetRoot.Position)
		from = enemy.Root.Position + Vector3.new(0, 1.2, 0) + enemy.Root.CFrame.LookVector * 1.5
		local aim = targetRoot.Position
		local travel = (aim - from).Magnitude / ranged.ProjectileSpeed
		effectRemote:FireAllClients(ranged.Shot or "Arrow", from, aim, travel)
		local damage = enemy.Damage
		task.delay(travel, function()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and (root.Position - aim).Magnitude <= ranged.HitRadius then
					local dealt = ArmorService.Hurt(humanoid, damage)
					damageNumberRemote:FireAllClients(root.Position + Vector3.new(0, 2.5, 0), dealt, "Hurt")
					spore(humanoid, enemy.Def.Blight)
				end
			end
		end)
	end
	enemy.Attacking = false
end

------------------------------------------------------------------------------------------------
-- Bosses

-- Living players whose root stands within `radius` (flat) of `center`.
local function playersNear(center: Vector3, radius: number): { { Player: Player, Root: BasePart, Humanoid: Humanoid } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local offset = root.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius then
				table.insert(list, { Player = player, Root = root, Humanoid = humanoid })
			end
		end
	end
	return list
end

local function hurt(humanoid: Humanoid, root: BasePart, amount: number)
	local damage = ArmorService.Hurt(humanoid, amount)
	damageNumberRemote:FireAllClients(root.Position + Vector3.new(0, 2.5, 0), damage, "Hurt")
end

-- The Mycelid's sprouts: little mushrooms pushing up round a player, red circles under them, then a burst of
-- spores. Walking out of the circles in time dodges them.
local function sprout(enemy: Enemy, targetRoot: BasePart)
	local s = enemy.Def.Sprouts :: { Count: number, Range: number, Radius: number, Delay: number, DamageScale: number, Blight: number, Cooldown: number }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, targetRoot.Parent :: Instance }
	local rng = Random.new()
	local spots = {}
	for i = 1, s.Count do
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		local hit = workspace:Raycast(targetRoot.Position + offset + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
		if hit then
			table.insert(spots, hit.Position)
		end
	end
	local grown = {}
	for _, spot in spots do
		effectRemote:FireAllClients("Telegraph", spot, s.Radius, s.Delay)
		effectRemote:FireAllClients("Rise", spot)
		local mushrooms = Props.Place("MushroomCluster", workspace, CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 0.3)
		if mushrooms then
			for _, p in mushrooms:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
				end
			end
			-- pushing up out of the floor
			local final = mushrooms:GetPivot()
			mushrooms:PivotTo(final - Vector3.new(0, 1.5, 0))
			task.spawn(function()
				local t = 0
				while t < 0.6 and mushrooms.Parent do
					t += task.wait()
					mushrooms:PivotTo(final - Vector3.new(0, 1.5 * (1 - math.min(t / 0.6, 1)), 0))
				end
			end)
			table.insert(grown, mushrooms)
		end
	end
	task.wait(s.Delay)
	for _, spot in spots do
		effectRemote:FireAllClients("Quake", spot, s.Radius)
		for _, entry in playersNear(spot, s.Radius) do
			hurt(entry.Humanoid, entry.Root, enemy.Damage * s.DamageScale)
			spore(entry.Humanoid, s.Blight)
		end
	end
	for _, mushrooms in grown do
		mushrooms:Destroy()
	end
end

-- The Rot Crawler: under the floor, then up through it beneath a player.

local BURROW_DEPTH = 9

-- Moves the whole body to `y` (the root's height) over `seconds`.
local function riseTo(enemy: Enemy, y: number, seconds: number)
	local start = enemy.Root.Position.Y
	local t = 0
	while t < seconds and not enemy.Dead do
		t += task.wait()
		local pos = enemy.Root.Position
		local at = start + (y - start) * math.min(t / seconds, 1)
		enemy.Model:PivotTo(enemy.Root.CFrame.Rotation + Vector3.new(pos.X, at, pos.Z))
	end
end

function sink(enemy: Enemy)
	enemy.Root.Anchored = true
	enemy.Burrowed = true
	local bar = enemy.Model:FindFirstChild("HealthBar", true)
	if bar and bar:IsA("BillboardGui") then
		bar.Enabled = false
	end
	effectRemote:FireAllClients("Rise", Vector3.new(enemy.Root.Position.X, enemy.FloorY or enemy.Root.Position.Y, enemy.Root.Position.Z))
	riseTo(enemy, (enemy.GroundY or enemy.Root.Position.Y) - BURROW_DEPTH, 0.5)
end

local function burrowStrike(enemy: Enemy, targetRoot: BasePart)
	local burrow = enemy.Def.Burrow :: { Radius: number, Surface: number }
	enemy.Attacking = true
	enemy.LastAttack = os.clock()
	local ground = enemy.GroundY or 0
	local spot = Vector3.new(targetRoot.Position.X, enemy.FloorY or ground, targetRoot.Position.Z)
	-- under the floor it slides beneath the player; the floor shows a red circle (and dust) where it will come up
	enemy.Model:PivotTo(enemy.Root.CFrame.Rotation + Vector3.new(spot.X, ground - BURROW_DEPTH, spot.Z))
	effectRemote:FireAllClients("Telegraph", spot, burrow.Radius, enemy.Def.Windup)
	effectRemote:FireAllClients("Rise", spot)
	task.wait(enemy.Def.Windup)
	if enemy.Dead then
		return
	end
	effectRemote:FireAllClients("Quake", spot, burrow.Radius)
	riseTo(enemy, ground, 0.18)
	enemy.Burrowed = false
	local bar = enemy.Model:FindFirstChild("HealthBar", true)
	if bar and bar:IsA("BillboardGui") then
		bar.Enabled = true
	end
	for _, entry in playersNear(spot, burrow.Radius) do
		hurt(entry.Humanoid, entry.Root, enemy.Damage)
		spore(entry.Humanoid, enemy.Def.Blight)
	end
	-- up for a while: the time to hit it
	task.wait(burrow.Surface)
	if not enemy.Dead then
		sink(enemy)
		enemy.LastAttack = os.clock()
	end
	enemy.Attacking = false
end

-- Leaps at a player: a red circle marks where it will land; everyone still inside when it lands is hit.
local function bossSlam(enemy: Enemy, targetRoot: BasePart)
	local boss = enemy.Boss :: BossState
	local move = boss.SlamMove or (enemy.Def.Boss :: Enemies.BossDef).Slam
	enemy.Attacking = true
	boss.NextSlam = os.clock() + move.Cooldown * boss.Pace
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	face(enemy, targetRoot.Position)
	local start = enemy.Root.CFrame
	local floorY = start.Position.Y - enemy.Humanoid.HipHeight - enemy.Root.Size.Y / 2
	local landing = Vector3.new(targetRoot.Position.X, floorY, targetRoot.Position.Z)
	effectRemote:FireAllClients("Telegraph", landing, move.Radius, move.HitAt)
	setEyes(enemy, true)
	boss.Slam:Play(0.1)
	-- The body travels to just short of the circle's middle while it is in the air.
	local toward = Vector3.new(landing.X - start.Position.X, 0, landing.Z - start.Position.Z)
	local travel = math.max(toward.Magnitude - move.Radius * 0.35, 0)
	local finish = if toward.Magnitude > 0.1 then start + toward.Unit * travel else start
	enemy.Root.Anchored = true
	task.wait(move.HitAt * 0.35)
	if not enemy.Dead then
		TweenService:Create(enemy.Root, TweenInfo.new(move.HitAt * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = finish }):Play()
	end
	task.wait(move.HitAt * 0.65)
	if not enemy.Dead then
		setEyes(enemy, false)
		effectRemote:FireAllClients("Quake", landing, move.Radius)
		for _, hit in playersNear(landing, move.Radius) do
			hurt(hit.Humanoid, hit.Root, enemy.Damage * move.DamageScale)
		end
	end
	task.wait(0.6)
	enemy.Root.Anchored = false
	enemy.Attacking = false
end

-- Shoves away whoever crowds it.
local function bossKick(enemy: Enemy, targetRoot: BasePart)
	local boss = enemy.Boss :: BossState
	local move = (enemy.Def.Boss :: Enemies.BossDef).Kick
	enemy.Attacking = true
	boss.NextKick = os.clock() + move.Cooldown * boss.Pace
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	face(enemy, targetRoot.Position)
	boss.Kick:Play(0.1)
	task.wait(move.HitAt)
	if not enemy.Dead then
		local look = enemy.Root.CFrame.LookVector
		for _, hit in playersNear(enemy.Root.Position, move.Range + 1.5) do
			local offset = hit.Root.Position - enemy.Root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local away = if flat.Magnitude > 0.1 then flat.Unit else look
			if look:Dot(away) > 0 then
				hurt(hit.Humanoid, hit.Root, enemy.Damage * move.DamageScale)
				-- The player's own screen moves their character, so it gets the push.
				effectRemote:FireClient(hit.Player, "Knockback", away * move.Push + Vector3.new(0, move.Push * 0.45, 0))
			end
		end
	end
	task.wait(0.5)
	enemy.Attacking = false
end

-- Calls skeletons up out of the floor around it.
local function bossSummon(enemy: Enemy)
	local boss = enemy.Boss :: BossState
	local move = (enemy.Def.Boss :: Enemies.BossDef).Summon
	enemy.Attacking = true
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	boss.Summon:Play(0.15)
	effectRemote:FireAllClients("Summon", enemy.Root.Position)
	task.wait(move.RiseAt)
	if not enemy.Dead then
		local floorY = enemy.Root.Position.Y - enemy.Humanoid.HipHeight - enemy.Root.Size.Y / 2
		local strength = enemy.Options.MinionMultiplier or 1
		for i = 1, move.Count do
			local angle = (i / move.Count) * math.pi * 2 + math.random() * 0.5
			local spot = Vector3.new(enemy.Root.Position.X + math.cos(angle) * 9, floorY, enemy.Root.Position.Z + math.sin(angle) * 9)
			effectRemote:FireAllClients("Rise", spot)
			local ok, minion = pcall(EnemyService.Spawn, move.Minion, CFrame.lookAt(spot, Vector3.new(enemy.Root.Position.X, floorY, enemy.Root.Position.Z)), {
				HealthMultiplier = strength,
				DamageMultiplier = strength,
			})
			if ok and minion then
				table.insert(boss.Minions, minion)
			end
		end
	end
	-- arrows rain round every player in the lair: red circles first, then they strike
	local rain = move.Rain
	if rain and not enemy.Dead then
		local floorY = enemy.Root.Position.Y - enemy.Humanoid.HipHeight - enemy.Root.Size.Y / 2
		for _, target in playersNear(enemy.Root.Position, 90) do
			for _ = 1, rain.Count do
				local offset = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 10
				local spot = Vector3.new(target.Root.Position.X + offset.X, floorY, target.Root.Position.Z + offset.Z)
				effectRemote:FireAllClients("Telegraph", spot, rain.Radius, rain.Delay)
				task.delay(rain.Delay, function()
					if enemy.Dead then
						return
					end
					effectRemote:FireAllClients("Quake", spot, rain.Radius)
					for _, hit in playersNear(spot, rain.Radius) do
						hurt(hit.Humanoid, hit.Root, enemy.Damage * rain.DamageScale)
					end
				end)
				task.wait(0.15)
			end
		end
	end
	task.wait(math.max(move.Length - move.RiseAt - 0.6, 0.3))
	enemy.Attacking = false
end

-- Under its rage threshold: it roars, then fights faster: runs, lunges, and attacks more often.
local function bossRage(enemy: Enemy)
	local boss = enemy.Boss :: BossState
	local rage = (enemy.Def.Boss :: Enemies.BossDef).Rage
	if not rage then
		return
	end
	enemy.Attacking = true
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	setEyes(enemy, true)
	if boss.Rage then
		boss.Rage:Play(0.15)
	end
	effectRemote:FireAllClients("Quake", enemy.Root.Position - Vector3.new(0, enemy.Humanoid.HipHeight, 0), 16)
	task.wait(rage.Length)
	if enemy.Dead then
		return
	end
	setEyes(enemy, false)
	enemy.Humanoid.WalkSpeed = enemy.Def.WalkSpeed * rage.SpeedScale
	boss.Pace = rage.CooldownScale
	local animator = enemy.Humanoid:FindFirstChildOfClass("Animator")
	if rage.Run and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = rage.Run
		local run = animator:LoadAnimation(animation)
		run.Looped = true
		run.Priority = Enum.AnimationPriority.Movement
		local walk = enemy.Tracks.Walk
		if walk and walk.IsPlaying then
			walk:Stop(0.1)
		end
		enemy.Tracks.Walk = run
	end
	if rage.Lunge and animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = rage.Lunge.Id
		local lunge = animator:LoadAnimation(animation)
		lunge.Looped = false
		lunge.Priority = Enum.AnimationPriority.Action
		boss.Slam = lunge
		boss.SlamMove = rage.Lunge
		boss.NextSlam = os.clock() + 1.5
	end
	enemy.Attacking = false
end

-- Its entrance: it steps slowly out of its tomb to `stepOut` (if given), stands and calls (the summoning pose)
-- while the players watch, then the fight begins.
function EnemyService.PlayIntro(enemy: Enemy, duration: number, stepOut: Vector3?)
	local boss = enemy.Boss
	if not boss then
		return
	end
	enemy.Attacking = true
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	if stepOut then
		task.delay(0.9, function()
			if enemy.Dead then
				return
			end
			local walkSpeed = enemy.Humanoid.WalkSpeed
			enemy.Humanoid.WalkSpeed = 5
			enemy.Humanoid:MoveTo(Vector3.new(stepOut.X, enemy.Root.Position.Y, stepOut.Z))
			task.delay(duration * 0.35 - 1, function()
				enemy.Humanoid.WalkSpeed = walkSpeed
				if not enemy.Dead then
					enemy.Humanoid:MoveTo(enemy.Root.Position)
				end
			end)
		end)
	end
	task.delay(duration * 0.35, function()
		if not enemy.Dead then
			if boss.Pose then
				boss.Pose:Play(0.2, 1, 0.6)
			else
				boss.Summon:Play(0.2, 1, 0.8)
			end
		end
	end)
	task.delay(duration, function()
		boss.NextSlam = os.clock() + 4
		enemy.LastAttack = os.clock()
		enemy.Attacking = false
	end)
end

local function bossThink(enemy: Enemy, targetRoot: BasePart, targetHumanoid: Humanoid, distance: number, now: number)
	local boss = enemy.Boss :: BossState
	local def = enemy.Def.Boss :: Enemies.BossDef
	local ratio = enemy.Humanoid.Health / enemy.Humanoid.MaxHealth
	local nextSummon = def.Summon.At[boss.SummonsDone + 1]
	if def.Rage and not boss.Raged and ratio <= def.Rage.At then
		boss.Raged = true
		task.spawn(bossRage, enemy)
	elseif nextSummon and ratio <= nextSummon then
		boss.SummonsDone += 1
		task.spawn(bossSummon, enemy)
	elseif distance <= def.Kick.Range and now >= boss.NextKick then
		task.spawn(bossKick, enemy, targetRoot)
	elseif distance > def.Kick.Range + 2 and distance <= (boss.SlamMove or def.Slam).Range and now >= boss.NextSlam then
		task.spawn(bossSlam, enemy, targetRoot)
	elseif distance <= enemy.Def.AttackRange then
		if now - enemy.LastAttack >= enemy.Def.AttackCooldown * boss.Pace then
			task.spawn(attack, enemy, targetRoot, targetHumanoid)
		else
			enemy.Humanoid:MoveTo(enemy.Root.Position)
			face(enemy, targetRoot.Position)
		end
	else
		enemy.Humanoid:MoveTo(targetRoot.Position)
	end
end

local function think()
	local now = os.clock()
	for _, enemy in enemies do
		if enemy.Dead or enemy.Attacking then
			continue
		end
		local targetRoot, targetHumanoid = nearestTarget(enemy.Root.Position, enemy.Def.AggroRange)
		if not targetRoot or not targetHumanoid then
			enemy.Humanoid:MoveTo(enemy.Root.Position)
			continue
		end
		local offset = targetRoot.Position - enemy.Root.Position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local ranged = enemy.Def.Ranged
		local sprouts = enemy.Def.Sprouts
		if sprouts and distance <= sprouts.Range then
			-- the first sprouting comes 3 seconds after it first sees a player
			enemy.LastSprout = enemy.LastSprout or now - sprouts.Cooldown + 3
			if now - (enemy.LastSprout :: number) >= sprouts.Cooldown then
				enemy.LastSprout = now
				task.spawn(sprout, enemy, targetRoot)
			end
		end
		if enemy.Def.Burrow then
			if now - enemy.LastAttack >= enemy.Def.AttackCooldown then
				task.spawn(burrowStrike, enemy, targetRoot)
			end
		elseif enemy.Boss then
			bossThink(enemy, targetRoot, targetHumanoid, distance, now)
		elseif ranged then
			if distance < ranged.KeepAway then
				-- Too close: back away from the player.
				local away = Vector3.new(-offset.X, 0, -offset.Z).Unit
				enemy.Humanoid:MoveTo(enemy.Root.Position + away * 8)
			elseif distance > enemy.Def.AttackRange then
				enemy.Humanoid:MoveTo(targetRoot.Position)
			elseif now - enemy.LastAttack >= enemy.Def.AttackCooldown then
				task.spawn(shoot, enemy, targetRoot)
			else
				enemy.Humanoid:MoveTo(enemy.Root.Position)
				face(enemy, targetRoot.Position)
			end
		elseif distance <= enemy.Def.AttackRange then
			if now - enemy.LastAttack >= enemy.Def.AttackCooldown then
				task.spawn(attack, enemy, targetRoot, targetHumanoid)
			else
				enemy.Humanoid:MoveTo(enemy.Root.Position)
				face(enemy, targetRoot.Position)
			end
		else
			enemy.Humanoid:MoveTo(targetRoot.Position)
		end
	end
end

-- Deals damage from a player. `kind` is "Hit", "Crit" or "Poison" (picks the number's look).
function EnemyService.Damage(enemy: Enemy, amount: number, player: Player, kind: string)
	if enemy.Dead or enemy.Burrowed then
		return
	end
	local rounded = math.max(1, math.floor(amount + 0.5))
	enemy.Damagers[player] = (enemy.Damagers[player] or 0) + rounded
	damageNumberRemote:FireAllClients(enemy.Root.Position + Vector3.new(0, 2.5, 0), rounded, kind)
	if kind ~= "Poison" then
		local hit = enemy.Tracks.Hit
		if hit and not enemy.Attacking and enemy.Humanoid.Health > rounded then
			hit:Play(0.05)
		end
		if enemy.Def.Procedural and enemy.Humanoid.Health > rounded then
			enemy.Model:SetAttribute("FlinchCount", (enemy.Model:GetAttribute("FlinchCount") or 0) + 1)
		end
		enemy.Flash.Enabled = true
		task.delay(0.08, function()
			enemy.Flash.Enabled = false
		end)
	end
	enemy.Humanoid.Health = math.max(0, enemy.Humanoid.Health - rounded)
end

-- Every living enemy.
function EnemyService.GetAlive(): { Enemy }
	local list = {}
	for _, enemy in enemies do
		if not enemy.Dead then
			table.insert(list, enemy)
		end
	end
	return list
end

function EnemyService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace

	local function onSpawnPart(instance: Instance)
		if instance:IsA("BasePart") then
			local name = instance:GetAttribute("Enemy")
			EnemyService.Spawn(if type(name) == "string" then name else "Skeleton", instance.CFrame, nil, instance)
		end
	end
	-- One after another: the first spawn builds the template, the rest just clone it.
	task.spawn(function()
		for _, instance in CollectionService:GetTagged(SPAWN_TAG) do
			onSpawnPart(instance)
		end
		CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(onSpawnPart)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= THINK_INTERVAL then
			elapsed = 0
			think()
		end
	end)
end

return EnemyService
