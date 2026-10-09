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

local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ProgressService = require(script.Parent.Parent.Common.ProgressService)

local SPAWN_TAG = "EnemySpawn"
local ENEMY_TAG = "Enemy"
local THINK_INTERVAL = 0.15

-- Roblox's own default R15 animations (idle, walk, tool slash).
local ANIMATIONS = {
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

local BUILDERS: { [string]: () -> Model } = {
	Skeleton = buildSkeleton,
}

local function getTemplate(name: string): Model
	local template = templates[name]
	if not template then
		template = BUILDERS[name]()
		templates[name] = template
	end
	return template
end

local function setEyes(enemy: Enemy, flaring: boolean)
	for _, eye in enemy.Eyes do
		eye.Color = if flaring then Color3.fromRGB(255, 230, 160) else enemy.EyeColor
		eye.Size = if flaring then Vector3.new(0.18, 0.14, 0.05) else Vector3.new(0.14, 0.1, 0.05)
	end
	enemy.EyeLight.Brightness = if flaring then 3 else 0.6
	enemy.EyeLight.Range = if flaring then 9 else 5
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
	-- The bones fall apart and scatter on the floor.
	for _, part in enemy.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
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

	task.delay(4, function()
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
	local eyeLight = head:FindFirstChild("EyeLight") :: PointLight
	eyeLight.Color = eyeColor
	if elite then
		model.Name = `Elite {def.DisplayName}`
		model:ScaleTo(ELITE.Scale)
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

	local animator = humanoid:FindFirstChildOfClass("Animator") :: Animator
	local tracks = {}
	for key, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		tracks[key] = animator:LoadAnimation(animation)
	end
	tracks.Idle.Looped = true
	tracks.Walk.Looped = true
	tracks.Attack.Priority = Enum.AnimationPriority.Action
	tracks.Idle:Play()

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
		Damagers = {},
		LastAttack = 0,
		Attacking = false,
		Dead = false,
	}
	enemies[model] = enemy
	CollectionService:AddTag(model, ENEMY_TAG)

	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not tracks.Walk.IsPlaying then
				tracks.Walk:Play()
			end
		elseif tracks.Walk.IsPlaying then
			tracks.Walk:Stop()
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
	enemy.Tracks.Attack:Play(0.1, 1, 0.8)

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
		if distance <= enemy.Def.AttackRange then
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
