--!strict
-- Makes squishy monsters (slimes) wobble: their body stretches up and squashes down in a slow rhythm.
-- Only drawn on players' screens; the server's copy keeps its true size.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Squish = {}

type Wobbler = { Parts: { [BasePart]: Vector3 }, Phase: number }

local wobblers: { [Model]: Wobbler } = {}

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "Head" then
			parts[part] = part.Size
		end
	end
	wobblers[model] = { Parts = parts, Phase = math.random() * math.pi * 2 }
end

function Squish.Start()
	for _, model in CollectionService:GetTagged("Squishy") do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal("Squishy"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Squishy"):Connect(function(model)
		wobblers[model :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, wobbler in wobblers do
			if not model.Parent then
				wobblers[model] = nil
				continue
			end
			local wave = math.sin(now * 6 + wobbler.Phase) * 0.09
			local stretch = Vector3.new(1 - wave, 1 + wave, 1 - wave)
			for part, size in wobbler.Parts do
				part.Size = size * stretch
			end
		end
	end)
end

return Squish
