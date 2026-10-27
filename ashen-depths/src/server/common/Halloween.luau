--!strict
-- Halloween (until the morning of 2 November, UTC): carved pumpkins glow round Emberhold's square, and on every
-- floor of the Depths a lost Jack-o'-Lantern hides in one of the rooms, worth a purse of gold to each player who
-- finds it. The pumpkin is a Studio-generated model, ServerStorage.SeasonProps.JackOLantern (pivot at its base);
-- without it nothing is placed. After the date it all simply stops appearing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ProgressService = require(script.Parent.ProgressService)

local ENDS = DateTime.fromUniversalTime(2026, 11, 2).UnixTimestamp
local CANDLE = Color3.fromRGB(255, 140, 50)

local Halloween = {}

function Halloween.On(): boolean
	return os.time() < ENDS
end

-- A carved pumpkin at `at` (its base), lit from inside by a flickering candle.
function Halloween.Lantern(parent: Instance, at: CFrame, scale: number?): Model?
	local folder = ServerStorage:FindFirstChild("SeasonProps")
	local source = folder and folder:FindFirstChild("JackOLantern")
	if not source or not source:IsA("Model") then
		return nil
	end
	local lantern = source:Clone()
	if scale and scale ~= 1 then
		lantern:ScaleTo(lantern:GetScale() * scale)
	end
	lantern:PivotTo(at)
	local cf, size = lantern:GetBoundingBox()
	local core = Instance.new("Part")
	core.Name = "Candle"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CFrame = CFrame.new(cf.Position)
	core.Parent = lantern
	local light = Instance.new("PointLight")
	light.Color = CANDLE
	light.Range = 10 + size.Y * 2
	light.Brightness = 1.6
	light.Shadows = true
	light.Parent = core
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(CANDLE)
	glow.LightEmission = 1
	glow.Size = NumberSequence.new(size.Y * 0.35, 0)
	glow.Transparency = NumberSequence.new(0.6, 1)
	glow.Lifetime = NumberRange.new(0.3, 0.6)
	glow.Rate = 6
	glow.Speed = NumberRange.new(0)
	glow.Parent = core
	for _, p in lantern:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	lantern.Parent = parent
	task.spawn(function()
		local rng = Random.new()
		while lantern.Parent do
			light.Brightness = rng:NextNumber(1.2, 2)
			task.wait(rng:NextNumber(0.08, 0.2))
		end
	end)
	return lantern
end

local function ground(x: number, z: number, ignore: { Instance }): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	return hit and CFrame.new(hit.Position)
end

-- Emberhold: pumpkins at the foot of the plaza's lamp posts (looking in at the Well) and round the Well
-- (looking out at the people walking by).
function Halloween.DecorateTown(town: Model)
	if not Halloween.On() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Halloween"
	folder.Parent = workspace
	local rng = Random.new(31)
	local well = town:FindFirstChild("GreatWell", true)
	local center = if well and well:IsA("Model") then well:GetPivot().Position else Vector3.zero
	local flat = Vector3.new(center.X, 0, center.Z)
	local spots = {}
	for _, lamp in town:GetChildren() do
		if lamp:IsA("Model") and lamp.Name == "LampPost" then
			local at = lamp:GetPivot().Position
			local toWell = flat - Vector3.new(at.X, 0, at.Z)
			-- only the lamps round the plaza, not the ones out along the roads
			if toWell.Magnitude < 50 then
				toWell = toWell.Unit
				local side = toWell:Cross(Vector3.yAxis)
				table.insert(spots, { at + toWell * 2.5 + side * 1.6, toWell, 1 })
				table.insert(spots, { at + toWell * 2.2 - side * 1.8, toWell, 0.7 })
			end
		end
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2 + math.pi / 8
		local at = flat + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 16
		table.insert(spots, { at, Vector3.new(math.cos(angle), 0, math.sin(angle)), if i % 2 == 0 then 1.2 else 0.85 })
	end
	local players = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(players, p.Character)
		end
	end
	for _, spot in spots do
		local base = ground(spot[1].X, spot[1].Z, players)
		if base then
			local facing = CFrame.lookAt(Vector3.zero, spot[2]).Rotation -- (the carved face is on the model's front)
			Halloween.Lantern(folder, base * facing * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), spot[3])
		end
	end
end

-- The Depths: a lost Jack-o'-Lantern on this floor. Each player may take it once: gold for the floor's depth.
function Halloween.HideLantern(parent: Instance, at: Vector3, floor: number): Model?
	if not Halloween.On() then
		return nil
	end
	local lantern = Halloween.Lantern(parent, CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0), 1.1)
	if not lantern then
		return nil
	end
	local core = lantern:FindFirstChild("Candle") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Lost Jack-o'-Lantern"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	local notifyRemote = Remotes.Event("Notify")
	local soundRemote = Remotes.Event("Sound")
	local gold = 40 + floor * 12
	local taken: { [Player]: boolean } = {}
	prompt.Triggered:Connect(function(player)
		if taken[player] then
			notifyRemote:FireClient(player, "You already took this lantern's gold.")
			return
		end
		taken[player] = true
		ProgressService.AddGold(player, gold)
		soundRemote:FireClient(player, "Gold", core.Position)
		notifyRemote:FireClient(player, `Happy Halloween! The lantern held {gold} gold.`)
	end)
	return lantern
end

return Halloween
