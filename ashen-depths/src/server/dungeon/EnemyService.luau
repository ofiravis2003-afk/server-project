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
	HealthMultiplier: number?,
	DamageMultiplier: number?,
	Elite: boolean?,
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
}

local EnemyService = {}

local enemies: { [Model]: Enemy } = {}
local templates: { [string]: Model } = {}
local folder: Folder
local damageNumberRemote = Remotes.Event("DamageNumber")
local effectRemote = Remotes.Event("Effect")

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
	humanoid.HipHeight = height / 2 - root.Size.Y / 2
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

local function getTemplate(name: string): Model
	local template = templates[name]
	if not template then
		local def = Enemies[name]
		local modelsFolder = ServerStorage:FindFirstChild("EnemyModels")
		local source = modelsFolder and modelsFolder:FindFirstChild(def.Model or name)
		if source and source:IsA("Model") then
			template = buildFromModel(source, def)
		elseif BUILDERS[name] then
			template = BUILDERS[name]()
		else
			template = buildFromModel(slimeBlob(), def)
		end
		if def.Scale and def.Scale ~= 1 then
			template:ScaleTo(template:GetScale() * def.Scale)
		end
		for _, held in def.HeldProps or {} do
			holdProp(template, held)
		end
		template.Name = name
		templates[name] = template
	end
	return template
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

local function onDied(enemy: Enemy, options: SpawnOptions, spawnPart: BasePart?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	CollectionService:RemoveTag(enemy.Model, ENEMY_TAG)
	enemies[enemy.Model] = nil

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
					-- The death clip has laid the body on its back behind the root: shatter there, low down.
					ground -= enemy.Root.CFrame.LookVector * (crumble.FallBack or 0) * scale
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
	local rewards = if enemy.Elite then ELITE.Rewards else 1
	for player, dealt in enemy.Damagers do
		if player.Parent and dealt > 0 then
			local xp = enemy.Def.XP * rewards
			local gold = math.random(enemy.Def.Gold[1], enemy.Def.Gold[2]) * rewards
			ProgressService.AddXP(player, xp)
			ProgressService.AddGold(player, gold)
			damageNumberRemote:FireClient(player, position + Vector3.new(0, 3, 0), `+{xp} XP   +{gold} Gold`, "Reward")
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
	local health = def.Health * (opts.HealthMultiplier or 1) * (if elite then ELITE.Health else 1)
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

	model:PivotTo(cframe + Vector3.new(0, 3, 0))
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
		tracks.Idle.Looped = true
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
	local enemy: Enemy = {
		Name = name,
		Def = def,
		Damage = def.Damage * (opts.DamageMultiplier or 1) * (if elite then ELITE.Damage else 1),
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
	}
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

local function attack(enemy: Enemy, targetRoot: BasePart, targetHumanoid: Humanoid)
	enemy.Attacking = true
	enemy.LastAttack = os.clock()
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	face(enemy, targetRoot.Position)
	setEyes(enemy, true)
	if #enemy.AttackTracks > 0 then
		-- A random blow from its set, timed so the weapon lands as the Windup ends.
		local clip = enemy.AttackTracks[math.random(#enemy.AttackTracks)]
		clip.Track:Play(0.1, 1, clip.HitAt / enemy.Def.Windup)
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
			local damage = math.floor(enemy.Damage + 0.5)
			targetHumanoid:TakeDamage(damage)
			damageNumberRemote:FireAllClients(targetRoot.Position + Vector3.new(0, 2.5, 0), damage, "Hurt")
		end
	end
	enemy.Attacking = false
end

-- Archers: show a red aiming line, then loose an arrow at where the target stands at that moment.
-- Whoever is still within HitRadius of that spot when the arrow arrives is hit.
local function shoot(enemy: Enemy, targetRoot: BasePart)
	local ranged = enemy.Def.Ranged :: { KeepAway: number, ProjectileSpeed: number, HitRadius: number }
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
		effectRemote:FireAllClients("Arrow", from, aim, travel)
		local damage = math.floor(enemy.Damage + 0.5)
		task.delay(travel, function()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid and humanoid.Health > 0 and (root.Position - aim).Magnitude <= ranged.HitRadius then
					humanoid:TakeDamage(damage)
					damageNumberRemote:FireAllClients(root.Position + Vector3.new(0, 2.5, 0), damage, "Hurt")
				end
			end
		end)
	end
	enemy.Attacking = false
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
		if ranged then
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
	if enemy.Dead then
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
