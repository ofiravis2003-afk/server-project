--!strict
-- Attacking with the held weapon: click / tap (hold to keep attacking), or the Attack button on a phone.
-- Aims by itself at the nearest enemy in reach; with no enemy near, attacks toward the mouse
-- (computer) or straight ahead (phone). The server decides what is actually hit.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(ReplicatedStorage.Shared.Device)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Audio = require(script.Parent.Audio)

local ACTION = "AshenAttack"
local AUTO_AIM_REACH = 1.3 -- melee weapons look for targets a bit past their reach

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local attackRemote = Remotes.Event("Attack")

local Combat = {}

local heldTool: Tool? = nil
local holding = false
local lastFire = 0
local swingTracks: { AnimationTrack } = {}
local swingIndex = 0
local holdTrack: AnimationTrack? = nil

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
	flat = flat.Unit

	-- Turn to face the attack.
	if not humanoid.Sit then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	playSwing(weapon, sinceLast)
	Audio.Play(if weapon.Kind == "Melee" then "Swing" else "Spell")
	attackRemote:FireServer(tool:GetAttribute("ItemId"), flat, aimPoint)
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
