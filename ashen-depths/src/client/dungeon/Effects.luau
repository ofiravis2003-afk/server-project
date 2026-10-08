--!strict
-- Draws what the server says happened: arrows, fireballs and the blast where a fireball lands.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FIRE = Color3.fromRGB(255, 120, 40)

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
