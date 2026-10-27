--!strict
-- The Training Grounds on the lawn north of the square: three straw dummies to try a weapon on before going down.
-- Every blow shows its number, the dummy rocks back, and a board over it shows the striker's damage per second
-- over their last few seconds of hitting it. Dummies never break and give nothing: they're for testing.
-- The dummy is a Studio-generated model, ServerStorage.TownProps.TrainingDummy (pivot at its base); without it a
-- plain post and sack stand in. They're the hub's targets for CombatService.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Fonts = require(ReplicatedStorage.Shared.Fonts)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CENTER = Vector3.new(-22, 0, -57) -- on the open lawn between the forge and the houses
local FACING = Vector3.new(0, 0, 1) -- the dummies face the square
local SPACING = 7
local WINDOW = 5 -- seconds of hits the damage-per-second counts
local IDLE = 6 -- seconds without a hit before a dummy's board resets

export type Dummy = {
	Root: BasePart,
	Model: Model,
	Base: CFrame,
	Board: TextLabel,
	Hits: { { Time: number, Amount: number, Player: Player } },
	Rocking: boolean,
}

local TrainingService = {}

local dummies: { Dummy } = {}
local damageNumberRemote = Remotes.Event("DamageNumber")

local function ground(x: number, z: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged("Character")
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position else Vector3.new(x, 0, z)
end

local function stand(name: string, parent: Instance, at: CFrame): Model?
	local folder = ServerStorage:FindFirstChild("TownProps")
	local source = folder and folder:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local copy = source:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	copy:PivotTo(at)
	local box, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() + (at.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))))
	copy.Parent = parent
	return copy
end

