--!strict
-- Attacking with the held weapon: click / tap (hold to keep attacking), or the Attack button on a phone.
-- Aims by itself at the nearest enemy in reach; with no enemy near, attacks toward the mouse
-- (computer) or straight ahead (phone). The server decides what is actually hit.
-- The weapon's special move (shared/Abilities) is on Q (a gamepad's X, or a round button on a phone), with a
-- slot by the hotbar showing its name and its cooldown, or the level it's learned at.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(ReplicatedStorage.Shared.Device)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Audio = require(script.Parent.Audio)

local ACTION = "AshenAttack"
local ABILITY_ACTION = "AshenAbility"
local AUTO_AIM_REACH = 1.3 -- melee weapons look for targets a bit past their reach

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local attackRemote = Remotes.Event("Attack")
local abilityRemote = Remotes.Event("Ability")

local Combat = {}

local heldTool: Tool? = nil
local holding = false
local lastFire = 0
local swingTracks: { AnimationTrack } = {}
local swingIndex = 0
local holdTrack: AnimationTrack? = nil
local lastAbility = -math.huge

-- Loads the held weapon's attack clips onto the character (played here; Roblox shares them with everyone).
local function loadSwings(humanoid: Humanoid, weapon: Weapons.WeaponType)
	for _, track in swingTracks do
		track:Destroy()
	end
	swingTracks = {}
	swingIndex = 0
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	if holdTrack then
		holdTrack:Stop(0.2)
		holdTrack:Destroy()
		holdTrack = nil
	end
	if weapon.Hold then
		-- Above the default walk and tool pose (so the arms keep the stance), below the swings.
		local animation = Instance.new("Animation")
		animation.AnimationId = weapon.Hold
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		track:Play(0.25)
		holdTrack = track
	end
	for _, id in weapon.Swings or {} do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		table.insert(swingTracks, track)
	end
end

-- The next swing: in turn for a combo, starting over after a pause.
local function playSwing(weapon: Weapons.WeaponType, sinceLast: number)
	if #swingTracks == 0 then
		return
	end
	swingIndex = if sinceLast > weapon.Cooldown * 2.5 then 1 else swingIndex % #swingTracks + 1
	for _, track in swingTracks do
		track:Stop(0.08)
	end
	local track = swingTracks[swingIndex]
	local speed = weapon.SwingSpeed or 1
	track:Play(0.06, 1, speed)
	local length = weapon.SwingLength
	if length then
		task.delay(length / speed, function()
			if track.IsPlaying and track.TimePosition >= length - 0.05 then
				track:Stop(0.15)
			end
		end)
	end
end

local function findTarget(root: BasePart, range: number): BasePart?
	local best, bestScore = nil, math.huge
	local look = root.CFrame.LookVector
	for _, model in CollectionService:GetTagged("Enemy") do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local enemyRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and humanoid.Health > 0 and enemyRoot then
			local offset = enemyRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if distance <= range then
				local inFront = distance < 0.1 or look:Dot(flat.Unit) > 0.2
				local score = if inFront then distance else distance * 1.8
				if score < bestScore then
					best, bestScore = enemyRoot, score
				end
			end
		end
	end
	return best
end

-- Which way to strike: at the nearest enemy within `reach`, or else toward the mouse (computer) or straight
-- ahead (phone). Returns the flat direction and the point aimed at (if any).
local function aimFrom(root: BasePart, reach: number): (Vector3, Vector3?)
	local target = findTarget(root, reach)
	local direction: Vector3
	local aimPoint: Vector3? = nil
	if target then
		direction = target.Position - root.Position
		aimPoint = target.Position - Vector3.new(0, 2.5, 0)
	elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		direction = root.CFrame.LookVector
	else
		direction = mouse.Hit.Position - root.Position
		aimPoint = mouse.Hit.Position
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = root.CFrame.LookVector
	end
	return flat.Unit, aimPoint
end

local function tryAttack()
	local tool = heldTool
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Cutscene") then
		return
	end
	local weapon = Weapons[tool:GetAttribute("WeaponType") :: string]
	if not weapon then
		return
	end
	local now = os.clock()
	if now - lastFire < weapon.Cooldown then
		return
	end
	local sinceLast = now - lastFire
	lastFire = now

	local reach = if weapon.Kind == "Melee" then weapon.Range * AUTO_AIM_REACH else weapon.Range
	local flat, aimPoint = aimFrom(root, reach)

	-- Turn to face the attack.
	if not humanoid.Sit then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	playSwing(weapon, sinceLast)
	Audio.Play(if weapon.Kind == "Melee" then "Swing" else "Spell")
	attackRemote:FireServer(tool:GetAttribute("ItemId"), flat, aimPoint)
end

