--!strict
-- Draws what the server says happened: arrows, fireballs and their blasts, the healer's light,
-- and the red line an archer aims along before it shoots.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FIRE = Color3.fromRGB(255, 120, 40)
local HOLY = Color3.fromRGB(255, 225, 140)

local Effects = {}

local function basePart(size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	return p
end

local function fly(p: BasePart, from: Vector3, to: Vector3, duration: number)
	local direction = to - from
	local face = if direction.Magnitude > 0.01 then CFrame.lookAt(from, to) else CFrame.new(from)
	p.CFrame = face
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Linear), {
		CFrame = face + direction,
	}):Play()
	Debris:AddItem(p, duration + 0.05)
end

local handlers: { [string]: (...any) -> () } = {
	Arrow = function(from: Vector3, to: Vector3, duration: number)
		local arrow = basePart(Vector3.new(0.12, 0.12, 2.4), Color3.fromRGB(110, 80, 55), Enum.Material.Wood)
		local tip = basePart(Vector3.new(0.2, 0.2, 0.4), Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
		tip.Anchored = false
		tip.CFrame = CFrame.new(0, 0, -1.3)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arrow
		weld.Part1 = tip
		weld.Parent = tip
		tip.Parent = arrow
		fly(arrow, from, to, duration)
	end,
	Fireball = function(from: Vector3, to: Vector3, duration: number)
		local ball = basePart(Vector3.new(1.3, 1.3, 1.3), FIRE, Enum.Material.Neon)
		ball.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = FIRE
		light.Range = 14
		light.Brightness = 3
		light.Parent = ball
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 0
		fire.Color = FIRE
		fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
		fire.Parent = ball
		fly(ball, from, to, duration)
	end,
	Blast = function(position: Vector3, radius: number)
		local blast = basePart(Vector3.new(1, 1, 1), FIRE, Enum.Material.Neon)
		blast.Shape = Enum.PartType.Ball
		blast.Transparency = 0.25
		blast.CFrame = CFrame.new(position)
		local light = Instance.new("PointLight")
		light.Color = FIRE
		light.Range = radius * 3
		light.Brightness = 5
		light.Parent = blast
		blast.Parent = workspace
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(blast, info, { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
		TweenService:Create(light, info, { Brightness = 0 }):Play()
		Debris:AddItem(blast, 0.4)
	end,
	Bolt = function(from: Vector3, to: Vector3, duration: number)
		local bolt = basePart(Vector3.new(0.7, 0.7, 0.7), HOLY, Enum.Material.Neon)
		bolt.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = HOLY
		light.Range = 10
		light.Brightness = 2.5
		light.Parent = bolt
		fly(bolt, from, to, duration)
	end,
	-- A thin red line from an archer to where it aims; it brightens until the arrow flies.
	AimLine = function(from: Vector3, to: Vector3, duration: number)
		local length = (to - from).Magnitude
		local line = basePart(Vector3.new(0.08, 0.08, length), Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
		line.CFrame = CFrame.lookAt((from + to) / 2, to)
		line.Transparency = 0.8
		line.Parent = workspace
		TweenService:Create(line, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Transparency = 0.15,
			Size = Vector3.new(0.16, 0.16, length),
		}):Play()
		Debris:AddItem(line, duration)
	end,
	-- A ring of light rising around the healed player.
	Heal = function(position: Vector3)
		local ring = basePart(Vector3.new(0.2, 5, 5), Color3.fromRGB(170, 255, 150), Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = 0.35
		local start = CFrame.new(position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.CFrame = start
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(170, 255, 150)
		light.Range = 10
		light.Brightness = 2
		light.Parent = ring
		ring.Parent = workspace
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ring, info, {
			CFrame = start + Vector3.new(0, 4, 0),
			Size = Vector3.new(0.2, 3, 3),
			Transparency = 1,
		}):Play()
		TweenService:Create(light, info, { Brightness = 0 }):Play()
		Debris:AddItem(ring, 0.65)
	end,
}

function Effects.Start()
	Remotes.Event("Effect").OnClientEvent:Connect(function(kind: string, ...)
		local handler = handlers[kind]
		if handler then
			handler(...)
		end
	end)
end

return Effects
