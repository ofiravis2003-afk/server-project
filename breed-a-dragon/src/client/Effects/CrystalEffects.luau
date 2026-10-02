--!strict
-- Click feedback for Ember Crystals, shown only on the clicking player's screen so it feels instant:
-- a burst of sparks, a soft "ping" and a quick bounce. The Embers themselves are given by the server.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local SPARK_COLOR = Color3.fromRGB(255, 170, 60)
local BOUNCE_SCALE = 1.08
local BOUNCE_TIME = 0.08

local CrystalEffects = {}

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
clickSound.Volume = 0.35
clickSound.Parent = SoundService

local function makeEmitter(heart: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0 -- only bursts on click
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), SPARK_COLOR)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.4, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Parent = heart
	return emitter
end

local function hook(crystal: Instance)
	if not crystal:IsA("Model") then
		return
	end
	local clickDetector = crystal:WaitForChild("ClickDetector", 10) :: ClickDetector?
	local heart = crystal:WaitForChild("Heart", 10) :: BasePart?
	if not clickDetector or not heart then
		return
	end

	local emitter = makeEmitter(heart)
	local bouncing = false

	clickDetector.MouseClick:Connect(function(player)
		if player ~= Players.LocalPlayer then
			return
		end
		emitter:Emit(12)
		clickSound.PlaybackSpeed = 0.9 + math.random() * 0.3
		SoundService:PlayLocalSound(clickSound)

		if not bouncing then
			bouncing = true
			crystal:ScaleTo(BOUNCE_SCALE)
			task.delay(BOUNCE_TIME, function()
				crystal:ScaleTo(1)
				bouncing = false
			end)
		end
	end)
end

function CrystalEffects.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("EmberCrystals")
		folder.ChildAdded:Connect(hook)
		for _, crystal in folder:GetChildren() do
			task.spawn(hook, crystal)
		end
	end)
end

return CrystalEffects
