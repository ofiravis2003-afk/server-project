--!strict
-- A new adventurer's first fight, right after taking the Guild Brand (IntroService): the Great Well shakes and
-- breathes ash, and three skeletons burst up out of the ash on the road toward the player. The first Wardstone
-- below has gone dark and the dead are climbing out; Aldric shouts to use the Brand. The skeletons go only for
-- that player (other people in town are left alone), are weak, and can't kill them: their health never drops
-- under a quarter. When all three have fallen, done() runs (Aldric sends them down the Well).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local EnemyService = require(script.Parent.Parent.Common.EnemyService)
local TipService = require(script.Parent.Parent.Common.TipService)

local TownFight = {}

local COUNT = 3
local HEALTH = 0.35 -- of a floor 1 skeleton's
local DAMAGE = 0.4
local SPAWN_DISTANCE = 26 -- studs from the player, toward the Well
local LIMIT = 150 -- seconds: whatever is still standing by then crumbles away, and the fight counts as over
local FLOOR = 0.25 -- the player's health never drops under this share of their max during the fight
local SHOUT = "The first Wardstone has gone dark... they're climbing out! Your Brand, use it!"

local fighting: { [Player]: boolean } = {}

local function ground(at: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else at
end

-- Grey ash pouring up out of the Well for a few seconds.
local function ashFromWell(well: BasePart, seconds: number)
	local holder = Instance.new("Part")
	holder.Name = "WellAsh"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(8, 1, 8)
	holder.CFrame = CFrame.new(well.Position + Vector3.new(0, 1, 0))
	local ash = Instance.new("ParticleEmitter")
	ash.Color = ColorSequence.new(Color3.fromRGB(95, 90, 88), Color3.fromRGB(150, 140, 132))
	ash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	ash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	ash.Lifetime = NumberRange.new(3, 5)
	ash.Speed = NumberRange.new(10, 16)
	ash.SpreadAngle = Vector2.new(18, 18)
	ash.Acceleration = Vector3.new(0, -1.5, 0)
	ash.Drag = 0.6
	ash.Rate = 45
	ash.Parent = holder
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 150, 70))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	embers.Lifetime = NumberRange.new(1.5, 2.5)
	embers.Speed = NumberRange.new(12, 20)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Rate = 25
	embers.Parent = holder
	holder.Parent = workspace
	task.delay(seconds, function()
		ash.Enabled = false
		embers.Enabled = false
		task.wait(6)
		holder:Destroy()
	end)
end

-- Aldric's shout, for this player only: a line across the top of their screen, like a subtitle.
local function shout(player: Player, text: string, seconds: number)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AldricShout"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.2)
	label.Size = UDim2.new(0.8, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(255, 220, 160)
	label.FontFace = Fonts.Title
	label.TextSize = 24
	label.TextWrapped = true
	label.RichText = true
	label.Text = `<font color="#f0be5a">Aldric:</font> "{text}"`
	label.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, math.huge)
	limit.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(120, 90, 50)
	edge.Thickness = 1.5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = label
	gui.Parent = playerGui
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

-- The weapon in hand, so the first click swings it.
local function drawWeapon(player: Player, humanoid: Humanoid)
	local character = player.Character
	if not character or character:FindFirstChildOfClass("Tool") then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local first: Tool? = nil
	for _, tool in if backpack then backpack:GetChildren() else {} do
		if tool:IsA("Tool") then
			if tool:GetAttribute("WeaponType") ~= nil then
				first = tool
				break
			end
			first = first or tool
		end
	end
	if first then
		humanoid:EquipTool(first)
	end
end

function TownFight.Begin(player: Player, town: { Model: Model, Well: BasePart }, done: () -> ())
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if fighting[player] or not character or not root or not humanoid then
		task.spawn(done)
		return
	end
	fighting[player] = true
	local soundRemote = Remotes.Event("Sound")
	local effectRemote = Remotes.Event("Effect")
	local notifyRemote = Remotes.Event("Notify")
	local started = os.clock()

	-- the Well shakes and breathes ash
	task.wait(1.5)
	effectRemote:FireClient(player, "Quake", town.Well.Position, 14)
	soundRemote:FireClient(player, "BossRoar", town.Well.Position)
	ashFromWell(town.Well, 7)
	notifyRemote:FireClient(player, "The ground shakes. Ash pours out of the Great Well...")
	task.wait(2)
	if not player.Parent or not root.Parent then
		fighting[player] = nil
		return
	end

	-- they burst up out of the ash on the road, between the player and the Well
	local toWell = Vector3.new(town.Well.Position.X - root.Position.X, 0, town.Well.Position.Z - root.Position.Z)
	local forward = if toWell.Magnitude > 1 then toWell.Unit else root.CFrame.LookVector
	local side = forward:Cross(Vector3.yAxis)
	local base = root.Position + forward * math.min(SPAWN_DISTANCE, toWell.Magnitude * 0.6)
	local left = COUNT
	local living = {}
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		fighting[player] = nil
		for _, enemy in living do
			EnemyService.Remove(enemy)
		end
		if player.Parent then
			pcall(function()
				AnalyticsService:LogCustomEvent(player, "TownFightWon", math.floor(os.clock() - started))
			end)
			done()
		end
	end
	for i = 1, COUNT do
		local offset = side * ((i - (COUNT + 1) / 2) * 6) + forward * (if i % 2 == 0 then 3 else 0)
		local at = ground(base + offset, { character, town.Well })
		effectRemote:FireClient(player, "Quake", at, 5)
		local enemy = EnemyService.Spawn("Skeleton", CFrame.lookAt(at + Vector3.new(0, 3, 0), Vector3.new(root.Position.X, at.Y + 3, root.Position.Z)), {
			HealthMultiplier = HEALTH,
			DamageMultiplier = DAMAGE,
			Only = player,
			OnDied = function()
				left -= 1
				if left <= 0 then
					task.wait(2.5)
					finish()
				end
			end,
		})
		if enemy then
			table.insert(living, enemy)
		else
			left -= 1
		end
		task.wait(0.35)
	end
	if left <= 0 then
		finish()
		return
	end

	shout(player, SHOUT, 8)
	drawWeapon(player, humanoid)
	TipService.Show(player, "Attack")

	-- they can't kill a newcomer: the health stops at a quarter
	local guard = humanoid.HealthChanged:Connect(function(health)
		local least = humanoid.MaxHealth * FLOOR
		if not finished and health < least then
			humanoid.Health = least
		end
	end)
	task.delay(LIMIT, finish)
	while not finished and player.Parent do
		task.wait(0.5)
	end
	guard:Disconnect()
	if not player.Parent then
		finish()
	end
end

-- Studio only: ServerStorage.DevTownFight:Invoke(player) starts the fight again (to watch it).
function TownFight.Start(town: { Model: Model, Well: BasePart })
	Players.PlayerRemoving:Connect(function(player)
		fighting[player] = nil
	end)
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevTownFight"
		dev.OnInvoke = function(player: Player)
			task.spawn(TownFight.Begin, player, town, function()
				print("[TownFight] won")
			end)
			return true
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return TownFight