local function plainDummy(parent: Instance, at: CFrame): Model
	local model = Instance.new("Model")
	local function piece(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Parent = model
	end
	piece(Vector3.new(0.6, 5, 0.6), at * CFrame.new(0, 2.5, 0), Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
	piece(Vector3.new(3.2, 0.5, 0.5), at * CFrame.new(0, 4, 0), Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
	piece(Vector3.new(2, 2.6, 1.4), at * CFrame.new(0, 3.6, 0), Color3.fromRGB(176, 150, 104), Enum.Material.Fabric)
	piece(Vector3.new(1.3, 1.3, 1.3), at * CFrame.new(0, 5.6, 0), Color3.fromRGB(176, 150, 104), Enum.Material.Fabric)
	model.Parent = parent
	return model
end

local function makeBoard(parent: BasePart, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "DpsBoard"
	gui.Size = UDim2.fromScale(4.2, 1.1) -- (in studs: it shrinks with distance like the dummy)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
	label.TextColor3 = Color3.fromRGB(255, 214, 150)
	label.FontFace = Fonts.Body
	label.TextScaled = true
	label.Text = "Hit me!"
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = label
	gui.Parent = parent
	return label
end

-- What a dummy's board says now: the last striker's damage per second over their hits in the window.
local function refresh(dummy: Dummy)
	local now = os.clock()
	local kept = {}
	for _, hit in dummy.Hits do
		if now - hit.Time <= WINDOW then
			table.insert(kept, hit)
		end
	end
	dummy.Hits = kept
	local last = kept[#kept]
	if not last then
		dummy.Board.Text = "Hit me!"
		return
	end
	local total, first = 0, last.Time
	for _, hit in kept do
		if hit.Player == last.Player then
			total += hit.Amount
			first = math.min(first, hit.Time)
		end
	end
	-- (over at least a second, so one blow doesn't read as a huge rate)
	local dps = total / math.max(now - first, 1)
	dummy.Board.Text = `{last.Player.DisplayName}\n{math.floor(dps + 0.5)} damage / sec`
end

local function rock(dummy: Dummy, from: Vector3)
	if dummy.Rocking then
		return
	end
	dummy.Rocking = true
	local away = Vector3.new(dummy.Root.Position.X - from.X, 0, dummy.Root.Position.Z - from.Z)
	away = if away.Magnitude > 0.01 then away.Unit else -FACING
	-- tilt back about the base, away from the blow
	local axis = Vector3.yAxis:Cross(away)
	local tilt = dummy.Base * CFrame.fromAxisAngle(dummy.Base:VectorToObjectSpace(axis), math.rad(12))
	local value = Instance.new("CFrameValue")
	value.Value = dummy.Base
	value.Changed:Connect(function(cf)
		dummy.Model:PivotTo(cf)
	end)
	local out = TweenService:Create(value, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Value = tilt })
	out:Play()
	out.Completed:Wait()
	local back = TweenService:Create(value, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), { Value = dummy.Base })
	back:Play()
	back.Completed:Wait()
	value:Destroy()
	dummy.Rocking = false
end

function TrainingService.GetAlive(): { Dummy }
	return dummies
end

function TrainingService.Damage(dummy: Dummy, amount: number, player: Player, kind: string)
	local rounded = math.max(1, math.floor(amount + 0.5))
	damageNumberRemote:FireAllClients(dummy.Root.Position + Vector3.new(0, 2.5, 0), rounded, kind)
	table.insert(dummy.Hits, { Time = os.clock(), Amount = rounded, Player = player })
	refresh(dummy)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	task.spawn(rock, dummy, if root then root.Position else dummy.Root.Position - FACING)
end

function TrainingService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "TrainingGrounds"
	folder.Parent = workspace
	local side = Vector3.yAxis:Cross(FACING)
	for i = -1, 1 do
		local spot = CENTER + side * (i * SPACING)
		local at = CFrame.lookAt(ground(spot.X, spot.Z), ground(spot.X, spot.Z) + FACING)
		local model = stand("TrainingDummy", folder, at) or plainDummy(folder, at)
		model.Name = "TrainingDummy"
		local _, size = model:GetBoundingBox()
		-- what blows hit and what the aim locks onto: a box round the body, with a Humanoid for the aim
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Transparency = 1
		root.CanCollide = true
		root.Size = Vector3.new(2.6, size.Y * 0.8, 1.8)
		root.CFrame = at + Vector3.new(0, size.Y * 0.45, 0)
		root.Parent = model
		local humanoid = Instance.new("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.Parent = model
		CollectionService:AddTag(model, "Enemy")
		local dummy: Dummy = {
			Root = root,
			Model = model,
			Base = model:GetPivot(),
			Board = makeBoard(root, size.Y * 0.6 + 1.5),
			Hits = {},
			Rocking = false,
		}
		table.insert(dummies, dummy)
	end
	-- the rack of practice weapons behind them, and the name over the ground
	local rackSpot = CENTER - FACING * 6 + side * (SPACING * 1.6)
	stand("WeaponRack", folder, CFrame.lookAt(ground(rackSpot.X, rackSpot.Z), ground(rackSpot.X, rackSpot.Z) + FACING))
	local mark = Instance.new("Part")
	mark.Name = "TrainingSign"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.Transparency = 1
	mark.Size = Vector3.new(1, 1, 1)
	mark.Position = ground(CENTER.X, CENTER.Z) + Vector3.new(0, 10, 0)
	mark.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, 2)
	gui.MaxDistance = 90
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = "Training Grounds"
	title.TextColor3 = Color3.fromRGB(255, 210, 140)
	title.TextStrokeTransparency = 0.4
	title.FontFace = Fonts.Title
	title.TextScaled = true
	title.Parent = gui
	gui.Parent = mark

	task.spawn(function()
		while true do
			task.wait(1)
			for _, dummy in dummies do
				local last = dummy.Hits[#dummy.Hits]
				if not last or os.clock() - last.Time > IDLE then
					dummy.Hits = {}
					dummy.Board.Text = "Hit me!"
				else
					refresh(dummy)
				end
			end
		end
	end)
end

return TrainingService