-- The held weapon's special move, if learned and ready (the server checks both again).
local function tryAbility()
	local tool = heldTool
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not root or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Cutscene") then
		return
	end
	local weaponType = tool:GetAttribute("WeaponType") :: string
	local weapon = Weapons[weaponType]
	local ability, _rank, rank = Abilities.At(weaponType, (player:GetAttribute("Level") :: number?) or 1)
	if not weapon or not ability or not rank then
		return
	end
	local now = os.clock()
	if now - lastAbility < rank.Cooldown then
		return
	end
	lastAbility = now
	local flat, aimPoint = aimFrom(root, if ability.Kind == "Meteor" then ability.Range or 45 else ability.Radius)
	if not humanoid.Sit then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	-- the weapon's own strongest swing, a little quicker
	if #swingTracks > 0 then
		for _, track in swingTracks do
			track:Stop(0.05)
		end
		swingTracks[#swingTracks]:Play(0.05, 1, (weapon.SwingSpeed or 1) * 1.3)
	end
	Audio.Play(if weapon.Kind == "Melee" then "Swing" else "Spell")
	abilityRemote:FireServer(tool:GetAttribute("ItemId"), flat, aimPoint)
end

-- The special move's slot by the hotbar: its name, the key, the cooldown counting down, or the level it opens at.
local function abilitySlot(weaponType: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilitySlot"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	local touch = Device.Touch()
	local b = Instance.new("TextButton")
	b.Name = "Ability"
	b.AutoButtonColor = true
	b.Text = ""
	b.BackgroundColor3 = Color3.fromRGB(34, 24, 18)
	b.BackgroundTransparency = 0.1
	if touch then
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -228, 1, -44)
		b.Size = UDim2.fromOffset(78, 78)
	else
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0.5, 150, 1, -6)
		b.Size = UDim2.fromOffset(66, 66)
	end
	b.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = if touch then UDim.new(1, 0) else UDim.new(0, 10)
	round.Parent = b
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(240, 190, 90)
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = b
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -8, 0.5, 0)
	name.Position = UDim2.new(0, 4, 0.18, 0)
	name.FontFace = Fonts.Title
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 220, 150)
	name.ZIndex = 3
	name.Parent = b
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -8, 0.26, 0)
	sub.Position = UDim2.new(0, 4, 0.68, 0)
	sub.FontFace = Fonts.Body
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(226, 214, 196)
	sub.ZIndex = 3
	sub.Parent = b
	-- the cooldown: a dark veil drawn down from the top as it recharges
	local veil = Instance.new("Frame")
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0.35
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 0)
	veil.ZIndex = 2
	veil.Parent = b
	local veilRound = Instance.new("UICorner")
	veilRound.CornerRadius = round.CornerRadius
	veilRound.Parent = veil
	b.Activated:Connect(tryAbility)
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		local level = (player:GetAttribute("Level") :: number?) or 1
		local ability, rankIndex, rank = Abilities.At(weaponType, level)
		local def = Abilities.Defs[weaponType]
		if not def then
			gui.Enabled = false
			return
		end
		gui.Enabled = true
		local numerals = { "", " II", " III" }
		name.Text = def.Name .. (numerals[rankIndex] or "")
		if not ability or not rank then
			name.TextTransparency = 0.5
			sub.Text = `Level {Abilities.UnlockLevel}`
			veil.Size = UDim2.fromScale(1, 1)
			return
		end
		name.TextTransparency = 0
		local left = rank.Cooldown - (os.clock() - lastAbility)
		if left > 0 then
			veil.Size = UDim2.fromScale(1, math.clamp(left / rank.Cooldown, 0, 1))
			sub.Text = string.format("%d", math.ceil(left))
		else
			veil.Size = UDim2.fromScale(1, 0)
			sub.Text = if touch then "" else "Q"
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function onAbilityAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		tryAbility()
	end
	return Enum.ContextActionResult.Sink
end

local function startHolding()
	if holding then
		return
	end
	holding = true
	task.spawn(function()
		while holding and heldTool do
			tryAttack()
			task.wait(0.05)
		end
		holding = false
	end)
end

local function onAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		startHolding()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false
	end
	return Enum.ContextActionResult.Sink
end

local function onToolEquipped(tool: Tool)
	if not tool:GetAttribute("ItemId") then
		return
	end
	heldTool = tool
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local weapon = Weapons[tool:GetAttribute("WeaponType") :: string]
	if humanoid and weapon then
		loadSwings(humanoid, weapon)
	end
	local activated = tool.Activated:Connect(startHolding)
	local deactivated = tool.Deactivated:Connect(function()
		holding = false
	end)
	-- a gamepad trigger through ContextActionService; on a touch screen, a big round button by the jump button
	ContextActionService:BindAction(ACTION, onAction, false, Enum.KeyCode.ButtonR2) -- (the mouse goes through tool.Activated)
	ContextActionService:BindAction(ABILITY_ACTION, onAbilityAction, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	local slot = abilitySlot(tool:GetAttribute("WeaponType") :: string)
	local touchGui: ScreenGui? = nil
	if Device.Touch() then
		local gui = Instance.new("ScreenGui")
		gui.Name = "AttackButton"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 3
		local b = Instance.new("TextButton")
		b.Name = "Attack"
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -120, 1, -40)
		b.Size = UDim2.fromOffset(96, 96)
		b.BackgroundColor3 = Color3.fromRGB(120, 40, 30)
		b.BackgroundTransparency = 0.15
		b.AutoButtonColor = true
		b.Font = Enum.Font.GothamBlack
		b.TextSize = 40
		b.TextColor3 = Color3.fromRGB(255, 225, 190)
		b.Text = "⚔"
		b.Parent = gui
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = b
		local ring = Instance.new("UIStroke")
		ring.Color = Color3.fromRGB(240, 190, 90)
		ring.Thickness = 3
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				startHolding()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				holding = false
			end
		end)
		gui.Parent = player:WaitForChild("PlayerGui")
		touchGui = gui
	end

	tool.AncestryChanged:Once(function()
		activated:Disconnect()
		deactivated:Disconnect()
		if heldTool == tool then
			heldTool = nil
			holding = false
			ContextActionService:UnbindAction(ACTION)
			ContextActionService:UnbindAction(ABILITY_ACTION)
			slot:Destroy()
			if touchGui then
				touchGui:Destroy()
			end
			if holdTrack then
				holdTrack:Stop(0.2)
				holdTrack = nil
			end
		end
	end)
end

local function onCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onToolEquipped(child)
		end
	end)
end

function Combat.Start()
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return Combat
