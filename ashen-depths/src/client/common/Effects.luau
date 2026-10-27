--!strict
-- Draws what the server says happened: arrows, fireballs and their blasts, the healer's light,
-- the red line an archer aims along before it shoots, and the bosses' warnings, quakes and summons.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
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
	SporeOrb = function(from: Vector3, to: Vector3, duration: number)
		local orb = basePart(Vector3.new(1, 1, 1), Color3.fromRGB(110, 240, 140), Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.Transparency = 0.2
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(110, 240, 140)
		light.Range = 10
		light.Brightness = 2
		light.Parent = orb
		local trail = Instance.new("ParticleEmitter")
		trail.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(60, 180, 100))
		trail.LightEmission = 1
		trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = NumberRange.new(0.3, 0.6)
		trail.Speed = NumberRange.new(0.5, 1.5)
		trail.SpreadAngle = Vector2.new(180, 180)
		trail.Rate = 40
		trail.Parent = orb
		fly(orb, from, to, duration)
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
	-- A boss's warning: a red circle on the floor that fills in until the blow lands.
	Telegraph = function(center: Vector3, radius: number, duration: number)
		local base = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local ring = basePart(Vector3.new(0.12, radius * 2, radius * 2), Color3.fromRGB(200, 30, 25), Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = base
		ring.Transparency = 0.65
		ring.Parent = workspace
		local fill = basePart(Vector3.new(0.16, 0.2, 0.2), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
		fill.Shape = Enum.PartType.Cylinder
		fill.CFrame = base + Vector3.new(0, 0.02, 0)
		fill.Transparency = 0.35
		fill.Parent = workspace
		TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(0.16, radius * 2, radius * 2) }):Play()
		TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.4 }):Play()
		Debris:AddItem(ring, duration + 0.05)
		Debris:AddItem(fill, duration + 0.05)
	end,
	-- The blow lands: a shock ring of dust, and the screen shakes for whoever is close.
	Quake = function(center: Vector3, radius: number)
		local ring = basePart(Vector3.new(0.4, 2, 2), Color3.fromRGB(150, 135, 115), Enum.Material.SmoothPlastic)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.2
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.4, radius * 2.4, radius * 2.4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.5)
		local holder = basePart(Vector3.new(1, 1, 1), Color3.new(), Enum.Material.SmoothPlastic)
		holder.Transparency = 1
		holder.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(Color3.fromRGB(170, 155, 135))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.8, 1.4)
		dust.Speed = NumberRange.new(8, 16)
		dust.SpreadAngle = Vector2.new(90, 10)
		dust.Drag = 3
		dust.Rate = 0
		dust.Parent = holder
		holder.Parent = workspace
		dust:Emit(60)
		Debris:AddItem(holder, 2)
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if camera and root and (root.Position - center).Magnitude < radius * 3 then
			task.spawn(function()
				for i = 1, 8 do
					local strength = (1 - i / 8) * 0.6
					camera.CFrame *= CFrame.new(math.random(-10, 10) / 10 * strength, math.random(-10, 10) / 10 * strength, 0)
					task.wait(0.025)
				end
			end)
		end
	end,
	-- A boss calls the dead: a sickly green glow spreads around it.
	Summon = function(position: Vector3)
		local glow = basePart(Vector3.new(0.2, 4, 4), Color3.fromRGB(90, 255, 140), Enum.Material.Neon)
		glow.Shape = Enum.PartType.Cylinder
		glow.CFrame = CFrame.new(position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		glow.Transparency = 0.4
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(90, 255, 140)
		light.Range = 24
		light.Brightness = 3
		light.Parent = glow
		glow.Parent = workspace
		TweenService:Create(glow, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, 30, 30),
			Transparency = 1,
		}):Play()
		TweenService:Create(light, TweenInfo.new(1.6), { Brightness = 0 }):Play()
		Debris:AddItem(glow, 1.7)
		-- The lair's fire bowls flare up green while the dead climb out, then burn orange again.
		for _, fire in CollectionService:GetTagged("LairFire") do
			local bowl = fire.Parent
			if not fire:IsA("Fire") or not bowl or not bowl:IsA("BasePart") or (bowl.Position - position).Magnitude > 90 then
				continue
			end
			local color, secondary, size = fire.Color, fire.SecondaryColor, fire.Size
			fire.Color = Color3.fromRGB(110, 255, 150)
			fire.SecondaryColor = Color3.fromRGB(30, 160, 70)
			fire.Size = size * 1.6
			local bowlLight = bowl:FindFirstChildOfClass("PointLight")
			local lightColor = bowlLight and bowlLight.Color
			if bowlLight then
				bowlLight.Color = Color3.fromRGB(110, 255, 150)
			end
			task.delay(5, function()
				fire.Color, fire.SecondaryColor, fire.Size = color, secondary, size
				if bowlLight and lightColor then
					TweenService:Create(bowlLight, TweenInfo.new(1), { Color = lightColor }):Play()
				end
			end)
		end
	end,
	-- Where a summoned monster climbs out of the floor: a puff of grave dust.
	Rise = function(position: Vector3)
		local holder = basePart(Vector3.new(1, 1, 1), Color3.new(), Enum.Material.SmoothPlastic)
		holder.Transparency = 1
		holder.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(Color3.fromRGB(120, 140, 110))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.8, 1.3)
		dust.Speed = NumberRange.new(2, 6)
		dust.SpreadAngle = Vector2.new(60, 60)
		dust.Rate = 0
		dust.Parent = holder
		holder.Parent = workspace
		dust:Emit(30)
		Debris:AddItem(holder, 2)
	end,
	-- A boss's kick: this player's own character is thrown back.
	Knockback = function(velocity: Vector3)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = velocity
		end
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
