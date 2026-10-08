--!strict
-- Attacking with the held weapon: click / tap (hold to keep attacking), or the Attack button on a phone.
-- Aims by itself at the nearest enemy in reach; with no enemy near, attacks toward the mouse
-- (computer) or straight ahead (phone). The server decides what is actually hit.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local ACTION = "AshenAttack"
local AUTO_AIM_REACH = 1.3 -- melee weapons look for targets a bit past their reach

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local attackRemote = Remotes.Event("Attack")

local Combat = {}

local heldTool: Tool? = nil
local holding = false
local lastFire = 0

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
	if not tool or not root or not humanoid or humanoid.Health <= 0 then
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
	lastFire = now

	local reach = if weapon.Kind == "Melee" or weapon.Kind == "Line"
		then weapon.Range * AUTO_AIM_REACH
		else weapon.Range
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
	local activated = tool.Activated:Connect(startHolding)
	local deactivated = tool.Deactivated:Connect(function()
		holding = false
	end)
	ContextActionService:BindAction(ACTION, onAction, true)
	ContextActionService:SetTitle(ACTION, "Attack")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -190, 1, -120))

	tool.AncestryChanged:Once(function()
		activated:Disconnect()
		deactivated:Disconnect()
		if heldTool == tool then
			heldTool = nil
			holding = false
			ContextActionService:UnbindAction(ACTION)
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
