--!strict
-- Traps: they run in a loop, and always show a warning before they hurt, so a careful player
-- can time their way past.
--   Spikes: an iron grate in the floor glows red, then spikes shoot up.
--   Flames: a vent hisses sparks, then a column of fire bursts out for a moment.
--   Arrows: a slit in a corridor wall glows, then an arrow flies across the corridor.
-- Traps only run while a player is close, and stop when their floor is destroyed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTIVE_RANGE = 70
local IRON = Color3.fromRGB(40, 38, 38)
local WARN = Color3.fromRGB(255, 60, 30)

local TrapService = {}

local damageNumberRemote = Remotes.Event("DamageNumber")
local effectRemote = Remotes.Event("Effect")

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
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

-- Players whose body is inside the box `cframe` / `size` (checked from where they really are).
local function playersInBox(cframe: CFrame, size: Vector3): { { Humanoid: Humanoid, Root: BasePart } }
	local hits = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local p = cframe:PointToObjectSpace(root.Position)
			if math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2 then
				table.insert(hits, { Humanoid = humanoid, Root = root })
			end
		end
	end
	return hits
end

local function anyoneNear(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= ACTIVE_RANGE then
			return true
		end
	end
	return false
end

local function hurt(target: { Humanoid: Humanoid, Root: BasePart }, damage: number)
	local amount = math.floor(damage + 0.5)
	target.Humanoid:TakeDamage(amount)
	damageNumberRemote:FireAllClients(target.Root.Position + Vector3.new(0, 2.5, 0), amount, "Hurt")
end

-- Runs `cycle` over and over (after a random delay so traps don't all fire together),
-- while the trap still exists and someone is close.
local function loop(anchor: BasePart, period: number, cycle: () -> ())
	task.spawn(function()
		task.wait(math.random() * period)
		while anchor.Parent do
			if anyoneNear(anchor.Position) then
				cycle()
			end
			task.wait(period)
		end
	end)
end

-- `cframe` is the trap's center on the floor.
function TrapService.Spikes(parent: Instance, cframe: CFrame, damage: number)
	local model = Instance.new("Model")
	model.Name = "SpikeTrap"
	local glow = part(model, "Glow", Vector3.new(5.6, 0.1, 5.6), cframe * CFrame.new(0, 0.02, 0), Color3.fromRGB(30, 10, 8), Enum.Material.SmoothPlastic)
	glow.CanCollide = false
	for i = -2, 2 do
		part(model, "GrateBar", Vector3.new(0.3, 0.12, 6), cframe * CFrame.new(i * 1.3, 0.08, 0), IRON, Enum.Material.Metal)
		part(model, "GrateBar", Vector3.new(6, 0.12, 0.3), cframe * CFrame.new(0, 0.08, i * 1.3), IRON, Enum.Material.Metal)
	end
	local down = cframe * CFrame.new(0, -1.4, 0)
	local up = cframe * CFrame.new(0, 1.0, 0)
	local spikes = part(model, "Spikes", Vector3.new(5, 0.2, 5), down, IRON, Enum.Material.Metal)
	spikes.Transparency = 1
	spikes.CanCollide = false
	for x = -2, 2 do
		for z = -2, 2 do
			local spike = part(model, "Spike", Vector3.new(0.25, 2.2, 0.25), down * CFrame.new(x * 1.1, 0, z * 1.1), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
			spike.Anchored = false
			spike.CanCollide = false
			spike.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = spikes
			weld.Part1 = spike
			weld.Parent = spike
		end
	end
	model.Parent = parent

	loop(glow, 3.5, function()
		glow.Material = Enum.Material.Neon
		glow.Color = WARN
		task.wait(0.8)
		TweenService:Create(spikes, TweenInfo.new(0.12), { CFrame = up }):Play()
		task.wait(0.1)
		for _, target in playersInBox(cframe * CFrame.new(0, 2.5, 0), Vector3.new(6, 6, 6)) do
			hurt(target, damage)
		end
		glow.Material = Enum.Material.SmoothPlastic
		glow.Color = Color3.fromRGB(30, 10, 8)
		task.wait(0.8)
		TweenService:Create(spikes, TweenInfo.new(0.4), { CFrame = down }):Play()
	end)
end

function TrapService.Flames(parent: Instance, cframe: CFrame, damage: number)
	local model = Instance.new("Model")
	model.Name = "FlameTrap"
	local vent = part(model, "Vent", Vector3.new(3.5, 0.2, 3.5), cframe * CFrame.new(0, 0.1, 0), Color3.fromRGB(25, 22, 22), Enum.Material.Metal)
	for i = -1, 1 do
		part(model, "VentBar", Vector3.new(0.25, 0.22, 3.5), cframe * CFrame.new(i * 0.9, 0.12, 0), IRON, Enum.Material.Metal)
	end
	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 140, 40)
	sparks.Enabled = false
	sparks.Parent = vent
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 18
	fire.Color = Color3.fromRGB(255, 110, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 100)
	fire.Enabled = false
	fire.Parent = vent
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 50)
	light.Range = 16
	light.Brightness = 0
	light.Parent = vent
	model.Parent = parent

	loop(vent, 4.5, function()
		sparks.Enabled = true
		task.wait(0.9)
		sparks.Enabled = false
		fire.Enabled = true
		light.Brightness = 3
		local stop = os.clock() + 1.5
		while os.clock() < stop and vent.Parent do
			for _, target in playersInBox(cframe * CFrame.new(0, 4, 0), Vector3.new(4.5, 8, 4.5)) do
				hurt(target, damage * 0.35)
			end
			task.wait(0.3)
		end
		fire.Enabled = false
		light.Brightness = 0
	end)
end

-- `wallCFrame` is the shooting slit on one corridor wall, looking across to the other wall.
function TrapService.Arrows(parent: Instance, wallCFrame: CFrame, span: number, damage: number)
	local model = Instance.new("Model")
	model.Name = "ArrowTrap"
	local slit = part(model, "Slit", Vector3.new(1.4, 0.5, 0.3), wallCFrame, Color3.fromRGB(15, 12, 12), Enum.Material.SmoothPlastic)
	slit.CanCollide = false
	model.Parent = parent
	local from = wallCFrame.Position + wallCFrame.LookVector * 0.5
	local to = wallCFrame.Position + wallCFrame.LookVector * span

	loop(slit, 2.8, function()
		slit.Material = Enum.Material.Neon
		slit.Color = Color3.fromRGB(255, 120, 40)
		task.wait(0.6)
		slit.Material = Enum.Material.SmoothPlastic
		slit.Color = Color3.fromRGB(15, 12, 12)
		local travel = span / 120
		effectRemote:FireAllClients("Arrow", from, to, travel)
		task.wait(travel * 0.5)
		local mid = CFrame.lookAt((from + to) / 2, to)
		for _, target in playersInBox(mid, Vector3.new(3, 6, span)) do
			hurt(target, damage)
		end
	end)
end

return TrapService
